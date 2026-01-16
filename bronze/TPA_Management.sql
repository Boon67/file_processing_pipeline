-- ============================================
-- TPA MANAGEMENT UTILITIES
-- ============================================
-- Purpose: Helper queries for managing TPAs in the Bronze layer
-- 
-- This script provides utilities for:
--   1. Viewing active TPAs
--   2. Adding new TPAs
--   3. Deactivating TPAs
--   4. Updating TPA information
--   5. Viewing TPA usage statistics
-- ============================================

USE DATABASE db_ingest_pipeline;
USE SCHEMA BRONZE;

-- ============================================
-- VIEW ACTIVE TPAs
-- ============================================

-- List all active TPAs
SELECT 
    TPA_CODE,
    TPA_NAME,
    TPA_DESCRIPTION,
    CREATED_TIMESTAMP,
    UPDATED_TIMESTAMP
FROM TPA_MASTER
WHERE ACTIVE = TRUE
ORDER BY TPA_CODE;

-- ============================================
-- ADD NEW TPA
-- ============================================

-- Template for adding a new TPA
-- Replace the values below with your actual TPA information

/*
INSERT INTO TPA_MASTER (TPA_CODE, TPA_NAME, TPA_DESCRIPTION, ACTIVE)
VALUES (
    'provider_f',                    -- TPA code (lowercase, use underscores)
    'Provider F Healthcare',         -- Full TPA name
    'New healthcare provider F',     -- Description
    TRUE                             -- Active status
);
*/

-- Example: Add multiple TPAs at once
/*
INSERT INTO TPA_MASTER (TPA_CODE, TPA_NAME, TPA_DESCRIPTION, ACTIVE)
VALUES 
    ('blue_cross', 'Blue Cross Blue Shield', 'Blue Cross Blue Shield Insurance', TRUE),
    ('aetna', 'Aetna Healthcare', 'Aetna Healthcare Insurance', TRUE),
    ('cigna', 'Cigna Health', 'Cigna Health Insurance', TRUE),
    ('united_health', 'UnitedHealthcare', 'UnitedHealthcare Insurance', TRUE);
*/

-- ============================================
-- UPDATE TPA INFORMATION
-- ============================================

-- Update TPA name
/*
UPDATE TPA_MASTER
SET 
    TPA_NAME = 'New Provider Name',
    UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
WHERE TPA_CODE = 'provider_a';
*/

-- Update TPA description
/*
UPDATE TPA_MASTER
SET 
    TPA_DESCRIPTION = 'Updated description',
    UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
WHERE TPA_CODE = 'provider_a';
*/

-- ============================================
-- DEACTIVATE TPA
-- ============================================

-- Deactivate a TPA (prevents it from appearing in upload dropdown)
-- Note: Does not delete existing data, just prevents new uploads
/*
UPDATE TPA_MASTER
SET 
    ACTIVE = FALSE,
    UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
WHERE TPA_CODE = 'provider_old';
*/

-- ============================================
-- REACTIVATE TPA
-- ============================================

-- Reactivate a previously deactivated TPA
/*
UPDATE TPA_MASTER
SET 
    ACTIVE = TRUE,
    UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
WHERE TPA_CODE = 'provider_old';
*/

-- ============================================
-- VIEW ALL TPAs (INCLUDING INACTIVE)
-- ============================================

SELECT 
    TPA_CODE,
    TPA_NAME,
    TPA_DESCRIPTION,
    ACTIVE,
    CREATED_TIMESTAMP,
    UPDATED_TIMESTAMP,
    CREATED_BY
FROM TPA_MASTER
ORDER BY ACTIVE DESC, TPA_CODE;

-- ============================================
-- TPA USAGE STATISTICS
-- ============================================

-- Count files by TPA
SELECT 
    tm.TPA_CODE,
    tm.TPA_NAME,
    tm.ACTIVE,
    COUNT(DISTINCT rdt.FILE_NAME) as file_count,
    COUNT(*) as row_count,
    MIN(rdt.LOAD_TIMESTAMP) as first_upload,
    MAX(rdt.LOAD_TIMESTAMP) as last_upload
