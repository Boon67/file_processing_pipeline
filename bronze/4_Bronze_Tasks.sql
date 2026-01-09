-- ============================================
-- BRONZE LAYER: AUTOMATED FILE PROCESSING TASKS
-- ============================================
-- Purpose: Task-based pipeline for automated file processing
--
-- Prerequisites:
--   1. Run "1. Bronze_Roles_Grants.sql" to set up roles and permissions
--   2. Run "2. Bronze_Setup_Logic.sql" to create stages, tables, and Python procedures
--   3. Run "3a. Bronze_Stored_Procedures.sql" to create SQL orchestration procedures
--
-- Architecture:
--   Queue-based approach to work around Snowflake limitation that stored 
--   procedures cannot execute COPY FILES or REMOVE commands
--
-- Pipeline Flow:
--   1. discover_files_task (scheduled) → Scans @SRC stage, adds new files to queue
--   2. process_files_task (after #1) → Calls Python procedures to ingest data
--   3. move_successful_files_task (after #2) → Moves processed files to @SRC_COMPLETED
--   4. move_failed_files_task (after #2) → Moves failed files to @SRC_ERROR
--
-- Task Dependency Graph:
--   discover_files_task (scheduled)
--        ↓
--   process_files_task
--        ↓
--   ┌────────────────┴────────────────┐
--   ↓                                 ↓
--   move_successful_files_task    move_failed_files_task
-- ============================================

USE ROLE db_ingest_pipeline_ADMIN;

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = 'db_ingest_pipeline';
SET SCHEMA_NAME = 'BRONZE';
SET WAREHOUSE_NAME = 'COMPUTE_WH';
SET DISCOVER_TASK_SCHEDULE_MINUTES = '60';

USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SCHEMA_NAME);

-- ============================================
-- TASK 1: FILE DISCOVERY
-- ============================================
-- Purpose: Root task that discovers new files in @SRC stage
-- Schedule: Configurable interval (default: 60 minutes)
-- Calls: discover_files() stored procedure
-- Note: SCHEDULE value will be replaced by deploy.sh with actual minutes
-- Features:
--   - Refreshes @SRC stage metadata before discovery
--   - Ensures latest files are detected
-- ============================================

EXECUTE IMMEDIATE $$
DECLARE
    warehouse_name VARCHAR DEFAULT '$WAREHOUSE_NAME';
    task_name VARCHAR DEFAULT '$DISCOVER_TASK_NAME';
    schedule_minutes VARCHAR DEFAULT '$DISCOVER_TASK_SCHEDULE_MINUTES';
    stage_name VARCHAR DEFAULT '$SRC_STAGE_NAME';
    create_task_sql VARCHAR;
BEGIN
    create_task_sql := 'CREATE OR REPLACE TASK IDENTIFIER(''' || task_name || ''')
        WAREHOUSE = IDENTIFIER(''' || warehouse_name || ''')
        SCHEDULE = ''' || schedule_minutes || ' MINUTE''
    AS
    BEGIN
        -- Refresh stage metadata to ensure latest files are detected
        ALTER STAGE IDENTIFIER(''' || stage_name || ''') REFRESH;
        
        -- Discover new files
        CALL discover_files();
    END;';
    
    EXECUTE IMMEDIATE create_task_sql;
END;
$$;

-- ============================================
-- TASK 2: FILE PROCESSING
-- ============================================
-- Purpose: Process files added to queue by discovery task
-- Trigger: Runs after discover_files_task completes
-- Calls: process_queued_files() stored procedure
-- Features:
--   - Processes up to 10 files per execution
--   - Routes to appropriate Python processor (CSV or Excel)
--   - Updates queue status based on processing results
-- ============================================

CREATE OR REPLACE TASK process_files_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    AFTER discover_files_task
AS
    CALL process_queued_files();

-- ============================================
-- TASK 3: MOVE SUCCESSFUL FILES
-- ============================================
-- Purpose: Move successfully processed files to @SRC_COMPLETED
-- Trigger: Runs after process_files_task completes
-- Features:
--   - Moves up to 10 files per execution
--   - Uses EXECUTE IMMEDIATE (required for COPY FILES/REMOVE in tasks)
--   - Updates queue moved_timestamp
--   - Continues on error to process remaining files
-- ============================================

EXECUTE IMMEDIATE $$
CREATE OR REPLACE TASK move_successful_files_task
    WAREHOUSE = IDENTIFIER('COMPUTE_WH')
    AFTER process_files_task
AS
DECLARE
    file_name VARCHAR;
    files_moved INT DEFAULT 0;
    move_cursor CURSOR FOR 
        SELECT file_name 
        FROM file_processing_queue 
        WHERE status = 'SUCCESS' AND moved_timestamp IS NULL
        LIMIT 10;
BEGIN
    FOR file_rec IN move_cursor DO
        file_name := file_rec.file_name;
        
        BEGIN
            -- Copy file to completed stage and remove from source
            EXECUTE IMMEDIATE 'COPY FILES INTO @SRC_COMPLETED FROM @SRC FILES = (\'' || :file_name || '\')';
            EXECUTE IMMEDIATE 'REMOVE @SRC/' || :file_name;
            
            -- Mark as moved in queue
            UPDATE file_processing_queue 
            SET moved_timestamp = CURRENT_TIMESTAMP()
            WHERE file_name = :file_name AND status = 'SUCCESS';
            
            files_moved := files_moved + 1;
        EXCEPTION
            WHEN OTHER THEN
                -- Log error but continue processing other files
                NULL;
        END;
    END FOR;
END;
$$;

-- ============================================
-- TASK 4: MOVE FAILED FILES
-- ============================================
-- Purpose: Move failed files to @SRC_ERROR for investigation
-- Trigger: Runs after process_files_task completes (parallel with task 3)
-- Features:
--   - Moves up to 10 files per execution
--   - Uses EXECUTE IMMEDIATE (required for COPY FILES/REMOVE in tasks)
--   - Updates queue moved_timestamp
--   - Continues on error to process remaining files
-- ============================================

EXECUTE IMMEDIATE $$
CREATE OR REPLACE TASK move_failed_files_task
    WAREHOUSE = IDENTIFIER('COMPUTE_WH')
    AFTER process_files_task
AS
DECLARE
    file_name VARCHAR;
    files_moved INT DEFAULT 0;
    move_cursor CURSOR FOR 
        SELECT file_name 
        FROM file_processing_queue 
        WHERE status = 'FAILED' AND moved_timestamp IS NULL
        LIMIT 10;
BEGIN
    FOR file_rec IN move_cursor DO
        file_name := file_rec.file_name;
        
        BEGIN
            -- Copy file to error stage and remove from source
            EXECUTE IMMEDIATE 'COPY FILES INTO @SRC_ERROR FROM @SRC FILES = (\'' || :file_name || '\')';
            EXECUTE IMMEDIATE 'REMOVE @SRC/' || :file_name;
            
            -- Mark as moved in queue
            UPDATE file_processing_queue 
            SET moved_timestamp = CURRENT_TIMESTAMP()
            WHERE file_name = :file_name AND status = 'FAILED';
            
            files_moved := files_moved + 1;
        EXCEPTION
            WHEN OTHER THEN
                -- Log error but continue processing other files
                NULL;
        END;
    END FOR;
END;
$$;

-- ============================================
-- TASK ACTIVATION
-- ============================================
-- Resume tasks in reverse dependency order (children first, parent last)
-- This ensures child tasks are ready when their predecessors complete

ALTER TASK move_failed_files_task RESUME;
ALTER TASK move_successful_files_task RESUME;
ALTER TASK process_files_task RESUME;
ALTER TASK discover_files_task RESUME;

-- ============================================
-- TASK MANAGEMENT COMMANDS
-- ============================================

-- Pause all tasks (for maintenance)
-- ALTER TASK discover_files_task SUSPEND;
-- ALTER TASK process_files_task SUSPEND;
-- ALTER TASK move_successful_files_task SUSPEND;
-- ALTER TASK move_failed_files_task SUSPEND;

-- Resume all tasks (after maintenance)
-- ALTER TASK move_failed_files_task RESUME;
-- ALTER TASK move_successful_files_task RESUME;
-- ALTER TASK process_files_task RESUME;
-- ALTER TASK discover_files_task RESUME;

-- ============================================
-- MANUAL TESTING
-- ============================================
-- Uncomment to manually execute individual tasks for testing

-- EXECUTE TASK discover_files_task;
-- EXECUTE TASK process_files_task;
-- EXECUTE TASK move_successful_files_task;
-- EXECUTE TASK move_failed_files_task;

-- ============================================
-- MONITORING AND OBSERVABILITY
-- ============================================

-- View task execution history (last 7 days)
-- SELECT 
--     NAME,
--     STATE,
--     SCHEDULED_TIME,
--     COMPLETED_TIME,
--     ERROR_CODE,
--     ERROR_MESSAGE
-- FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
--     SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())
-- ))
-- WHERE NAME IN ('DISCOVER_FILES_TASK', 'PROCESS_FILES_TASK', 'MOVE_SUCCESSFUL_FILES_TASK', 'MOVE_FAILED_FILES_TASK')
-- ORDER BY SCHEDULED_TIME DESC
-- LIMIT 50;

