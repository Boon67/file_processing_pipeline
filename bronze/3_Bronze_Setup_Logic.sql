-- ============================================
-- BRONZE LAYER: FILE PROCESSING STORED PROCEDURES
-- ============================================
-- Purpose: SQL stored procedures for file discovery and processing orchestration
--
-- These procedures are called by tasks in the automated pipeline:
--   - discover_files(): Scans @SRC stage and adds files to queue
--   - process_queued_files(): Calls Python procedures to process files
--
-- Note: These are SQL procedures, not Python. They cannot execute
--       COPY FILES or REMOVE commands (must be done in tasks).
-- ============================================

USE ROLE db_ingest_pipeline_ADMIN;

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = 'db_ingest_pipeline';
SET SCHEMA_NAME = 'BRONZE';

USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SCHEMA_NAME);

-- ============================================
-- FILE DISCOVERY PROCEDURE
-- ============================================
-- Purpose: Scan @SRC stage and add new files to processing queue
-- Returns: Count of newly discovered files
-- Called by: discover_files_task
--
-- Features:
--   - Detects both CSV and Excel files
--   - Deduplicates: Skips files already in queue with PENDING/PROCESSING/SUCCESS status
--   - Batch discovers all files in single call
-- ============================================

CREATE OR REPLACE PROCEDURE discover_files()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    files_added INT DEFAULT 0;
BEGIN
    -- Discover CSV files
    INSERT INTO file_processing_queue (file_name, file_type, status)
    SELECT 
        SPLIT_PART(RELATIVE_PATH, '/', -1) AS file_name,
        'CSV' AS file_type,
        'PENDING' AS status
    FROM DIRECTORY(@SRC)
    WHERE LOWER(RELATIVE_PATH) LIKE '%.csv'
    AND SPLIT_PART(RELATIVE_PATH, '/', -1) NOT IN (
        SELECT file_name FROM file_processing_queue 
        WHERE status IN ('PENDING', 'PROCESSING', 'SUCCESS')
    );
    
    files_added := SQLROWCOUNT;
    
    -- Discover Excel files
    INSERT INTO file_processing_queue (file_name, file_type, status)
    SELECT 
        SPLIT_PART(RELATIVE_PATH, '/', -1) AS file_name,
        'EXCEL' AS file_type,
        'PENDING' AS status
    FROM DIRECTORY(@SRC)
    WHERE (LOWER(RELATIVE_PATH) LIKE '%.xlsx' OR LOWER(RELATIVE_PATH) LIKE '%.xls')
    AND SPLIT_PART(RELATIVE_PATH, '/', -1) NOT IN (
        SELECT file_name FROM file_processing_queue 
        WHERE status IN ('PENDING', 'PROCESSING', 'SUCCESS')
    );
    
    files_added := files_added + SQLROWCOUNT;
    
    RETURN 'Discovered ' || files_added || ' new files';
END;
$$;

-- ============================================
-- FILE PROCESSING PROCEDURE
-- ============================================
-- Purpose: Process pending files by calling appropriate Python procedures
-- Returns: Count of files processed in this batch
-- Called by: process_files_task
--
-- Features:
--   - Processes up to 10 files per call (batch processing)
--   - Updates status to PROCESSING before calling procedure
--   - Routes to appropriate processor based on file_type
--   - Updates status to SUCCESS/FAILED based on result
--   - Captures error messages for debugging
--
-- Note: Calls process_single_csv_file() and process_single_excel_file()
--       which are defined in 2. Bronze_Setup_Logic.sql
-- ============================================

CREATE OR REPLACE PROCEDURE process_queued_files()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    queue_id INT;
    file_name VARCHAR;
    file_type VARCHAR;
    result VARCHAR;
    files_processed INT DEFAULT 0;
    
    file_cursor CURSOR FOR 
        SELECT queue_id, file_name, file_type
        FROM file_processing_queue
        WHERE status = 'PENDING'
        ORDER BY discovered_timestamp
        LIMIT 10;  -- Process 10 files at a time
