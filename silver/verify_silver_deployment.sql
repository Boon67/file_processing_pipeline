-- ============================================
-- SILVER LAYER DEPLOYMENT VERIFICATION
-- ============================================
-- Purpose: Comprehensive validation of Silver layer deployment
-- Run this after deployment to ensure all components are properly configured

USE DATABASE db_ingest_pipeline;
USE SCHEMA SILVER;

-- ============================================
-- SECTION 1: METADATA TABLES
-- ============================================
SELECT '========================================' as info;
SELECT '1. METADATA TABLES VERIFICATION' as info;
SELECT '========================================' as info;

-- List all tables in Silver schema
SELECT 'All Silver Tables:' as info;
SHOW TABLES IN SCHEMA SILVER;

-- Expected metadata tables
SELECT 'Checking Metadata Tables...' as info;
SELECT 
    CASE 
        WHEN COUNT(*) >= 8 THEN '✓ PASS: ' || COUNT(*) || ' metadata tables found (expected >= 8)'
        ELSE '✗ FAIL: Only ' || COUNT(*) || ' metadata tables found (expected >= 8)'
    END as status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SILVER'
AND TABLE_TYPE = 'BASE TABLE';

-- List metadata tables
SELECT 
    TABLE_NAME,
    ROW_COUNT,
    CREATED as CREATED_DATE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SILVER'
AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- ============================================
-- SECTION 2: TARGET SCHEMAS TABLE
-- ============================================
SELECT '========================================' as info;
SELECT '2. TARGET SCHEMAS VERIFICATION' as info;
SELECT '========================================' as info;

-- Check target_schemas table exists and has data
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ PASS: target_schemas table has ' || COUNT(*) || ' column definitions'
        ELSE '✗ FAIL: target_schemas table is empty'
    END as status
FROM target_schemas
WHERE active = TRUE;

-- List all target tables defined
SELECT 'Target Tables Defined:' as info;
SELECT 
    table_name,
    COUNT(*) as column_count,
    COUNT(CASE WHEN nullable = FALSE THEN 1 END) as required_columns,
    MIN(created_timestamp) as first_created
FROM target_schemas
WHERE active = TRUE
GROUP BY table_name
ORDER BY table_name;

-- Check for CLAIMS table specifically
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ PASS: CLAIMS table defined with ' || COUNT(*) || ' columns'
        ELSE '✗ FAIL: CLAIMS table not defined in target_schemas'
    END as status
FROM target_schemas
WHERE table_name = 'CLAIMS' AND active = TRUE;

-- Show CLAIMS table structure
SELECT 'CLAIMS Table Structure:' as info;
SELECT 
    column_name,
    data_type,
    nullable,
    default_value
FROM target_schemas
WHERE table_name = 'CLAIMS' AND active = TRUE
ORDER BY schema_id;

-- ============================================
-- SECTION 3: PHYSICAL TABLES
-- ============================================
SELECT '========================================' as info;
SELECT '3. PHYSICAL TABLES VERIFICATION' as info;
SELECT '========================================' as info;

-- Check if physical tables exist for defined target schemas
SELECT 'Physical Table Status:' as info;
SELECT 
    ts.table_name,
    CASE 
        WHEN t.TABLE_NAME IS NOT NULL THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as physical_table_status,
    COUNT(DISTINCT ts.column_name) as defined_columns,
    t.ROW_COUNT as current_row_count
FROM (
    SELECT DISTINCT table_name 
    FROM target_schemas 
    WHERE active = TRUE
) ts
LEFT JOIN INFORMATION_SCHEMA.TABLES t
    ON ts.table_name = t.TABLE_NAME
    AND t.TABLE_SCHEMA = 'SILVER'
GROUP BY ts.table_name, t.TABLE_NAME, t.ROW_COUNT
ORDER BY ts.table_name;

-- Verify CLAIMS table exists physically
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ PASS: CLAIMS physical table exists'
        ELSE '✗ FAIL: CLAIMS physical table does not exist'
    END as status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SILVER' AND TABLE_NAME = 'CLAIMS';

