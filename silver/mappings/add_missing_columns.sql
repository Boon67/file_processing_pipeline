-- ============================================
-- Add Missing Columns Suggested by LLM
-- ============================================
-- This script adds columns that the LLM suggested but weren't in the original schema
-- Run this if your source data contains these fields

USE DATABASE db_ingest_pipeline;
USE SCHEMA SILVER;

-- Insert missing columns into target_schemas
-- These were suggested by the LLM but not in the original CSV

INSERT INTO target_schemas (table_name, column_name, tpa, data_type, nullable, default_value, description, active)
VALUES
    ('CLAIMS', 'PROCEDURE_DATE', 'provider_a', 'DATE', TRUE, NULL, 'Date when medical/dental procedure was performed', TRUE),
    ('CLAIMS', 'TOOTH_NUMBER', 'provider_a', 'VARCHAR(10)', TRUE, NULL, 'Tooth number for dental procedures (if applicable)', TRUE),
    ('PRODUCT_TYPE', 'provider_a', 'VARCHAR(100)', TRUE, NULL, 'Type of product or service provided', TRUE)
ON CONFLICT (table_name, column_name, tpa) DO NOTHING;

-- Verify the columns were added
SELECT table_name, column_name, data_type, description
FROM target_schemas
WHERE table_name = 'CLAIMS'
  AND column_name IN ('PROCEDURE_DATE', 'TOOTH_NUMBER', 'PRODUCT_TYPE')
  AND tpa = 'provider_a'
ORDER BY column_name;
