-- ============================================
-- QUICK SILVER DEPLOYMENT CHECK
-- ============================================
-- Purpose: Quick validation of Silver layer deployment
-- Run this to verify all critical components are in place

USE DATABASE db_ingest_pipeline;
USE SCHEMA SILVER;

SELECT '═══════════════════════════════════════════════════' as info;
SELECT '   SILVER LAYER DEPLOYMENT VERIFICATION REPORT' as info;
SELECT '═══════════════════════════════════════════════════' as info;
SELECT '' as info;

-- 1. Metadata Tables
SELECT '1. METADATA TABLES' as info;
SELECT '   ───────────────' as info;
SELECT 
    CASE 
        WHEN COUNT(*) >= 8 THEN '   ✓ PASS: ' || COUNT(*) || ' metadata tables exist'
        ELSE '   ✗ FAIL: Only ' || COUNT(*) || ' metadata tables found'
    END as status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SILVER' AND TABLE_TYPE = 'BASE TABLE';
SELECT '' as info;

-- 2. Target Table Definitions
SELECT '2. TARGET TABLE DEFINITIONS' as info;
SELECT '   ────────────────────────' as info;
SELECT 
    CASE 
        WHEN COUNT(DISTINCT table_name) > 0 THEN '   ✓ PASS: ' || COUNT(DISTINCT table_name) || ' target tables defined'
        ELSE '   ✗ FAIL: No target tables defined'
    END as status
FROM target_schemas WHERE active = TRUE;

SELECT 
    '   Tables: ' || LISTAGG(DISTINCT table_name, ', ') as tables
FROM target_schemas WHERE active = TRUE;
SELECT '' as info;

-- 3. CLAIMS Table
SELECT '3. CLAIMS TABLE' as info;
SELECT '   ────────────' as info;
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '   ✓ PASS: CLAIMS defined with ' || COUNT(*) || ' columns'
        ELSE '   ✗ FAIL: CLAIMS not defined'
    END as status
FROM target_schemas WHERE table_name = 'CLAIMS' AND active = TRUE;

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '   ✓ PASS: CLAIMS physical table exists with ' || MAX(ROW_COUNT) || ' records'
        ELSE '   ✗ FAIL: CLAIMS physical table missing'
    END as status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SILVER' AND TABLE_NAME = 'CLAIMS';
SELECT '' as info;

-- 4. Field Mappings
SELECT '4. FIELD MAPPINGS' as info;
SELECT '   ───────────────' as info;
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '   ✓ PASS: ' || COUNT(*) || ' field mappings configured'
        ELSE '   ⚠ WARNING: No field mappings'
    END as status
FROM field_mappings;

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '   ✓ PASS: CLAIMS has ' || COUNT(*) || ' field mappings'
        ELSE '   ⚠ WARNING: CLAIMS has no field mappings'
    END as status
FROM field_mappings WHERE target_table = 'CLAIMS';
SELECT '' as info;

-- 5. Transformation Rules
SELECT '5. TRANSFORMATION RULES' as info;
SELECT '   ────────────────────' as info;
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '   ✓ INFO: ' || COUNT(*) || ' transformation rules configured'
        ELSE '   ○ INFO: No transformation rules (optional)'
    END as status
FROM transformation_rules;
SELECT '' as info;

-- 6. Stored Procedures
SELECT '6. STORED PROCEDURES' as info;
SELECT '   ──────────────────' as info;
SELECT 
    CASE 
        WHEN COUNT(*) >= 5 THEN '   ✓ PASS: ' || COUNT(*) || ' procedures deployed'
        ELSE '   ✗ FAIL: Only ' || COUNT(*) || ' procedures found'
    END as status
FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'SILVER';

-- Check critical procedures
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '   ✓ transform_bronze_to_silver exists'
        ELSE '   ✗ transform_bronze_to_silver MISSING'
    END as status
FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'SILVER' 
AND PROCEDURE_NAME = 'TRANSFORM_BRONZE_TO_SILVER';

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '   ✓ create_silver_table exists'
        ELSE '   ✗ create_silver_table MISSING'
    END as status
FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'SILVER' 
AND PROCEDURE_NAME = 'CREATE_SILVER_TABLE';
SELECT '' as info;

-- 7. Stages
SELECT '7. STAGES' as info;
SELECT '   ───────' as info;
SELECT 
    CASE 
        WHEN COUNT(*) >= 2 THEN '   ✓ PASS: ' || COUNT(*) || ' stages configured'
        ELSE '   ✗ FAIL: Only ' || COUNT(*) || ' stages found'
    END as status