-- ============================================
-- SECTION 4: FIELD MAPPINGS
-- ============================================
SELECT '========================================' as info;
SELECT '4. FIELD MAPPINGS VERIFICATION' as info;
SELECT '========================================' as info;

-- Check field_mappings table
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ PASS: ' || COUNT(*) || ' field mappings configured'
        ELSE '⚠ WARNING: No field mappings configured'
    END as status
FROM field_mappings;

-- Field mappings by target table
SELECT 'Field Mappings by Target Table:' as info;
SELECT 
    target_table,
    COUNT(*) as mapping_count,
    COUNT(DISTINCT source_field) as unique_source_fields,
    COUNT(DISTINCT target_column) as unique_target_columns,
    COUNT(CASE WHEN approved = TRUE THEN 1 END) as approved_mappings
FROM field_mappings
GROUP BY target_table
ORDER BY target_table;

-- Check CLAIMS field mappings
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ PASS: CLAIMS has ' || COUNT(*) || ' field mappings'
        ELSE '⚠ WARNING: CLAIMS has no field mappings'
    END as status
FROM field_mappings
WHERE target_table = 'CLAIMS';

-- ============================================
-- SECTION 5: TRANSFORMATION RULES
-- ============================================
SELECT '========================================' as info;
SELECT '5. TRANSFORMATION RULES VERIFICATION' as info;
SELECT '========================================' as info;

-- Check transformation_rules table
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ PASS: ' || COUNT(*) || ' transformation rules configured'
        ELSE '⚠ INFO: No transformation rules configured (optional)'
    END as status
FROM transformation_rules;

-- Rules by type and table
SELECT 'Transformation Rules Summary:' as info;
SELECT 
    target_table,
    rule_type,
    COUNT(*) as rule_count,
    COUNT(CASE WHEN active = TRUE THEN 1 END) as active_rules
FROM transformation_rules
GROUP BY target_table, rule_type
ORDER BY target_table, rule_type;

-- ============================================
-- SECTION 6: STORED PROCEDURES
-- ============================================
SELECT '========================================' as info;
SELECT '6. STORED PROCEDURES VERIFICATION' as info;
SELECT '========================================' as info;

-- List all procedures
SELECT 'Silver Layer Procedures:' as info;
SHOW PROCEDURES IN SCHEMA SILVER;

-- Check critical procedures exist
SELECT 'Critical Procedures Check:' as info;
SELECT 
    CASE 
        WHEN COUNT(*) >= 5 THEN '✓ PASS: ' || COUNT(*) || ' procedures found (expected >= 5)'
        ELSE '✗ FAIL: Only ' || COUNT(*) || ' procedures found (expected >= 5)'
    END as status
FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'SILVER';

-- ============================================
-- SECTION 7: STAGES
-- ============================================
SELECT '========================================' as info;
SELECT '7. STAGES VERIFICATION' as info;
SELECT '========================================' as info;

-- Check Silver stages
SELECT 'Silver Stages:' as info;
SHOW STAGES IN SCHEMA SILVER;

-- Verify required stages exist
SELECT 
    CASE 
        WHEN COUNT(*) >= 2 THEN '✓ PASS: ' || COUNT(*) || ' stages configured (expected >= 2)'
        ELSE '✗ FAIL: Only ' || COUNT(*) || ' stages found (expected >= 2)'
    END as status
FROM INFORMATION_SCHEMA.STAGES
WHERE STAGE_SCHEMA = 'SILVER';

-- ============================================
-- SECTION 8: TASKS
-- ============================================
SELECT '========================================' as info;
SELECT '8. TASKS VERIFICATION' as info;
SELECT '========================================' as info;

-- List all tasks
SELECT 'Silver Layer Tasks:' as info;
SHOW TASKS IN SCHEMA SILVER;

