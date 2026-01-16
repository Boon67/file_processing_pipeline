-- ============================================
-- SILVER LAYER: STANDARD METADATA COLUMNS
-- ============================================
-- Purpose: Ensure all Silver tables have standard metadata columns
-- 
-- This script creates:
--   1. Procedure to add standard metadata columns to any table
--   2. Procedure to create standard field mappings for metadata columns
--   3. Trigger/automation to ensure new tables get these columns
--
-- Standard Metadata Columns:
--   - SOURCE_FILE_NAME: Original file name from Bronze layer
--   - INGESTION_TIMESTAMP: When the record was ingested
--   - CREATED_AT: Record creation timestamp
--   - UPDATED_AT: Record last update timestamp
-- ============================================

USE ROLE db_ingest_pipeline_ADMIN;
USE DATABASE db_ingest_pipeline;
USE SCHEMA SILVER;

-- ============================================
-- PROCEDURE: Add Standard Metadata Columns
-- ============================================
-- Purpose: Add standard metadata columns to a target table definition
-- Input: p_table_name - Target table name
--        p_tpa - TPA code (optional - will auto-detect from existing columns if not provided)
-- Output: Success/failure message

CREATE OR REPLACE PROCEDURE add_standard_metadata_columns(p_table_name VARCHAR, p_tpa VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    rows_added INT DEFAULT 0;
    column_exists INT;
    v_tpa VARCHAR;
BEGIN
    -- If TPA not provided, get it from existing columns for this table
    IF (p_tpa IS NULL) THEN
        SELECT tpa INTO :v_tpa
        FROM target_schemas
        WHERE table_name = UPPER(:p_table_name)
          AND active = TRUE
        LIMIT 1;
        
        -- If still no TPA found, raise error
        IF (v_tpa IS NULL) THEN
            RETURN 'ERROR: TPA must be provided or table must have existing columns with TPA';
        END IF;
    ELSE
        v_tpa := p_tpa;
    END IF;
    
    -- Check and add SOURCE_FILE_NAME
    SELECT COUNT(*) INTO :column_exists
    FROM target_schemas
    WHERE table_name = UPPER(:p_table_name)
      AND column_name = 'SOURCE_FILE_NAME'
      AND tpa = :v_tpa
      AND active = TRUE;
    
    IF (column_exists = 0) THEN
        INSERT INTO target_schemas (
            table_name, column_name, tpa, data_type, nullable,
            default_value, description, active
        )
        VALUES (
            UPPER(:p_table_name),
            'SOURCE_FILE_NAME',
            :v_tpa,
            'VARCHAR(500)',
            TRUE,
            NULL,
            'Original source file name from Bronze layer',
            TRUE
        );
        rows_added := rows_added + 1;
    END IF;
    
    -- Check and add INGESTION_TIMESTAMP
    SELECT COUNT(*) INTO :column_exists
    FROM target_schemas
    WHERE table_name = UPPER(:p_table_name)
      AND column_name = 'INGESTION_TIMESTAMP'
      AND tpa = :v_tpa
      AND active = TRUE;
    
    IF (column_exists = 0) THEN
        INSERT INTO target_schemas (
            table_name, column_name, tpa, data_type, nullable,
            default_value, description, active
        )
        VALUES (
            UPPER(:p_table_name),
            'INGESTION_TIMESTAMP',
            :v_tpa,
            'TIMESTAMP_NTZ',
            FALSE,
            'CURRENT_TIMESTAMP()',
            'Timestamp when record was ingested',
            TRUE
        );
        rows_added := rows_added + 1;
    END IF;
    
    -- Check and add CREATED_AT
    SELECT COUNT(*) INTO :column_exists
    FROM target_schemas
    WHERE table_name = UPPER(:p_table_name)
      AND column_name = 'CREATED_AT'
      AND tpa = :v_tpa
      AND active = TRUE;
    
    IF (column_exists = 0) THEN
        INSERT INTO target_schemas (
            table_name, column_name, tpa, data_type, nullable,
            default_value, description, active
        )
        VALUES (
            UPPER(:p_table_name),
            'CREATED_AT',
            :v_tpa,
            'TIMESTAMP_NTZ',
            FALSE,
            'CURRENT_TIMESTAMP()',
            'Record creation timestamp in Silver layer',
            TRUE
        );
        rows_added := rows_added + 1;
    END IF;
    
    -- Check and add UPDATED_AT
    SELECT COUNT(*) INTO :column_exists
    FROM target_schemas
    WHERE table_name = UPPER(:p_table_name)
      AND column_name = 'UPDATED_AT'
      AND tpa = :v_tpa
      AND active = TRUE;
    
    IF (column_exists = 0) THEN
        INSERT INTO target_schemas (
            table_name, column_name, tpa, data_type, nullable,
            default_value, description, active
        )
        VALUES (
            UPPER(:p_table_name),
            'UPDATED_AT',
            :v_tpa,
            'TIMESTAMP_NTZ',
            FALSE,
            'CURRENT_TIMESTAMP()',
            'Record last update timestamp',
            TRUE
        );
        rows_added := rows_added + 1;
    END IF;
    
    RETURN 'Added ' || rows_added || ' standard metadata column(s) to ' || UPPER(:p_table_name) || ' for TPA ' || :v_tpa;
END;
$$;

-- ============================================
-- PROCEDURE: Create Standard Field Mappings
-- ============================================
-- Purpose: Create field mappings for standard metadata columns
-- Input: p_table_name - Target table name
--        p_tpa - TPA code (optional - will auto-detect from existing columns if not provided)
-- Output: Success/failure message

CREATE OR REPLACE PROCEDURE create_standard_field_mappings(p_table_name VARCHAR, p_tpa VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    rows_added INT DEFAULT 0;
    mapping_exists INT;
    v_tpa VARCHAR;
BEGIN
    -- If TPA not provided, get it from existing columns for this table
    IF (p_tpa IS NULL) THEN
        SELECT tpa INTO :v_tpa
        FROM target_schemas
        WHERE table_name = UPPER(:p_table_name)
          AND active = TRUE
        LIMIT 1;
        
        -- If still no TPA found, raise error
        IF (v_tpa IS NULL) THEN
            RETURN 'ERROR: TPA must be provided or table must have existing columns with TPA';
        END IF;
    ELSE
        v_tpa := p_tpa;
    END IF;
    
    -- Check and add FILE_NAME -> SOURCE_FILE_NAME mapping
    SELECT COUNT(*) INTO :mapping_exists
    FROM field_mappings
    WHERE target_table = UPPER(:p_table_name)
      AND target_column = 'SOURCE_FILE_NAME'
      AND tpa = :v_tpa;
    
    IF (mapping_exists = 0) THEN
        INSERT INTO field_mappings (
            source_field, source_table, target_table, target_column,
            tpa, mapping_method, confidence_score, transformation_logic,
            description, approved
        )
        VALUES (
            'FILE_NAME',
            'RAW_DATA_TABLE',
            UPPER(:p_table_name),
            'SOURCE_FILE_NAME',
            :v_tpa,
            'SYSTEM',
            1.0,
            'FILE_NAME',
            'Maps FILE_NAME table column from Bronze RAW_DATA_TABLE to SOURCE_FILE_NAME. This is a table-level column, not from the RAW_DATA VARIANT.',
            TRUE
        );
        rows_added := rows_added + 1;
    END IF;
    
    -- Check and add LOAD_TIMESTAMP -> INGESTION_TIMESTAMP mapping
    SELECT COUNT(*) INTO :mapping_exists
    FROM field_mappings
    WHERE target_table = UPPER(:p_table_name)
      AND target_column = 'INGESTION_TIMESTAMP'
      AND tpa = :v_tpa;
    
    IF (mapping_exists = 0) THEN
        INSERT INTO field_mappings (
            source_field, source_table, target_table, target_column,
            tpa, mapping_method, confidence_score, transformation_logic,
            description, approved
        )
        VALUES (
            'LOAD_TIMESTAMP',
            'RAW_DATA_TABLE',
            UPPER(:p_table_name),
            'INGESTION_TIMESTAMP',
            :v_tpa,
            'SYSTEM',
            1.0,
            'LOAD_TIMESTAMP',
            'Maps LOAD_TIMESTAMP table column from Bronze RAW_DATA_TABLE to INGESTION_TIMESTAMP. This is a table-level column, not from the RAW_DATA VARIANT.',
            TRUE
        );
        rows_added := rows_added + 1;
    END IF;
    
    -- CREATED_AT and UPDATED_AT use default values, no mapping needed
    
    RETURN 'Added ' || rows_added || ' standard field mapping(s) for ' || UPPER(:p_table_name) || ' for TPA ' || :v_tpa;
END;
$$;

-- ============================================
-- PROCEDURE: Initialize Table with Standards
-- ============================================
-- Purpose: Add both standard columns and mappings to a table
-- Input: p_table_name - Target table name
--        p_tpa - TPA code (optional - will auto-detect from existing columns if not provided)
-- Output: Combined success message

CREATE OR REPLACE PROCEDURE initialize_table_with_standards(p_table_name VARCHAR, p_tpa VARCHAR DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    columns_result VARCHAR;
    mappings_result VARCHAR;
BEGIN
    -- Add standard columns (TPA will be auto-detected if not provided)
    CALL add_standard_metadata_columns(:p_table_name, :p_tpa);
    columns_result := SQLROWCOUNT;
    
    -- Create standard mappings (TPA will be auto-detected if not provided)
    CALL create_standard_field_mappings(:p_table_name, :p_tpa);
    mappings_result := SQLROWCOUNT;
    
    RETURN 'Initialized ' || UPPER(:p_table_name) || ' with standard metadata. ' || 
           columns_result || ' | ' || mappings_result;
END;
$$;

-- ============================================
-- Usage Examples
-- ============================================
-- After loading target schemas from CSV, you can add standard columns:
--
-- Example 1: Auto-detect TPA from existing columns
-- CALL add_standard_metadata_columns('CLAIMS');
-- CALL create_standard_field_mappings('CLAIMS');
--
-- Example 2: Specify TPA explicitly
-- CALL add_standard_metadata_columns('CLAIMS', 'provider_a');
-- CALL create_standard_field_mappings('CLAIMS', 'provider_a');
--
-- Example 3: Initialize everything at once
-- CALL initialize_table_with_standards('CLAIMS', 'provider_a');
-- ============================================

SELECT 'Standard metadata procedures created successfully' as result;