-- View processing queue status summary
-- SELECT 
--     status,
--     file_type,
--     COUNT(*) AS file_count,
--     MIN(discovered_timestamp) AS oldest,
--     MAX(discovered_timestamp) AS newest
-- FROM file_processing_queue
-- GROUP BY status, file_type
-- ORDER BY status, file_type;

-- View files in each stage
-- SELECT 'SRC' AS STAGE, COUNT(*) AS FILE_COUNT
-- FROM DIRECTORY(@SRC)
-- UNION ALL
-- SELECT 'COMPLETED' AS STAGE, COUNT(*) AS FILE_COUNT
-- FROM DIRECTORY(@SRC_COMPLETED)
-- UNION ALL
-- SELECT 'ERROR' AS STAGE, COUNT(*) AS FILE_COUNT
-- FROM DIRECTORY(@SRC_ERROR);

-- View recently loaded data (last 24 hours)
-- SELECT 
--     FILE_NAME,
--     COUNT(DISTINCT FILE_ROW_NUMBER) AS ROWS_LOADED,
--     MAX(LOAD_TIMESTAMP) AS LAST_LOAD_TIME
-- FROM RAW_DATA_TABLE
-- WHERE LOAD_TIMESTAMP >= DATEADD('day', -1, CURRENT_TIMESTAMP())
-- GROUP BY FILE_NAME
-- ORDER BY LAST_LOAD_TIME DESC;

