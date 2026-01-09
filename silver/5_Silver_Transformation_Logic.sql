-- ============================================
-- SILVER LAYER TRANSFORMATION LOGIC (Python Version)
-- ============================================
-- Purpose: Core transformation orchestration procedures
-- 
-- This script creates procedures for:
--   1. Schema discovery from Bronze VARIANT data
--   2. Main Bronze → Silver transformation orchestration
--   3. Incremental processing with watermarks
--   4. Batch processing and error handling
--
-- Transformation Flow:
--   1. Discover Bronze schema
--   2. Extract and map fields
--   3. Apply transformation rules
--   4. MERGE into Silver tables
--   5. Log metrics and update watermarks
--
-- Note: Main procedures implemented in Python for better control flow
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';

-- Set role name
SET role_admin = (SELECT '$DATABASE_NAME' || '_ADMIN');

USE ROLE IDENTIFIER($role_admin);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- FUNCTION: Generate Batch ID
-- ============================================
-- Purpose: Generate unique batch identifier
-- Output: Batch ID string

CREATE OR REPLACE FUNCTION generate_batch_id()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    'BATCH_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS') || '_' || 
    SUBSTRING(UUID_STRING(), 1, 8)
$$;

-- ============================================
-- PROCEDURE: Discover Bronze Schema (Python)
-- ============================================
-- Purpose: Analyze VARIANT column structure in Bronze table
-- Input: source_table - Bronze table to analyze (default: RAW_DATA_TABLE)
--        sample_size - Number of records to sample
-- Output: Schema discovery results as string