FROM TPA_MASTER tm
LEFT JOIN RAW_DATA_TABLE rdt ON tm.TPA_CODE = rdt.TPA
GROUP BY tm.TPA_CODE, tm.TPA_NAME, tm.ACTIVE
ORDER BY row_count DESC;

-- Files processed by TPA (from processing queue)
SELECT 
    tm.TPA_CODE,
    tm.TPA_NAME,
    COUNT(*) as total_files,
    SUM(CASE WHEN fpq.status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_files,
    SUM(CASE WHEN fpq.status = 'FAILED' THEN 1 ELSE 0 END) as failed_files,
    SUM(CASE WHEN fpq.status = 'PENDING' THEN 1 ELSE 0 END) as pending_files,
    ROUND(100.0 * SUM(CASE WHEN fpq.status = 'SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2) as success_rate
FROM TPA_MASTER tm
LEFT JOIN RAW_DATA_TABLE rdt ON tm.TPA_CODE = rdt.TPA
LEFT JOIN file_processing_queue fpq ON rdt.FILE_NAME = fpq.file_name
WHERE fpq.file_name IS NOT NULL
GROUP BY tm.TPA_CODE, tm.TPA_NAME
ORDER BY total_files DESC;

-- Recent uploads by TPA (last 7 days)
SELECT 
    TPA,
    COUNT(DISTINCT FILE_NAME) as files_uploaded,
    COUNT(*) as rows_loaded,
    MIN(LOAD_TIMESTAMP) as first_upload,
    MAX(LOAD_TIMESTAMP) as last_upload
FROM RAW_DATA_TABLE
WHERE LOAD_TIMESTAMP >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY TPA
ORDER BY rows_loaded DESC;

-- ============================================
-- TPA DATA VOLUME ANALYSIS
-- ============================================

-- Data volume by TPA (bytes and rows)
SELECT 
    TPA,
    COUNT(DISTINCT FILE_NAME) as file_count,
    COUNT(*) as row_count,
    SUM(FILE_SIZE) as total_bytes,
    ROUND(SUM(FILE_SIZE) / 1024.0 / 1024.0, 2) as total_mb,
    ROUND(AVG(FILE_SIZE) / 1024.0 / 1024.0, 2) as avg_file_mb
FROM RAW_DATA_TABLE
GROUP BY TPA
ORDER BY total_bytes DESC;

-- ============================================
-- FIND ORPHANED TPAs
-- ============================================

-- TPAs in RAW_DATA_TABLE that are not in TPA_MASTER
-- These may need to be added to TPA_MASTER or data may need to be corrected
SELECT DISTINCT
    rdt.TPA,
    COUNT(DISTINCT rdt.FILE_NAME) as file_count,
    COUNT(*) as row_count
FROM RAW_DATA_TABLE rdt
LEFT JOIN TPA_MASTER tm ON rdt.TPA = tm.TPA_CODE
WHERE tm.TPA_CODE IS NULL
GROUP BY rdt.TPA
ORDER BY row_count DESC;

-- ============================================
-- VALIDATE TPA DATA INTEGRITY
-- ============================================

-- Check for NULL TPAs in RAW_DATA_TABLE (should not exist)
SELECT 
    COUNT(*) as null_tpa_count,
    COUNT(DISTINCT FILE_NAME) as affected_files
FROM RAW_DATA_TABLE
WHERE TPA IS NULL;

-- If NULL TPAs found, list the affected files
SELECT DISTINCT
    FILE_NAME,
    STAGE_NAME,
    MIN(LOAD_TIMESTAMP) as first_loaded,
    COUNT(*) as row_count
FROM RAW_DATA_TABLE
WHERE TPA IS NULL
GROUP BY FILE_NAME, STAGE_NAME
ORDER BY first_loaded DESC;

-- ============================================
-- BULK TPA OPERATIONS
-- ============================================

-- Deactivate multiple TPAs at once
/*
UPDATE TPA_MASTER
SET 
    ACTIVE = FALSE,
    UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
WHERE TPA_CODE IN ('old_provider_1', 'old_provider_2', 'old_provider_3');
*/

-- Bulk insert TPAs from a staging table (if you have one)
/*
MERGE INTO TPA_MASTER AS target
USING staging_tpas AS source
ON target.TPA_CODE = source.TPA_CODE
WHEN NOT MATCHED THEN
    INSERT (TPA_CODE, TPA_NAME, TPA_DESCRIPTION, ACTIVE)
    VALUES (source.TPA_CODE, source.TPA_NAME, source.TPA_DESCRIPTION, TRUE)
WHEN MATCHED THEN
    UPDATE SET
        TPA_NAME = source.TPA_NAME,
        TPA_DESCRIPTION = source.TPA_DESCRIPTION,
        UPDATED_TIMESTAMP = CURRENT_TIMESTAMP();
*/

-- ============================================
-- TPA AUDIT TRAIL
-- ============================================

-- View TPA changes over time (requires STREAM or audit table)
-- This is a placeholder for future audit functionality
/*
SELECT 
    TPA_CODE,
    TPA_NAME,
    ACTIVE,
    UPDATED_TIMESTAMP,
    CREATED_BY
FROM TPA_MASTER
ORDER BY UPDATED_TIMESTAMP DESC;
*/

-- ============================================
-- CLEANUP OPERATIONS
-- ============================================

-- Delete a TPA (CAUTION: Only do this if no data exists for this TPA)
-- This will fail if there are foreign key constraints or existing data
/*
-- First check if TPA has any data
SELECT COUNT(*) FROM RAW_DATA_TABLE WHERE TPA = 'tpa_to_delete';

-- If count is 0, safe to delete
DELETE FROM TPA_MASTER WHERE TPA_CODE = 'tpa_to_delete';
*/

-- ============================================
-- EXPORT TPA LIST
-- ============================================

-- Export TPA list to CSV (for backup or sharing)
/*
COPY INTO @SRC/tpa_backup/tpa_master_backup.csv
FROM (
    SELECT 
        TPA_CODE,
        TPA_NAME,
        TPA_DESCRIPTION,
        ACTIVE,
        CREATED_TIMESTAMP,
        UPDATED_TIMESTAMP
    FROM TPA_MASTER
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' HEADER = TRUE)
OVERWRITE = TRUE;
*/

-- ============================================
-- BEST PRACTICES
-- ============================================

/*
TPA Management Best Practices:

1. NAMING CONVENTIONS:
   - Use lowercase for TPA codes
   - Use underscores for spaces (e.g., 'blue_cross')
   - Keep codes short but descriptive
   - Avoid special characters

2. DEACTIVATION vs DELETION:
   - Always DEACTIVATE instead of DELETE
   - Deactivation preserves historical data
   - Prevents orphaned records

3. VALIDATION:
   - Always check for existing data before deleting
   - Verify TPA code doesn't exist before inserting
   - Use MERGE for idempotent operations

4. DOCUMENTATION:
   - Keep TPA_DESCRIPTION up to date
   - Document why TPAs were deactivated
   - Maintain external documentation of TPA contacts

5. MONITORING:
   - Regularly check for orphaned TPAs
   - Monitor TPA usage statistics
   - Review inactive TPAs periodically

6. SECURITY:
   - Limit TPA_MASTER write access to admins only
   - Audit TPA changes
   - Validate TPA codes against external systems
*/

-- ============================================
-- TROUBLESHOOTING
-- ============================================

/*
Common Issues and Solutions:

1. TPA not appearing in Streamlit dropdown:
   - Check if TPA is ACTIVE = TRUE
   - Refresh the Streamlit app (cache TTL is 5 minutes)
   - Verify TPA_MASTER table exists and has data

2. Files uploaded with wrong TPA:
   - Check folder structure in @SRC stage
   - Verify TPA extraction logic in processing procedures
   - Reprocess files if needed

3. Orphaned TPA data:
   - Add missing TPA to TPA_MASTER
   - Or update RAW_DATA_TABLE to use existing TPA code

4. Cannot delete TPA:
   - Check if TPA has existing data
   - Deactivate instead of delete
   - If deletion is required, archive data first
*/

-- ============================================
-- END OF TPA MANAGEMENT UTILITIES
-- ============================================