-- View detailed queue history (last 50 entries)
-- SELECT 
--     queue_id,
--     file_name,
--     file_type,
--     status,
--     process_result,
--     discovered_timestamp,
--     processed_timestamp,
--     moved_timestamp,
--     error_message
-- FROM file_processing_queue
-- ORDER BY queue_id DESC
-- LIMIT 50;

-- ============================================
-- TASK 5: ARCHIVE OLD FILES (RUNS DAILY)
-- ============================================
-- Purpose: Move files older than 30 days from completed/error stages to archive
-- Schedule: Runs daily at 2 AM
-- Dependencies: None (independent cleanup task)
-- ============================================

CREATE OR REPLACE TASK archive_old_files_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    SCHEDULE = 'USING CRON 0 2 * * * America/Chicago'
    COMMENT = 'Archives files older than 30 days from completed and error stages'
AS
EXECUTE IMMEDIATE $$
DECLARE
    file_rec RECORD;
    files_archived INT DEFAULT 0;
    completed_stage STRING := (SELECT IDENTIFIER($COMPLETED_STAGE_NAME));
    error_stage STRING := (SELECT IDENTIFIER($ERROR_STAGE_NAME));
    archive_stage STRING := (SELECT IDENTIFIER($ARCHIVE_STAGE_NAME));