CREATE OR REPLACE PROCEDURE discover_bronze_schema(
    source_table VARCHAR,
    bronze_schema VARCHAR,
    sample_size INTEGER
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'discover_bronze_schema'
AS
$$
def discover_bronze_schema(session, source_table, bronze_schema, sample_size):
    """Discover schema from Bronze VARIANT data"""
    
    try:
        # Query to flatten and analyze Bronze data
        query = f"""
            WITH flattened_data AS (
                SELECT 
                    f.key as field_name,
                    f.value as field_value,
                    TYPEOF(f.value) as data_type
                FROM {bronze_schema}.{source_table},
                LATERAL FLATTEN(input => RAW_DATA) f
                WHERE RAW_DATA IS NOT NULL
                LIMIT {sample_size}
            )
            SELECT 
                field_name,
                MODE(data_type) as data_type,
                SUM(CASE WHEN field_value IS NULL THEN 1 ELSE 0 END) as null_count,
                COUNT(DISTINCT field_value) as distinct_count,
                COUNT(*) as sample_count
            FROM flattened_data
            GROUP BY field_name
            ORDER BY field_name
        """
        
        result_df = session.sql(query).collect()
        
        if not result_df:
            return "No fields discovered in Bronze table"
        
        # Format results as string
        results = []
        for row in result_df:
            results.append(
                f"Field: {row['FIELD_NAME']}, "
                f"Type: {row['DATA_TYPE']}, "
                f"Nulls: {row['NULL_COUNT']}/{row['SAMPLE_COUNT']}, "
                f"Distinct: {row['DISTINCT_COUNT']}"
            )
        
        return f"Discovered {len(results)} fields:\\n" + "\\n".join(results)
        
    except Exception as e:
        return f"Error discovering schema: {str(e)}"
$$;

-- ============================================
-- PROCEDURE: Transform Bronze to Silver (Python)
-- ============================================
-- Purpose: Main transformation orchestration procedure
-- Input: source_table - Bronze table (default: RAW_DATA_TABLE)
--        target_table - Silver target table
--        bronze_schema - Bronze schema name
--        batch_size - Number of records to process per batch
--        apply_rules - Whether to apply transformation rules
--        incremental - Whether to use watermark-based incremental processing
-- Output: Transformation results
--
-- Note: FILE_NAME is automatically included as SOURCE_FILE_NAME if:
--       1. SOURCE_FILE_NAME exists in target schema
--       2. No explicit mapping for SOURCE_FILE_NAME exists
--       This ensures source file tracking is always preserved from Bronze layer

CREATE OR REPLACE PROCEDURE transform_bronze_to_silver(
    source_table VARCHAR,
    target_table VARCHAR,
    bronze_schema VARCHAR,
    batch_size INTEGER,
    apply_rules BOOLEAN,
    incremental BOOLEAN
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'transform_bronze_to_silver'
AS
$$
import uuid
from datetime import datetime

def transform_bronze_to_silver(session, source_table, target_table, bronze_schema, 
                                batch_size, apply_rules, incremental):
    """Main Bronze to Silver transformation orchestration"""
    
    # Generate batch ID
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    batch_id = f"BATCH_{timestamp}_{str(uuid.uuid4())[:8]}"
    watermark_id = f"{source_table.upper()}_TO_{target_table.upper()}"
    
    try:
        # Initialize processing log
        session.sql(f"""
            INSERT INTO silver_processing_log (
                batch_id, source_table, target_table, status, start_timestamp
            )
            VALUES (
                '{batch_id}',
                '{source_table.upper()}',
                '{target_table.upper()}',
                'PROCESSING',
                CURRENT_TIMESTAMP()
            )
        """).collect()
        
        # Get watermark for incremental processing
        last_processed_id = 0
        if incremental:
            watermark_result = session.sql(f"""
                SELECT COALESCE(last_processed_id, 0) as last_id
                FROM processing_watermarks
                WHERE watermark_id = '{watermark_id}'
            """).collect()
            
            if watermark_result:
                last_processed_id = watermark_result[0]['LAST_ID']
        
        # Get first column for tracking (since we don't enforce primary keys)
        pk_result = session.sql(f"""
            SELECT column_name
            FROM target_schemas
            WHERE table_name = '{target_table.upper()}'
              AND active = TRUE
            ORDER BY schema_id
            LIMIT 1
        """).collect()
        
        if not pk_result:
            raise Exception(f"No columns defined for target table: {target_table}")
        
        pk_column = pk_result[0]['COLUMN_NAME']
        
        # Get approved field mappings
        mappings_result = session.sql(f"""
            SELECT 
                source_field,
                target_column,
                COALESCE(transformation_logic, 'RAW_DATA:' || source_field) as field_expression
            FROM field_mappings
            WHERE target_table = '{target_table.upper()}'
              AND approved = TRUE
            ORDER BY target_column
        """).collect()
        
        if not mappings_result:
            raise Exception(f"No approved mappings found for target table: {target_table}")
        
        # Build column list for SELECT
        select_columns = []
        target_columns_mapped = []
        for mapping in mappings_result:
            expr = mapping['FIELD_EXPRESSION']
            col = mapping['TARGET_COLUMN']
            select_columns.append(f"{expr} as {col}")
            target_columns_mapped.append(col)
        
        # Always include FILE_NAME as SOURCE_FILE_NAME if it's in the target schema
        # but not already mapped
        if 'SOURCE_FILE_NAME' not in target_columns_mapped:
            select_columns.append("FILE_NAME as SOURCE_FILE_NAME")
        
        columns_str = ", ".join(select_columns)
        
        # Create temporary table with mapped data
        temp_table = f"TEMP_TRANSFORM_{batch_id.replace('-', '_')}"
        
        create_temp_query = f"""
            CREATE OR REPLACE TABLE {temp_table} AS
            SELECT 
                RAW_ID,
                {columns_str}
            FROM {bronze_schema}.{source_table.upper()}
            WHERE RAW_ID > {last_processed_id}
            LIMIT {batch_size}
        """
        
        session.sql(create_temp_query).collect()
        
        # Count records read
        count_result = session.sql(f"SELECT COUNT(*) as cnt FROM {temp_table}").collect()
        records_read = count_result[0]['CNT'] if count_result else 0
        
        if records_read == 0:
            session.sql(f"""
                UPDATE silver_processing_log
                SET status = 'SUCCESS',
                    end_timestamp = CURRENT_TIMESTAMP(),
                    records_read = 0,
                    records_processed = 0
                WHERE batch_id = '{batch_id}'
            """).collect()
            
            return "No new records to process"
        
        # Apply transformation rules if enabled
        rules_applied = 0
        if apply_rules:
            try:
                session.call('apply_quality_rules', batch_id, temp_table)
                rules_applied += 1
            except:
                pass
            
            try:
                session.call('apply_business_rules', batch_id, temp_table)
                rules_applied += 1
            except:
                pass
            
            try:
                session.call('apply_standardization_rules', batch_id, temp_table)
                rules_applied += 1
            except:
                pass
            
            try:
                session.call('apply_deduplication_rules', batch_id, temp_table, target_table)
                rules_applied += 1
            except:
                pass
        
        # Count records after rules
        count_result = session.sql(f"SELECT COUNT(*) as cnt FROM {temp_table}").collect()
        records_processed = count_result[0]['CNT'] if count_result else 0
        records_rejected = records_read - records_processed
        
        # Get columns that were actually mapped (exist in temp table)
        # These are the columns we added to target_columns_mapped earlier
        mapped_columns = target_columns_mapped.copy()
        
        # Ensure SOURCE_FILE_NAME is included if it was added
        if 'SOURCE_FILE_NAME' not in mapped_columns:
            mapped_columns.append('SOURCE_FILE_NAME')
        
        # Build MERGE query using only mapped columns
        non_pk_columns = [col for col in mapped_columns if col != pk_column]
        
        cols_str = ", ".join(mapped_columns)
        src_cols_str = ", ".join([f"src.{col}" for col in mapped_columns])
        update_cols_str = ", ".join([f"tgt.{col} = src.{col}" for col in non_pk_columns])
        
        merge_query = f"""
            MERGE INTO {target_table.upper()} tgt
            USING {temp_table} src
            ON tgt.{pk_column} = src.{pk_column}
            WHEN MATCHED THEN UPDATE SET {update_cols_str}
            WHEN NOT MATCHED THEN INSERT ({cols_str}) VALUES ({src_cols_str})
        """
        
        session.sql(merge_query).collect()
        
        # Get max RAW_ID for watermark
        max_id_result = session.sql(f"SELECT MAX(RAW_ID) as max_id FROM {temp_table}").collect()
        max_id = max_id_result[0]['MAX_ID'] if max_id_result else last_processed_id
        
        # Update watermark
        session.sql(f"""
            MERGE INTO processing_watermarks wm
            USING (
                SELECT 
                    '{watermark_id}' as watermark_id,
                    '{source_table.upper()}' as source_table,
                    '{target_table.upper()}' as target_table,
                    {max_id} as max_id
            ) src
            ON wm.watermark_id = src.watermark_id
            WHEN MATCHED THEN UPDATE SET
                last_processed_id = src.max_id,
                last_processed_timestamp = CURRENT_TIMESTAMP(),
                records_processed = wm.records_processed + {records_processed},
                last_batch_id = '{batch_id}',
                updated_timestamp = CURRENT_TIMESTAMP()
            WHEN NOT MATCHED THEN INSERT (
                watermark_id, source_table, target_table,
                last_processed_id, last_processed_timestamp,
                records_processed, last_batch_id
            ) VALUES (
                src.watermark_id, src.source_table, src.target_table,
                src.max_id, CURRENT_TIMESTAMP(),
                {records_processed}, '{batch_id}'
            )
        """).collect()
        
        # Update processing log
        session.sql(f"""
            UPDATE silver_processing_log
            SET status = 'SUCCESS',
                end_timestamp = CURRENT_TIMESTAMP(),
                records_read = {records_read},
                records_processed = {records_processed},
                records_inserted = {records_processed},
                records_updated = 0,
                records_rejected = {records_rejected},
                rules_applied = {rules_applied}
            WHERE batch_id = '{batch_id}'
        """).collect()
        
        # Clean up temp table
        try:
            session.sql(f"DROP TABLE IF EXISTS {temp_table}").collect()
        except:
            pass
        
        return (f"Batch {batch_id} completed successfully. "
                f"Read: {records_read}, Processed: {records_processed}, "
                f"Rejected: {records_rejected}, Rules: {rules_applied}")
        
    except Exception as e:
        error_msg = str(e)
        
        # Update processing log with error
        try:
            session.sql(f"""
                UPDATE silver_processing_log
                SET status = 'FAILED',
                    end_timestamp = CURRENT_TIMESTAMP(),
                    error_message = '{error_msg.replace("'", "''")}'
                WHERE batch_id = '{batch_id}'
            """).collect()
        except:
            pass
        
        return f"Batch {batch_id} FAILED: {error_msg}"
$$;

-- ============================================
-- PROCEDURE: Process All Pending Bronze Data (Python)
-- ============================================
-- Purpose: Process all pending Bronze data for a target table
-- Input: target_table - Silver target table
--        bronze_schema - Bronze schema name
--        batch_size - Records per batch
-- Output: Summary of all batches processed

CREATE OR REPLACE PROCEDURE process_all_pending_bronze(
    target_table VARCHAR,
    bronze_schema VARCHAR,
    batch_size INTEGER
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'process_all_pending_bronze'
AS
$$
def process_all_pending_bronze(session, target_table, bronze_schema, batch_size):
    """Process all pending Bronze data in batches"""
    
    batch_count = 0
    total_processed = 0
    
    try:
        while batch_count < 100:  # Safety limit
            # Process one batch
            result = session.call(
                'transform_bronze_to_silver',
                'RAW_DATA_TABLE',
                target_table,
                bronze_schema,
                batch_size,
                True,  # apply_rules
                True   # incremental
            )
            
            batch_count += 1
            
            # Check if no more records
            if 'No new records' in result:
                break
            
            # Extract processed count from result (simplified)
            if 'Processed:' in result:
                try:
                    processed_str = result.split('Processed:')[1].split(',')[0].strip()
                    total_processed += int(processed_str)
                except:
                    pass
        
        return (f"Completed {batch_count} batches. "
                f"Total records processed: {total_processed}")
        
    except Exception as e:
        return f"Error processing batches: {str(e)}"
$$;

-- ============================================
-- PROCEDURE: Reset Watermark
-- ============================================
-- Purpose: Reset watermark for a source/target pair
-- Input: source_table - Bronze source table
--        target_table - Silver target table
-- Output: Confirmation message

CREATE OR REPLACE PROCEDURE reset_watermark(
    source_table VARCHAR,
    target_table VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    watermark_id VARCHAR;
    result_msg VARCHAR;
BEGIN
    watermark_id := UPPER(:source_table) || '_TO_' || UPPER(:target_table);
    
    DELETE FROM processing_watermarks
    WHERE watermark_id = :watermark_id;
    
    result_msg := 'Watermark reset for: ' || :watermark_id;
    RETURN result_msg;
END;
$$;

