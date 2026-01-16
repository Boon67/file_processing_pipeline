-- ============================================
-- Diagnose Source Data Fields
-- ============================================
-- This query shows what fields exist in your Bronze RAW_DATA
-- to help understand what the LLM is trying to map

USE DATABASE db_ingest_pipeline;
USE SCHEMA BRONZE;

-- Get all unique field names from Bronze RAW_DATA
SELECT 
    key AS source_field_name,
    COUNT(*) as occurrence_count,
    COUNT(DISTINCT file_name) as file_count
FROM RAW_DATA_TABLE,
LATERAL FLATTEN(input => RAW_DATA)
WHERE RAW_DATA IS NOT NULL
GROUP BY key
ORDER BY key;

-- Check if specific fields exist
SELECT 
    'PROCEDURE_DATE' as field_name,
    COUNT(*) as count
FROM RAW_DATA_TABLE
WHERE RAW_DATA:PROCEDURE_DATE IS NOT NULL
   OR RAW_DATA:procedure_date IS NOT NULL
   OR RAW_DATA:procedureDate IS NOT NULL
   OR RAW_DATA:ProcedureDate IS NOT NULL

UNION ALL

SELECT 
    'TOOTH_NUMBER' as field_name,
    COUNT(*) as count
FROM RAW_DATA_TABLE
WHERE RAW_DATA:TOOTH_NUMBER IS NOT NULL
   OR RAW_DATA:tooth_number IS NOT NULL
   OR RAW_DATA:toothNumber IS NOT NULL
   OR RAW_DATA:ToothNumber IS NOT NULL

UNION ALL

SELECT 
    'PRODUCT_TYPE' as field_name,
    COUNT(*) as count
FROM RAW_DATA_TABLE
WHERE RAW_DATA:PRODUCT_TYPE IS NOT NULL
   OR RAW_DATA:product_type IS NOT NULL
   OR RAW_DATA:productType IS NOT NULL
   OR RAW_DATA:ProductType IS NOT NULL;