BEGIN
    FOR file_rec IN file_cursor DO
        queue_id := file_rec.queue_id;
        file_name := file_rec.file_name;
        file_type := file_rec.file_type;
        
        -- Mark as processing
        UPDATE file_processing_queue 
        SET status = 'PROCESSING', processed_timestamp = CURRENT_TIMESTAMP()
        WHERE queue_id = :queue_id;
        
        BEGIN
            -- Call appropriate Python processor
            IF (file_type = 'CSV') THEN
                CALL process_single_csv_file('SRC', :file_name) INTO :result;
            ELSE
                CALL process_single_excel_file('SRC', :file_name) INTO :result;
            END IF;
            
            -- Update status based on result
            IF (STARTSWITH(:result, 'SUCCESS')) THEN
                UPDATE file_processing_queue 
                SET status = 'SUCCESS', process_result = :result
                WHERE queue_id = :queue_id;
            ELSE
                UPDATE file_processing_queue 
                SET status = 'FAILED', process_result = :result, error_message = :result
                WHERE queue_id = :queue_id;
            END IF;
            
            files_processed := files_processed + 1;
            
        EXCEPTION
            WHEN OTHER THEN
                -- Capture any processing errors
                UPDATE file_processing_queue 
                SET status = 'FAILED', error_message = SQLERRM
                WHERE queue_id = :queue_id;
        END;
    END FOR;
    
    RETURN 'Processed ' || files_processed || ' files';
END;
$$;

-- ============================================
-- ERROR FILE REPROCESSING PROCEDURES
-- ============================================
-- Purpose: Move files from ERROR stage back to SRC for reprocessing
-- Called by: Streamlit UI or manual intervention
-- ============================================

-- Reprocess a single error file
-- Note: Adds file to reprocess queue, then executes the reprocess task
-- The task will move the file from ERROR to SRC and trigger discovery
CREATE OR REPLACE PROCEDURE reprocess_error_file(p_file_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    file_exists INTEGER;
BEGIN
    -- Check if file exists in ERROR stage
    SELECT COUNT(*) INTO :file_exists
    FROM DIRECTORY(@ERROR)
    WHERE RELATIVE_PATH = :p_file_name;
    
    IF (:file_exists = 0) THEN
        RETURN 'ERROR: File not found in error stage: ' || :p_file_name;
    END IF;
    
    -- Add file to reprocess queue
    INSERT INTO reprocess_queue (file_name, status)
    VALUES (:p_file_name, 'PENDING_REPROCESS');
    
    -- Execute the reprocess task to move the file
    EXECUTE TASK reprocess_error_files_task;
    
    RETURN 'SUCCESS: File queued for reprocessing and task executed: ' || :p_file_name;
END;
$$;

-- Reprocess all error files
-- Note: Adds all error files to reprocess queue, then executes the reprocess task
-- The task will move files from ERROR to SRC and trigger discovery
CREATE OR REPLACE PROCEDURE reprocess_all_error_files()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    file_name VARCHAR;
    files_queued INTEGER DEFAULT 0;
    result_cursor CURSOR FOR
        SELECT RELATIVE_PATH
        FROM DIRECTORY(@ERROR)
        LIMIT 100;
BEGIN
    -- Add all error files to reprocess queue
    FOR record IN result_cursor DO
        file_name := record.RELATIVE_PATH;
        
        INSERT INTO reprocess_queue (file_name, status)
        VALUES (:file_name, 'PENDING_REPROCESS');
        
        files_queued := files_queued + 1;
    END FOR;
    
    IF (files_queued > 0) THEN
        -- Execute the reprocess task to move the files
        EXECUTE TASK reprocess_error_files_task;
        RETURN 'SUCCESS: ' || files_queued || ' file(s) queued for reprocessing and task executed';
    ELSE
        RETURN 'No error files found to reprocess';
    END IF;
END;
$$;

-- ============================================
-- ERROR FILES VIEW
-- ============================================
-- Purpose: Show files currently in ERROR stage with metadata
-- ============================================

CREATE OR REPLACE VIEW v_error_files AS
SELECT
    d.RELATIVE_PATH as file_name,
    d.SIZE as file_size_bytes,
    ROUND(d.SIZE / 1024.0, 2) as file_size_kb,
    d.LAST_MODIFIED,
    q.file_type,
    q.status,
    q.error_message,
    q.discovered_timestamp,
    q.processed_timestamp,
    DATEDIFF('hour', d.LAST_MODIFIED, CURRENT_TIMESTAMP()) as hours_in_error_stage
FROM DIRECTORY(@ERROR) d
LEFT JOIN file_processing_queue q
    ON d.RELATIVE_PATH = q.file_name
ORDER BY d.LAST_MODIFIED DESC;

-- ============================================
-- MANUAL TESTING
-- ============================================
-- Uncomment to test procedures manually

-- Test file discovery
-- CALL discover_files();
-- SELECT * FROM file_processing_queue ORDER BY discovered_timestamp DESC;

-- Test file processing
-- CALL process_queued_files();
-- SELECT * FROM file_processing_queue WHERE status IN ('SUCCESS', 'FAILED') ORDER BY processed_timestamp DESC;

-- Test error file reprocessing
-- CALL reprocess_error_file('your_file_name.csv');
-- SELECT * FROM v_error_files;