-- Task status summary
SELECT 
    CASE 
        WHEN COUNT(*) >= 3 THEN '✓ PASS: ' || COUNT(*) || ' tasks configured (expected >= 3)'
        ELSE '⚠ WARNING: Only ' || COUNT(*) || ' tasks found (expected >= 3)'
    END as status
FROM INFORMATION_SCHEMA.TASKS
WHERE TASK_SCHEMA = 'SILVER';

-- ============================================
-- SECTION 9: VIEWS
-- ============================================
SELECT '========================================' as info;
SELECT '9. VIEWS VERIFICATION' as info;
SELECT '========================================' as info;

-- List all views
SELECT 'Silver Layer Views:' as info;
SHOW VIEWS IN SCHEMA SILVER;

-- ============================================
-- SECTION 10: DATA VALIDATION
-- ============================================
SELECT '========================================' as info;
SELECT '10. DATA VALIDATION' as info;
SELECT '========================================' as info;

-- Check Bronze data availability
SELECT 'Bronze Data Availability:' as info;
SELECT 
    COUNT(*) as bronze_records,
    COUNT(DISTINCT FILE_NAME) as unique_files,
    MIN(LOAD_TIMESTAMP) as earliest_load,
    MAX(LOAD_TIMESTAMP) as latest_load
FROM db_ingest_pipeline.BRONZE.RAW_DATA_TABLE;

-- Check Silver data (if any)
SELECT 'Silver Data Status:' as info;
SELECT 
    'CLAIMS' as table_name,
    COUNT(*) as record_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ Has Data'
        ELSE '○ Empty (expected for new deployment)'
    END as status
FROM CLAIMS;

-- ============================================
-- SECTION 11: WATERMARKS
-- ============================================
SELECT '========================================' as info;
SELECT '11. WATERMARKS VERIFICATION' as info;
SELECT '========================================' as info;

-- Check processing_watermarks table
SELECT 'Processing Watermarks:' as info;
SELECT 
    watermark_id,
    source_table,
    target_table,
    records_processed,
    last_processed_timestamp,
    updated_timestamp
FROM processing_watermarks
ORDER BY updated_timestamp DESC;

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ INFO: ' || COUNT(*) || ' watermarks configured'
        ELSE '○ INFO: No watermarks yet (expected for new deployment)'
    END as status
FROM processing_watermarks;

-- ============================================
-- FINAL SUMMARY
-- ============================================
SELECT '========================================' as info;
SELECT 'DEPLOYMENT VERIFICATION SUMMARY' as info;
SELECT '========================================' as info;

SELECT 
    'Metadata Tables' as component,
    COUNT(*) as count,
    '✓' as status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SILVER' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 
    'Target Table Definitions' as component,
    COUNT(DISTINCT table_name) as count,
    CASE WHEN COUNT(DISTINCT table_name) > 0 THEN '✓' ELSE '✗' END as status
FROM target_schemas
WHERE active = TRUE
UNION ALL
SELECT 
    'Physical Tables Created' as component,
    COUNT(*) as count,
    CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '✗' END as status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SILVER' 
AND TABLE_NAME IN (SELECT DISTINCT table_name FROM target_schemas WHERE active = TRUE)
UNION ALL
SELECT 
    'Field Mappings' as component,
    COUNT(*) as count,
    CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '⚠' END as status
FROM field_mappings
UNION ALL
SELECT 
    'Stored Procedures' as component,
    COUNT(*) as count,
    '✓' as status
FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'SILVER'
UNION ALL
SELECT 
    'Stages' as component,
    COUNT(*) as count,
    '✓' as status
FROM INFORMATION_SCHEMA.STAGES
WHERE STAGE_SCHEMA = 'SILVER'
UNION ALL
SELECT 
    'Tasks' as component,
    COUNT(*) as count,
    '✓' as status
FROM INFORMATION_SCHEMA.TASKS
WHERE TASK_SCHEMA = 'SILVER';

SELECT '========================================' as info;
SELECT 'Verification Complete!' as info;
SELECT 'Review the results above to ensure all components are properly configured.' as info;
SELECT '========================================' as info;