BEGIN
    -- Archive files from completed stage older than 30 days
    FOR file_rec IN (
        SELECT relative_path, last_modified
        FROM DIRECTORY(@IDENTIFIER($COMPLETED_STAGE_NAME))
        WHERE last_modified < DATEADD(day, -30, CURRENT_TIMESTAMP())
    ) LOOP
        EXECUTE IMMEDIATE 'COPY FILES INTO @' || :archive_stage || 
                         ' FROM @' || :completed_stage || '/' || file_rec.relative_path;
        EXECUTE IMMEDIATE 'REMOVE @' || :completed_stage || '/' || file_rec.relative_path;
        files_archived := files_archived + 1;
    END LOOP;
    
    -- Archive files from error stage older than 30 days
    FOR file_rec IN (
        SELECT relative_path, last_modified
        FROM DIRECTORY(@IDENTIFIER($ERROR_STAGE_NAME))
        WHERE last_modified < DATEADD(day, -30, CURRENT_TIMESTAMP())
    ) LOOP
        EXECUTE IMMEDIATE 'COPY FILES INTO @' || :archive_stage || 
                         ' FROM @' || :error_stage || '/' || file_rec.relative_path;
        EXECUTE IMMEDIATE 'REMOVE @' || :error_stage || '/' || file_rec.relative_path;
        files_archived := files_archived + 1;
    END LOOP;
    
    RETURN 'Archived ' || files_archived || ' file(s) to ' || :archive_stage;
END;
$$;

-- Grant execute permission on archive task
-- Role name follows pattern: {database_name}_ADMIN
EXECUTE IMMEDIATE $$
DECLARE
    admin_role STRING := (SELECT $DATABASE_NAME || '_ADMIN');
BEGIN
    EXECUTE IMMEDIATE 'GRANT OPERATE ON TASK archive_old_files_task TO ROLE IDENTIFIER(''' || :admin_role || ''')';
END;
$$;

-- Resume the archive task (starts the schedule)
ALTER TASK archive_old_files_task RESUME;

-- ============================================
-- TASK 6: REPROCESS ERROR FILES
-- ============================================
-- Purpose: Move files from ERROR stage back to SRC for reprocessing
-- Trigger: Manual execution via EXECUTE TASK or Streamlit UI
-- Dependencies: None (manually triggered)
-- Note: This task moves files (not copies) and triggers discovery
-- ============================================

CREATE OR REPLACE TASK reprocess_error_files_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    COMMENT = 'Moves error files back to source stage for reprocessing'
AS
EXECUTE IMMEDIATE $$
DECLARE
    file_name STRING;
    files_moved INT DEFAULT 0;
    src_stage STRING := '@SRC';
    error_stage STRING := '@ERROR';
    result_cursor CURSOR FOR
        SELECT file_name 
        FROM reprocess_queue 
        WHERE status = 'PENDING_REPROCESS'
        LIMIT 100;
BEGIN
    -- Get list of files to reprocess from the queue
    FOR record IN result_cursor DO
        file_name := record.file_name;
        
        -- Copy file from ERROR to SRC
        EXECUTE IMMEDIATE 'COPY FILES INTO ' || :src_stage || 
                         ' FROM ' || :error_stage || 
                         ' FILES = (''' || :file_name || ''')';
        
        -- Remove file from ERROR stage
        EXECUTE IMMEDIATE 'REMOVE ' || :error_stage || '/' || :file_name;
        
        -- Update queue status
        UPDATE file_processing_queue
        SET status = 'PENDING',
            error_message = 'Reprocessing requested',
            processed_timestamp = NULL,
            process_result = NULL
        WHERE file_name = :file_name;
        
        -- Mark as processed in reprocess queue
        UPDATE reprocess_queue
        SET status = 'MOVED'
        WHERE file_name = :file_name;
        
        files_moved := files_moved + 1;
    END LOOP;
    
    -- Clean up processed entries from reprocess queue
    DELETE FROM reprocess_queue WHERE status = 'MOVED';
    
    -- If files were moved, trigger discovery task
    IF (files_moved > 0) THEN
        EXECUTE TASK discover_files_task;
    END IF;
    
    RETURN 'Moved ' || files_moved || ' file(s) from ERROR to SRC for reprocessing';
END;
$$;

-- Grant execute permission on reprocess task
EXECUTE IMMEDIATE $$
DECLARE
    admin_role STRING := (SELECT $DATABASE_NAME || '_ADMIN');
BEGIN
    EXECUTE IMMEDIATE 'GRANT OPERATE ON TASK reprocess_error_files_task TO ROLE IDENTIFIER(''' || :admin_role || ''')';
END;
$$;

-- Note: This task is NOT resumed automatically - it's triggered manually