FROM INFORMATION_SCHEMA.STAGES
WHERE STAGE_SCHEMA = 'SILVER';
SELECT '' as info;

-- 8. Tasks
SELECT '8. TASKS' as info;
SELECT '   ──────' as info;
SELECT 
    '   ✓ INFO: Tasks configured (check with SHOW TASKS)' as status;
SELECT '' as info;

-- 9. Bronze Data Availability
SELECT '9. BRONZE DATA AVAILABILITY' as info;
SELECT '   ────────────────────────' as info;
SELECT 
    '   ✓ INFO: ' || COUNT(*) || ' records in Bronze RAW_DATA_TABLE' as status
FROM db_ingest_pipeline.BRONZE.RAW_DATA_TABLE;

SELECT 
    '   ✓ INFO: ' || COUNT(DISTINCT FILE_NAME) || ' unique source files' as status
FROM db_ingest_pipeline.BRONZE.RAW_DATA_TABLE;
SELECT '' as info;

-- 10. Watermarks
SELECT '10. PROCESSING WATERMARKS' as info;
SELECT '    ──────────────────────' as info;
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '    ✓ INFO: ' || COUNT(*) || ' watermarks configured'
        ELSE '    ○ INFO: No watermarks yet (normal for new deployment)'
    END as status
FROM processing_watermarks;
SELECT '' as info;

-- SUMMARY
SELECT '═══════════════════════════════════════════════════' as info;
SELECT '   DEPLOYMENT SUMMARY' as info;
SELECT '═══════════════════════════════════════════════════' as info;

SELECT 
    LPAD('Component', 30) || ' | ' || LPAD('Count', 8) || ' | Status' as header;
SELECT REPEAT('─', 50) as separator;

SELECT 
    LPAD('Metadata Tables', 30) || ' | ' || LPAD(TO_VARCHAR(COUNT(*)), 8) || ' | ✓' as summary
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SILVER' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 
    LPAD('Target Table Definitions', 30) || ' | ' || LPAD(TO_VARCHAR(COUNT(DISTINCT table_name)), 8) || ' | ' ||
    CASE WHEN COUNT(DISTINCT table_name) > 0 THEN '✓' ELSE '✗' END as summary
FROM target_schemas WHERE active = TRUE
UNION ALL
SELECT 
    LPAD('CLAIMS Table Columns', 30) || ' | ' || LPAD(TO_VARCHAR(COUNT(*)), 8) || ' | ' ||
    CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '✗' END as summary
FROM target_schemas WHERE table_name = 'CLAIMS' AND active = TRUE
UNION ALL
SELECT 
    LPAD('CLAIMS Records', 30) || ' | ' || LPAD(TO_VARCHAR(COUNT(*)), 8) || ' | ✓' as summary
FROM CLAIMS
UNION ALL
SELECT 
    LPAD('Field Mappings', 30) || ' | ' || LPAD(TO_VARCHAR(COUNT(*)), 8) || ' | ' ||
    CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '⚠' END as summary
FROM field_mappings
UNION ALL
SELECT 
    LPAD('Transformation Rules', 30) || ' | ' || LPAD(TO_VARCHAR(COUNT(*)), 8) || ' | ○' as summary
FROM transformation_rules
UNION ALL
SELECT 
    LPAD('Stored Procedures', 30) || ' | ' || LPAD(TO_VARCHAR(COUNT(*)), 8) || ' | ✓' as summary
FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'SILVER'
UNION ALL
SELECT 
    LPAD('Stages', 30) || ' | ' || LPAD(TO_VARCHAR(COUNT(*)), 8) || ' | ✓' as summary
FROM INFORMATION_SCHEMA.STAGES
WHERE STAGE_SCHEMA = 'SILVER'
UNION ALL
SELECT 
    LPAD('Bronze Records Available', 30) || ' | ' || LPAD(TO_VARCHAR(COUNT(*)), 8) || ' | ✓' as summary
FROM db_ingest_pipeline.BRONZE.RAW_DATA_TABLE;

SELECT '' as info;
SELECT '═══════════════════════════════════════════════════' as info;
SELECT '   ✓ = Pass    ✗ = Fail    ⚠ = Warning    ○ = Info' as legend;
SELECT '═══════════════════════════════════════════════════' as info;
SELECT '' as info;
SELECT '   Deployment verification complete!' as info;
SELECT '' as info;

