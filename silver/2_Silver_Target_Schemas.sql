-- ============================================
-- SILVER LAYER TARGET SCHEMA MANAGEMENT
-- ============================================
-- Purpose: Dynamic target schema definition and table creation
-- 
-- This script creates procedures for:
--   1. Loading target schema definitions from CSV
--   2. Validating schema definitions
--   3. Dynamically creating Silver tables from metadata
--   4. Managing table lifecycle (create, alter, drop)
--
-- Note: Foreign keys in Snowflake are informational only (not enforced)
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';

-- Set role name
SET role_admin = (SELECT '$DATABASE_NAME' || '_ADMIN');

USE ROLE IDENTIFIER($role_admin);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- PROCEDURE: Load Target Schema from CSV
-- ============================================
-- Purpose: Load target table definitions from CSV file
-- Input: stage_path - Path to CSV file in stage (e.g., '@SILVER_CONFIG/target_tables.csv')
-- Output: Number of schema definitions loaded

CREATE OR REPLACE PROCEDURE load_target_schemas_from_csv(stage_path VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    rows_loaded INTEGER DEFAULT 0;
    result_msg VARCHAR;
BEGIN
    -- Create temporary table for CSV data
    CREATE OR REPLACE TEMPORARY TABLE temp_target_schemas (
        table_name VARCHAR(500),
        column_name VARCHAR(500),
        data_type VARCHAR(200),
        nullable VARCHAR(10),
        default_value VARCHAR(1000),
        description VARCHAR(5000)
    );
    
    -- Load CSV into temporary table
    EXECUTE IMMEDIATE 'COPY INTO temp_target_schemas FROM ' || :stage_path || '
        FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = ''"'')';
    
    -- Merge into target_schemas table with data type conversion (prevents duplicates)
    MERGE INTO target_schemas ts
    USING (
        SELECT 
            UPPER(table_name) as table_name,
            UPPER(column_name) as column_name,
            UPPER(data_type) as data_type,
            CASE WHEN UPPER(nullable) IN ('TRUE', 'YES', '1') THEN TRUE ELSE FALSE END as nullable,
            default_value,
            description
        FROM temp_target_schemas
    ) src
    ON ts.table_name = src.table_name AND ts.column_name = src.column_name
    WHEN MATCHED THEN UPDATE SET
        data_type = src.data_type,
        nullable = src.nullable,
        default_value = src.default_value,
        description = src.description,
        updated_timestamp = CURRENT_TIMESTAMP(),
        active = TRUE
    WHEN NOT MATCHED THEN INSERT (
        table_name, column_name, data_type, nullable, default_value, description, active
    ) VALUES (
        src.table_name, src.column_name, src.data_type, src.nullable, src.default_value, src.description, TRUE
    );
    
    rows_loaded := SQLROWCOUNT;
    
    -- Clean up
    DROP TABLE IF EXISTS temp_target_schemas;
    
    result_msg := 'Successfully loaded ' || rows_loaded || ' schema definitions from ' || :stage_path;
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Validate Target Schema
-- ============================================
-- Purpose: Validate schema definitions for a table
-- Input: table_name - Name of the table to validate
-- Output: Validation result message

CREATE OR REPLACE PROCEDURE validate_target_schema(table_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    validation_errors VARCHAR DEFAULT '';
    pk_count INTEGER;
    column_count INTEGER;
    invalid_type_count INTEGER;
    result_msg VARCHAR;
BEGIN
    -- Check if table has any columns defined
    SELECT COUNT(*) INTO column_count
    FROM target_schemas
    WHERE target_schemas.table_name = UPPER(:table_name)
      AND active = TRUE;
    
    IF (column_count = 0) THEN
        validation_errors := validation_errors || 'No columns defined for table. ';
    END IF;
    
    -- Primary key validation removed - Snowflake doesn't enforce PKs
    
    -- Check for invalid data types
    SELECT COUNT(*) INTO invalid_type_count
    FROM target_schemas
    WHERE target_schemas.table_name = UPPER(:table_name)
      AND active = TRUE
      AND data_type NOT RLIKE '^(VARCHAR|NUMBER|INTEGER|FLOAT|DOUBLE|BOOLEAN|DATE|TIMESTAMP_NTZ|TIMESTAMP_LTZ|TIMESTAMP_TZ|TIME|VARIANT|OBJECT|ARRAY|BINARY|GEOGRAPHY|GEOMETRY).*';
    
    IF (invalid_type_count > 0) THEN
        validation_errors := validation_errors || 'Invalid data types detected. ';
    END IF;
    
    -- Check for duplicate column names
    DECLARE
        duplicate_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO duplicate_count
        FROM (
            SELECT column_name, COUNT(*) as cnt
            FROM target_schemas
            WHERE target_schemas.table_name = UPPER(:table_name)
              AND active = TRUE
            GROUP BY column_name
            HAVING COUNT(*) > 1
        );
        
        IF (duplicate_count > 0) THEN
            validation_errors := validation_errors || 'Duplicate column names detected. ';
        END IF;
    END;
    
    -- Return validation result
    IF (validation_errors = '') THEN
        result_msg := 'Validation passed for table: ' || UPPER(:table_name);
    ELSE
        result_msg := 'Validation FAILED for table: ' || UPPER(:table_name) || ' - Errors: ' || validation_errors;
    END IF;
    
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Generate CREATE TABLE DDL
-- ============================================
-- Purpose: Generate CREATE TABLE DDL from metadata
-- Input: table_name - Name of the table
-- Output: DDL statement as string

CREATE OR REPLACE PROCEDURE generate_table_ddl(p_table_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    ddl_statement VARCHAR DEFAULT '';
    column_definitions VARCHAR DEFAULT '';
    tbl_name VARCHAR;
    col_name VARCHAR;
    col_type VARCHAR;
    col_nullable BOOLEAN;
    col_default VARCHAR;
    first_col BOOLEAN DEFAULT TRUE;
BEGIN
    -- Store table name in local variable
    tbl_name := UPPER(p_table_name);
    
    -- Start DDL
    ddl_statement := 'CREATE OR REPLACE TABLE ' || tbl_name || ' (\n';
    
    -- Get column definitions using LET to create resultset
    LET res RESULTSET := (SELECT column_name, data_type, nullable, default_value
                          FROM target_schemas
                          WHERE table_name = :tbl_name
                            AND active = TRUE
                          ORDER BY schema_id);
    
    -- Declare cursor for the resultset
    LET c1 CURSOR FOR res;
    
    -- Build column definitions
    OPEN c1;
    FOR record IN c1 DO
        col_name := record.column_name;
        col_type := record.data_type;
        col_nullable := record.nullable;
        col_default := record.default_value;
        
        -- Clean up data type (fix space to comma in NUMBER types, remove AUTOINCREMENT if present)
        col_type := REPLACE(col_type, ' ', ',');
        col_type := REPLACE(col_type, ',AUTOINCREMENT', '');
        col_type := TRIM(col_type);
        
        -- Add comma for subsequent columns
        IF (NOT first_col) THEN
            column_definitions := column_definitions || ',\n';
        END IF;
        first_col := FALSE;
        
        -- Column definition
        column_definitions := column_definitions || '    ' || col_name || ' ' || col_type;
        
        -- NOT NULL constraint
        IF (NOT col_nullable) THEN
            column_definitions := column_definitions || ' NOT NULL';
        END IF;
        
        -- Default value
        IF (col_default IS NOT NULL AND col_default != '') THEN
            column_definitions := column_definitions || ' DEFAULT ' || col_default;
        END IF;
    END FOR;
    CLOSE c1;
    
    -- Complete DDL
    ddl_statement := ddl_statement || column_definitions || '\n)';
    
    -- Add comment
    ddl_statement := ddl_statement || '\nCOMMENT = ''Silver layer table: ' || tbl_name || ' (dynamically generated)''';
    
    RETURN ddl_statement;
END;
$$;

-- ============================================
-- PROCEDURE: Create Silver Table
-- ============================================
-- Purpose: Create a Silver table from metadata definition
-- Input: table_name - Name of the table to create
-- Output: Success/failure message

CREATE OR REPLACE PROCEDURE create_silver_table(table_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    validation_result VARCHAR;
    ddl_statement VARCHAR;
    result_msg VARCHAR;
BEGIN
    -- Validate schema first
    CALL validate_target_schema(:table_name) INTO validation_result;
    
    IF (validation_result NOT LIKE 'Validation passed%') THEN
        RETURN 'Table creation failed: ' || validation_result;
    END IF;
    
    -- Generate DDL
    CALL generate_table_ddl(:table_name) INTO ddl_statement;
    
    -- Execute DDL
    EXECUTE IMMEDIATE :ddl_statement;
    
    result_msg := 'Successfully created table: ' || UPPER(:table_name);
    RETURN result_msg;
EXCEPTION
    WHEN OTHER THEN
        result_msg := 'Error creating table ' || UPPER(:table_name) || ': ' || SQLERRM;
        RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Create All Silver Tables
-- ============================================
-- Purpose: Create all Silver tables defined in metadata
-- Output: Summary of tables created

CREATE OR REPLACE PROCEDURE create_all_silver_tables()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    tables_created INTEGER DEFAULT 0;
    tables_failed INTEGER DEFAULT 0;
    result_msg VARCHAR;
    table_result VARCHAR;
    cursor_tables CURSOR FOR 
        SELECT DISTINCT table_name
        FROM target_schemas
        WHERE active = TRUE
        ORDER BY table_name;
    tbl_name VARCHAR;
BEGIN
    -- Loop through all distinct tables
    OPEN cursor_tables;
    FOR record IN cursor_tables DO
        tbl_name := record.table_name;
        
        -- Try to create each table
        BEGIN
            CALL create_silver_table(:tbl_name) INTO table_result;
            
            IF (table_result LIKE 'Successfully created%') THEN
                tables_created := tables_created + 1;
            ELSE
                tables_failed := tables_failed + 1;
            END IF;
        EXCEPTION
            WHEN OTHER THEN
                tables_failed := tables_failed + 1;
        END;
    END FOR;
    CLOSE cursor_tables;
    
    result_msg := 'Table creation complete. Created: ' || tables_created || ', Failed: ' || tables_failed;
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Drop Silver Table
-- ============================================
-- Purpose: Drop a Silver table and optionally deactivate its metadata
-- Input: table_name - Name of the table to drop
--        deactivate_metadata - If TRUE, marks schema as inactive instead of deleting
-- Output: Success/failure message

CREATE OR REPLACE PROCEDURE drop_silver_table(
    table_name VARCHAR,
    deactivate_metadata BOOLEAN DEFAULT TRUE
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    result_msg VARCHAR;
BEGIN
    -- Drop the table
    EXECUTE IMMEDIATE 'DROP TABLE IF EXISTS ' || UPPER(:table_name);
    
    -- Handle metadata
    IF (:deactivate_metadata) THEN
        -- Deactivate schema definitions
        UPDATE target_schemas
        SET active = FALSE, updated_timestamp = CURRENT_TIMESTAMP()
        WHERE target_schemas.table_name = UPPER(:table_name);
        
        -- Delete related field mappings (since field_mappings no longer has active column)
        DELETE FROM field_mappings
        WHERE target_table = UPPER(:table_name);
        
        -- Deactivate related transformation rules
        UPDATE transformation_rules
        SET active = FALSE, updated_timestamp = CURRENT_TIMESTAMP()
        WHERE target_table = UPPER(:table_name);
        
        result_msg := 'Dropped table ' || UPPER(:table_name) || ' and deactivated metadata';
    ELSE
        -- Delete schema definitions
        DELETE FROM target_schemas WHERE target_schemas.table_name = UPPER(:table_name);
        
        result_msg := 'Dropped table ' || UPPER(:table_name) || ' and deleted metadata';
    END IF;
    
    RETURN result_msg;
EXCEPTION
    WHEN OTHER THEN
        result_msg := 'Error dropping table ' || UPPER(:table_name) || ': ' || SQLERRM;
        RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Add Column to Silver Table
-- ============================================
-- Purpose: Add a new column to an existing Silver table
-- Input: table_name, column_name, data_type, nullable, default_value, description
-- Output: Success/failure message

CREATE OR REPLACE PROCEDURE add_column_to_silver_table(
    table_name VARCHAR,
    column_name VARCHAR,
    data_type VARCHAR,
    nullable BOOLEAN DEFAULT TRUE,
    default_value VARCHAR DEFAULT NULL,
    description VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    alter_statement VARCHAR;
    result_msg VARCHAR;
BEGIN
    -- Insert into metadata
    INSERT INTO target_schemas (
        table_name, column_name, data_type, nullable, default_value, description, active
    )
    VALUES (
        UPPER(:table_name), UPPER(:column_name), UPPER(:data_type), 
        :nullable, :default_value, :description, TRUE
    );
    
    -- Build ALTER TABLE statement
    alter_statement := 'ALTER TABLE ' || UPPER(:table_name) || ' ADD COLUMN ' || 
                       UPPER(:column_name) || ' ' || UPPER(:data_type);
    
    IF (NOT :nullable) THEN
        alter_statement := alter_statement || ' NOT NULL';
    END IF;
    
    IF (:default_value IS NOT NULL AND :default_value != '') THEN
        alter_statement := alter_statement || ' DEFAULT ' || :default_value;
    END IF;
    
    -- Execute ALTER TABLE
    EXECUTE IMMEDIATE :alter_statement;
    
    result_msg := 'Successfully added column ' || UPPER(:column_name) || 
                  ' to table ' || UPPER(:table_name);
    RETURN result_msg;
EXCEPTION
    WHEN OTHER THEN
        result_msg := 'Error adding column: ' || SQLERRM;
        RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Check if Table Exists
-- ============================================
-- Purpose: Check if a physical table exists in the database
-- Input: table_name - Name of the table to check
-- Output: TRUE if table exists, FALSE otherwise

CREATE OR REPLACE PROCEDURE check_table_exists(
    table_name VARCHAR
)
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO table_count
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'SILVER'
    AND TABLE_NAME = UPPER(:table_name);
    
    RETURN table_count > 0;
END;
$$;

-- ============================================
-- PROCEDURE: Alter Column in Silver Table
-- ============================================
-- Purpose: Alter an existing column in a Silver table
-- Input: table_name, column_name, new_data_type, nullable, default_value
-- Output: Success/failure message

CREATE OR REPLACE PROCEDURE alter_column_in_silver_table(
    table_name VARCHAR,
    column_name VARCHAR,
    new_data_type VARCHAR,
    nullable BOOLEAN DEFAULT TRUE,
    default_value VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    alter_statement VARCHAR;
    result_msg VARCHAR;
    table_exists BOOLEAN;
BEGIN
    -- Check if table exists
    CALL check_table_exists(:table_name) INTO table_exists;
    
    IF (NOT table_exists) THEN
        RETURN 'Table ' || UPPER(:table_name) || ' does not exist. Create it first.';
    END IF;
    
    -- Build ALTER TABLE statement to modify column type
    alter_statement := 'ALTER TABLE ' || UPPER(:table_name) || 
                       ' ALTER COLUMN ' || UPPER(:column_name) || 
                       ' SET DATA TYPE ' || UPPER(:new_data_type);
    
    -- Execute ALTER TABLE for data type
    EXECUTE IMMEDIATE :alter_statement;
    
    -- Handle nullable constraint
    IF (:nullable) THEN
        alter_statement := 'ALTER TABLE ' || UPPER(:table_name) || 
                          ' ALTER COLUMN ' || UPPER(:column_name) || ' DROP NOT NULL';
        EXECUTE IMMEDIATE :alter_statement;
    ELSE
        alter_statement := 'ALTER TABLE ' || UPPER(:table_name) || 
                          ' ALTER COLUMN ' || UPPER(:column_name) || ' SET NOT NULL';
        EXECUTE IMMEDIATE :alter_statement;
    END IF;
    
    -- Handle default value
    IF (:default_value IS NOT NULL AND :default_value != '' AND :default_value != '(None)') THEN
        alter_statement := 'ALTER TABLE ' || UPPER(:table_name) || 
                          ' ALTER COLUMN ' || UPPER(:column_name) || 
                          ' SET DEFAULT ' || :default_value;
        EXECUTE IMMEDIATE :alter_statement;
    ELSE
        alter_statement := 'ALTER TABLE ' || UPPER(:table_name) || 
                          ' ALTER COLUMN ' || UPPER(:column_name) || ' DROP DEFAULT';
        EXECUTE IMMEDIATE :alter_statement;
    END IF;
    
    result_msg := 'Successfully altered column ' || UPPER(:column_name) || 
                  ' in table ' || UPPER(:table_name);
    RETURN result_msg;
EXCEPTION
    WHEN OTHER THEN
        result_msg := 'Error altering column: ' || SQLERRM;
        RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Drop Column from Silver Table
-- ============================================
-- Purpose: Drop a column from an existing Silver table
-- Input: table_name, column_name
-- Output: Success/failure message

CREATE OR REPLACE PROCEDURE drop_column_from_silver_table(
    table_name VARCHAR,
    column_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    alter_statement VARCHAR;
    result_msg VARCHAR;
    table_exists BOOLEAN;
BEGIN
    -- Check if table exists
    CALL check_table_exists(:table_name) INTO table_exists;
    
    IF (NOT table_exists) THEN
        RETURN 'Table ' || UPPER(:table_name) || ' does not exist.';
    END IF;
    
    -- Build ALTER TABLE statement
    alter_statement := 'ALTER TABLE ' || UPPER(:table_name) || 
                       ' DROP COLUMN ' || UPPER(:column_name);
    
    -- Execute ALTER TABLE
    EXECUTE IMMEDIATE :alter_statement;
    
    result_msg := 'Successfully dropped column ' || UPPER(:column_name) || 
                  ' from table ' || UPPER(:table_name);
    RETURN result_msg;
EXCEPTION
    WHEN OTHER THEN
        result_msg := 'Error dropping column: ' || SQLERRM;
        RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Sync Table with Metadata
-- ============================================
-- Purpose: Create or alter a table to match its metadata definition
-- Input: table_name - Name of the table to sync
-- Output: Success/failure message

CREATE OR REPLACE PROCEDURE sync_table_with_metadata(
    table_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    table_exists BOOLEAN;
    result_msg VARCHAR;
BEGIN
    -- Check if table exists
    CALL check_table_exists(:table_name) INTO table_exists;
    
    IF (table_exists) THEN
        -- Table exists, recreate it to match metadata
        -- Drop and recreate is simpler than trying to alter each column
        EXECUTE IMMEDIATE 'DROP TABLE IF EXISTS ' || UPPER(:table_name);
        CALL create_silver_table(:table_name) INTO result_msg;
        RETURN 'Recreated table to match metadata: ' || result_msg;
    ELSE
        -- Table doesn't exist, create it
        CALL create_silver_table(:table_name) INTO result_msg;
        RETURN result_msg;
    END IF;
EXCEPTION
    WHEN OTHER THEN
        result_msg := 'Error syncing table: ' || SQLERRM;
        RETURN result_msg;
END;
$$;

-- ============================================
-- VIEW: Active Target Schemas Summary
-- ============================================
-- Purpose: Provide a summary view of active target schemas

CREATE OR REPLACE VIEW v_target_schemas_summary AS
SELECT 
    table_name,
    COUNT(*) as column_count,
    SUM(CASE WHEN NOT nullable THEN 1 ELSE 0 END) as required_columns,
    MAX(created_timestamp) as last_modified
FROM target_schemas
WHERE active = TRUE
GROUP BY table_name
ORDER BY table_name;

COMMENT ON VIEW v_target_schemas_summary IS 'Summary of active target table schemas. Shows column counts, required (non-nullable) column counts, and last modification timestamp for each target table.';

-- ============================================
-- VIEW: Table Creation Readiness
-- ============================================
-- Purpose: Show which tables are ready to be created

CREATE OR REPLACE VIEW v_table_creation_readiness AS
SELECT 
    table_name,
    column_count,
    CASE 
        WHEN column_count = 0 THEN 'NOT READY - No columns defined'
        ELSE 'READY'
    END as status
FROM v_target_schemas_summary
ORDER BY status, table_name;

COMMENT ON VIEW v_table_creation_readiness IS 'Shows readiness status for target table creation. Indicates whether each table has sufficient column definitions to be created in the Silver schema.';

