-- ============================================
-- SILVER LAYER RULES ENGINE (Python Version)
-- ============================================
-- Purpose: Comprehensive transformation rules engine
-- 
-- This script creates procedures for:
--   1. Data Quality Rules (null checks, format validation, range checks)
--   2. Business Logic Transformations (calculations, lookups, conditional logic)
--   3. Standardization Rules (date formats, name casing, code mapping)
--   4. Deduplication and Conflict Resolution
--
-- Rule Types:
--   - DATA_QUALITY: Validation rules for data integrity
--   - BUSINESS_LOGIC: Business calculations and derivations
--   - STANDARDIZATION: Data normalization and standardization
--   - DEDUPLICATION: Duplicate detection and resolution
--
-- Note: Procedures implemented in Python to avoid SQL scripting limitations
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
-- PROCEDURE: Load Transformation Rules from CSV (Python)
-- ============================================
-- Purpose: Load transformation rules from CSV file
-- Input: stage_path - Path to CSV file (e.g., '@SILVER_CONFIG/transformation_rules.csv')
-- Output: Number of rules loaded

CREATE OR REPLACE PROCEDURE load_transformation_rules_from_csv(stage_path VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    rows_loaded INTEGER DEFAULT 0;
    result_msg VARCHAR;
BEGIN
    -- Create temporary table for CSV data
    CREATE OR REPLACE TEMPORARY TABLE temp_transformation_rules (
        rule_id VARCHAR(50),
        rule_name VARCHAR(500),
        rule_type VARCHAR(50),
        target_table VARCHAR(500),
        target_column VARCHAR(500),
        rule_logic VARCHAR(5000),
        rule_parameters VARCHAR(5000),
        priority VARCHAR(10),
        error_action VARCHAR(50),
        description VARCHAR(5000),
        active VARCHAR(10)
    );
    
    -- Load CSV into temporary table
    EXECUTE IMMEDIATE 'COPY INTO temp_transformation_rules FROM ' || :stage_path || '
        FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = ''"'')';
    
    -- Merge into transformation_rules table (prevents duplicates)
    MERGE INTO transformation_rules tr
    USING (
        SELECT 
            UPPER(rule_id) as rule_id,
            rule_name,
            UPPER(rule_type) as rule_type,
            CASE WHEN target_table IS NOT NULL AND target_table != '' 
                 THEN UPPER(target_table) ELSE NULL END as target_table,
            CASE WHEN target_column IS NOT NULL AND target_column != '' 
                 THEN UPPER(target_column) ELSE NULL END as target_column,
            rule_logic,
            TRY_PARSE_JSON(rule_parameters) as rule_parameters,
            COALESCE(TRY_CAST(priority AS INTEGER), 100) as priority,
            COALESCE(UPPER(error_action), 'LOG') as error_action,
            description,
            CASE WHEN UPPER(active) IN ('TRUE', 'YES', '1') THEN TRUE ELSE FALSE END as active
        FROM temp_transformation_rules
    ) src
    ON tr.rule_id = src.rule_id
    WHEN MATCHED THEN UPDATE SET
        rule_name = src.rule_name,
        rule_type = src.rule_type,
        target_table = src.target_table,
        target_column = src.target_column,
        rule_logic = src.rule_logic,
        rule_parameters = src.rule_parameters,
        priority = src.priority,
        error_action = src.error_action,
        description = src.description,
        active = src.active,
        updated_timestamp = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        rule_id, rule_name, rule_type, target_table, target_column,
        rule_logic, rule_parameters, priority, error_action, description, active
    ) VALUES (
        src.rule_id, src.rule_name, src.rule_type, src.target_table, src.target_column,
        src.rule_logic, src.rule_parameters, src.priority, src.error_action, src.description, src.active
    );
    
    rows_loaded := SQLROWCOUNT;
    
    -- Clean up
    DROP TABLE IF EXISTS temp_transformation_rules;
    
    result_msg := 'Successfully loaded/updated ' || rows_loaded || ' transformation rules from ' || :stage_path;
    RETURN result_msg;
    
EXCEPTION
    WHEN OTHER THEN
        result_msg := 'Error loading transformation rules: ' || SQLERRM;
        RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Apply Data Quality Rules (Python)
-- ============================================
-- Purpose: Apply data quality validation rules to a batch
-- Input: batch_id - Batch identifier
--        temp_table_name - Temporary table with data to validate
-- Output: Validation results with pass/fail counts

CREATE OR REPLACE PROCEDURE apply_quality_rules(
    batch_id VARCHAR,
    temp_table_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'apply_quality_rules'
AS
$$
def apply_quality_rules(session, batch_id, temp_table_name):
    """Apply data quality validation rules to a batch"""
    
    try:
        # Get all active data quality rules
        rules_query = """
            SELECT rule_id, rule_name, target_table, target_column, rule_logic, 
                   rule_parameters, error_action, priority
            FROM transformation_rules
            WHERE rule_type = 'DATA_QUALITY'
              AND active = TRUE
            ORDER BY priority
        """
        
        rules = session.sql(rules_query).collect()
        
        total_rules = 0
        total_violations = 0
        
        for rule in rules:
            total_rules += 1
            rule_id = rule['RULE_ID']
            rule_name = rule['RULE_NAME']
            target_table = rule['TARGET_TABLE']
            target_column = rule['TARGET_COLUMN']
            rule_logic = rule['RULE_LOGIC']
            error_action = rule['ERROR_ACTION']
            
            try:
                # Build validation query
                validation_query = f"""
                    SELECT COUNT(*) as violation_count
                    FROM {temp_table_name}
                    WHERE NOT ({target_column} {rule_logic})
                """
                
                result = session.sql(validation_query).collect()
                violation_count = result[0]['VIOLATION_COUNT'] if result else 0
                
                # Log metric
                session.sql(f"""
                    INSERT INTO data_quality_metrics (
                        batch_id, table_name, column_name, metric_type,
                        metric_value, threshold_value, pass_fail, rule_id
                    )
                    VALUES (
                        '{batch_id}',
                        '{target_table}',
                        '{target_column}',
                        'RULE_VIOLATIONS',
                        {violation_count},
                        0,
                        '{"PASS" if violation_count == 0 else "FAIL"}',
                        '{rule_id}'
                    )
                """).collect()
                
                # Handle violations based on error_action
                if violation_count > 0:
                    total_violations += violation_count
                    
                    if error_action == 'REJECT':
                        # Delete violating records
                        session.sql(f"""
                            DELETE FROM {temp_table_name}
                            WHERE NOT ({target_column} {rule_logic})
                        """).collect()
                    
                    elif error_action == 'QUARANTINE':
                        # Move to quarantine table
                        session.sql(f"""
                            INSERT INTO quarantine_records (
                                batch_id, source_table, target_table, source_record, 
                                failed_rules, error_details
                            )
                            SELECT 
                                '{batch_id}',
                                'TEMP',
                                '{target_table}',
                                TO_VARIANT(temp.*),
                                ARRAY_CONSTRUCT('{rule_id}'),
                                OBJECT_CONSTRUCT(
                                    'rule', '{rule_name.replace("'", "''")}',
                                    'column', '{target_column}',
                                    'violation_type', 'DATA_QUALITY'
                                )
                            FROM {temp_table_name} temp
                            WHERE NOT (temp.{target_column} {rule_logic})
                        """).collect()
                        
                        # Delete from temp table
                        session.sql(f"""
                            DELETE FROM {temp_table_name}
                            WHERE NOT ({target_column} {rule_logic})
                        """).collect()
                    
                    # else: LOG (default) - just log, don't remove records
                
            except Exception as rule_error:
                # Log error but continue with other rules
                session.sql(f"""
                    INSERT INTO data_quality_metrics (
                        batch_id, table_name, column_name, metric_type,
                        metric_value, pass_fail, rule_id, details
                    )
                    VALUES (
                        '{batch_id}',
                        '{target_table}',
                        '{target_column}',
                        'RULE_ERROR',
                        0,
                        'FAIL',
                        '{rule_id}',
                        OBJECT_CONSTRUCT('error', '{str(rule_error).replace("'", "''")}')
                    )
                """).collect()
        
        return f"Applied {total_rules} data quality rules. Total violations: {total_violations}"
        
    except Exception as e:
        return f"Error applying quality rules: {str(e)}"
$$;

-- ============================================
-- PROCEDURE: Apply Business Logic Rules (Python)
-- ============================================
-- Purpose: Apply business logic transformations (calculations, lookups)
-- Input: batch_id - Batch identifier
--        temp_table_name - Temporary table with data to transform
-- Output: Transformation results

CREATE OR REPLACE PROCEDURE apply_business_rules(
    batch_id VARCHAR,
    temp_table_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'apply_business_rules'
AS
$$
def apply_business_rules(session, batch_id, temp_table_name):
    """Apply business logic transformations"""
    
    try:
        # Get all active business logic rules
        rules_query = """
            SELECT rule_id, rule_name, target_table, target_column, rule_logic, 
                   rule_parameters, priority
            FROM transformation_rules
            WHERE rule_type = 'BUSINESS_LOGIC'
              AND active = TRUE
            ORDER BY priority
        """
        
        rules = session.sql(rules_query).collect()
        total_rules = 0
        
        for rule in rules:
            total_rules += 1
            rule_id = rule['RULE_ID']
            target_table = rule['TARGET_TABLE']
            target_column = rule['TARGET_COLUMN']
            rule_logic = rule['RULE_LOGIC']
            
            try:
                # Build transformation query
                transform_query = f"""
                    UPDATE {temp_table_name}
                    SET {target_column} = {rule_logic}
                """
                
                result = session.sql(transform_query).collect()
                rows_affected = result[0]['number of rows updated'] if result else 0
                
                # Log metric
                session.sql(f"""
                    INSERT INTO data_quality_metrics (
                        batch_id, table_name, column_name, metric_type,
                        metric_value, pass_fail, rule_id
                    )
                    VALUES (
                        '{batch_id}',
                        '{target_table}',
                        '{target_column}',
                        'BUSINESS_TRANSFORM',
                        {rows_affected},
                        'PASS',
                        '{rule_id}'
                    )
                """).collect()
                
            except Exception as rule_error:
                # Log error but continue
                session.sql(f"""
                    INSERT INTO data_quality_metrics (
                        batch_id, table_name, column_name, metric_type,
                        metric_value, pass_fail, rule_id, details
                    )
                    VALUES (
                        '{batch_id}',
                        '{target_table}',
                        '{target_column}',
                        'BUSINESS_TRANSFORM_ERROR',
                        0,
                        'FAIL',
                        '{rule_id}',
                        OBJECT_CONSTRUCT('error', '{str(rule_error).replace("'", "''")}')
                    )
                """).collect()
        
        return f"Applied {total_rules} business logic rules"
        
    except Exception as e:
        return f"Error applying business rules: {str(e)}"
$$;

-- ============================================
-- PROCEDURE: Apply Standardization Rules (Python)
-- ============================================
-- Purpose: Apply data standardization rules (dates, casing, codes)
-- Input: batch_id - Batch identifier
--        temp_table_name - Temporary table with data to standardize
-- Output: Standardization results

CREATE OR REPLACE PROCEDURE apply_standardization_rules(
    batch_id VARCHAR,
    temp_table_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'apply_standardization_rules'
AS
$$
def apply_standardization_rules(session, batch_id, temp_table_name):
    """Apply data standardization rules"""
    
    try:
        # Get all active standardization rules
        rules_query = """
            SELECT rule_id, rule_name, target_table, target_column, rule_logic, 
                   rule_parameters, priority
            FROM transformation_rules
            WHERE rule_type = 'STANDARDIZATION'
              AND active = TRUE
            ORDER BY priority
        """
        
        rules = session.sql(rules_query).collect()
        total_rules = 0
        
        for rule in rules:
            total_rules += 1
            rule_id = rule['RULE_ID']
            target_table = rule['TARGET_TABLE']
            target_column = rule['TARGET_COLUMN']
            rule_logic = rule['RULE_LOGIC']
            
            try:
                # Build standardization query
                transform_query = f"""
                    UPDATE {temp_table_name}
                    SET {target_column} = {rule_logic}({target_column})
                    WHERE {target_column} IS NOT NULL
                """
                
                result = session.sql(transform_query).collect()
                rows_affected = result[0]['number of rows updated'] if result else 0
                
                # Log metric
                session.sql(f"""
                    INSERT INTO data_quality_metrics (
                        batch_id, table_name, column_name, metric_type,
                        metric_value, pass_fail, rule_id
                    )
                    VALUES (
                        '{batch_id}',
                        '{target_table}',
                        '{target_column}',
                        'STANDARDIZATION',
                        {rows_affected},
                        'PASS',
                        '{rule_id}'
                    )
                """).collect()
                
            except Exception as rule_error:
                # Log error but continue
                session.sql(f"""
                    INSERT INTO data_quality_metrics (
                        batch_id, table_name, column_name, metric_type,
                        metric_value, pass_fail, rule_id, details
                    )
                    VALUES (
                        '{batch_id}',
                        '{target_table}',
                        '{target_column}',
                        'STANDARDIZATION_ERROR',
                        0,
                        'FAIL',
                        '{rule_id}',
                        OBJECT_CONSTRUCT('error', '{str(rule_error).replace("'", "''")}')
                    )
                """).collect()
        
        return f"Applied {total_rules} standardization rules"
        
    except Exception as e:
        return f"Error applying standardization rules: {str(e)}"
$$;

-- ============================================
-- PROCEDURE: Apply Deduplication Rules (Python)
-- ============================================
-- Purpose: Detect and resolve duplicate records
-- Input: batch_id - Batch identifier
--        temp_table_name - Temporary table with data to deduplicate
--        target_table - Target table name for dedup rules
-- Output: Deduplication results

CREATE OR REPLACE PROCEDURE apply_deduplication_rules(
    batch_id VARCHAR,
    temp_table_name VARCHAR,
    target_table VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'apply_deduplication_rules'
AS
$$
import json

def apply_deduplication_rules(session, batch_id, temp_table_name, target_table):
    """Apply deduplication rules"""
    
    try:
        # Get all active deduplication rules for this target table
        rules_query = f"""
            SELECT rule_id, rule_name, rule_logic, rule_parameters, priority
            FROM transformation_rules
            WHERE rule_type = 'DEDUPLICATION'
              AND (target_table IS NULL OR target_table = '{target_table.upper()}')
              AND active = TRUE
            ORDER BY priority
        """
        
        rules = session.sql(rules_query).collect()
        total_rules = 0
        
        for rule in rules:
            total_rules += 1
            rule_id = rule['RULE_ID']
            rule_name = rule['RULE_NAME']
            dedup_key = rule['RULE_LOGIC']  # Comma-separated list of columns
            
            # Parse rule parameters
            rule_params = rule['RULE_PARAMETERS']
            resolution_strategy = 'KEEP_FIRST'
            if rule_params:
                try:
                    params_dict = json.loads(rule_params)
                    resolution_strategy = params_dict.get('strategy', 'KEEP_FIRST')
                except:
                    pass
            
            try:
                # Count duplicates before dedup
                count_query = f"""
                    SELECT COUNT(*) - COUNT(DISTINCT {dedup_key}) as duplicate_count
                    FROM {temp_table_name}
                """
                result = session.sql(count_query).collect()
                duplicate_count = result[0]['DUPLICATE_COUNT'] if result else 0
                
                # Apply deduplication based on strategy
                if resolution_strategy == 'KEEP_FIRST':
                    # Use ROW_NUMBER to keep first occurrence
                    session.sql(f"""
                        DELETE FROM {temp_table_name}
                        WHERE (SELECT ROW_NUMBER() OVER (PARTITION BY {dedup_key} ORDER BY ROWID) FROM {temp_table_name}) > 1
                    """).collect()
                
                elif resolution_strategy == 'KEEP_LAST':
                    # Use ROW_NUMBER to keep last occurrence
                    session.sql(f"""
                        CREATE OR REPLACE TEMPORARY TABLE temp_dedup AS
                        SELECT *
                        FROM (
                            SELECT *,
                                   ROW_NUMBER() OVER (PARTITION BY {dedup_key} ORDER BY ROWID DESC) as rn
                            FROM {temp_table_name}
                        )
                        WHERE rn = 1
                    """).collect()
                    
                    session.sql(f"DELETE FROM {temp_table_name}").collect()
                    session.sql(f"INSERT INTO {temp_table_name} SELECT * FROM temp_dedup").collect()
                    session.sql("DROP TABLE IF EXISTS temp_dedup").collect()
                
                elif resolution_strategy == 'QUARANTINE_ALL':
                    # Move all duplicates to quarantine
                    session.sql(f"""
                        INSERT INTO quarantine_records (
                            batch_id, source_table, target_table, source_record,
                            failed_rules, error_details
                        )
                        SELECT 
                            '{batch_id}',
                            'TEMP',
                            '{target_table.upper()}',
                            TO_VARIANT(t1.*),
                            ARRAY_CONSTRUCT('{rule_id}'),
                            OBJECT_CONSTRUCT(
                                'rule', '{rule_name.replace("'", "''")}',
                                'duplicate_key', '{dedup_key}',
                                'violation_type', 'DUPLICATE'
                            )
                        FROM {temp_table_name} t1
                        WHERE (
                            SELECT COUNT(*)
                            FROM {temp_table_name} t2
                            WHERE t2.{dedup_key} = t1.{dedup_key}
                        ) > 1
                    """).collect()
                    
                    # Delete duplicates from temp table
                    session.sql(f"""
                        DELETE FROM {temp_table_name}
                        WHERE (
                            SELECT COUNT(*)
                            FROM {temp_table_name} t2
                            WHERE t2.{dedup_key} = {temp_table_name}.{dedup_key}
                        ) > 1
                    """).collect()
                
                # Log metric
                session.sql(f"""
                    INSERT INTO data_quality_metrics (
                        batch_id, table_name, metric_type,
                        metric_value, pass_fail, rule_id
                    )
                    VALUES (
                        '{batch_id}',
                        '{target_table.upper()}',
                        'DUPLICATES_REMOVED',
                        {duplicate_count},
                        '{"PASS" if duplicate_count == 0 else "WARNING"}',
                        '{rule_id}'
                    )
                """).collect()
                
            except Exception as rule_error:
                # Log error but continue
                session.sql(f"""
                    INSERT INTO data_quality_metrics (
                        batch_id, table_name, metric_type,
                        metric_value, pass_fail, rule_id, details
                    )
                    VALUES (
                        '{batch_id}',
                        '{target_table.upper()}',
                        'DEDUPLICATION_ERROR',
                        0,
                        'FAIL',
                        '{rule_id}',
                        OBJECT_CONSTRUCT('error', '{str(rule_error).replace("'", "''")}')
                    )
                """).collect()
        
        return f"Applied {total_rules} deduplication rules"
        
    except Exception as e:
        return f"Error applying deduplication rules: {str(e)}"
$$;

-- ============================================
-- VIEW: Rules Summary by Type
-- ============================================
-- Purpose: Summary of transformation rules by type and status

CREATE OR REPLACE VIEW v_rules_summary AS
SELECT 
    rule_type,
    active,
    COUNT(*) as rule_count,
    COUNT(DISTINCT target_table) as affected_tables,
    AVG(priority) as avg_priority
FROM transformation_rules
GROUP BY rule_type, active
ORDER BY rule_type, active DESC;

COMMENT ON VIEW v_rules_summary IS 'Summary of transformation rules by type (QUALITY, BUSINESS, STANDARDIZATION, DEDUPLICATION) and active status. Shows rule counts, affected tables, and average priority for each category.';

-- ============================================
-- VIEW: Rule Execution History
-- ============================================
-- Purpose: Show rule execution history with pass/fail rates

CREATE OR REPLACE VIEW v_rule_execution_history AS
SELECT 
    dqm.rule_id,
    tr.rule_name,
    tr.rule_type,
    COUNT(*) as execution_count,
    SUM(CASE WHEN dqm.pass_fail = 'PASS' THEN 1 ELSE 0 END) as pass_count,
    SUM(CASE WHEN dqm.pass_fail = 'FAIL' THEN 1 ELSE 0 END) as fail_count,
    SUM(CASE WHEN dqm.pass_fail = 'WARNING' THEN 1 ELSE 0 END) as warning_count,
    AVG(dqm.metric_value) as avg_metric_value,
    MAX(dqm.measurement_timestamp) as last_execution
FROM data_quality_metrics dqm
JOIN transformation_rules tr ON dqm.rule_id = tr.rule_id
GROUP BY dqm.rule_id, tr.rule_name, tr.rule_type
ORDER BY last_execution DESC;

COMMENT ON VIEW v_rule_execution_history IS 'Historical execution statistics for transformation rules. Shows pass/fail/warning counts, execution frequency, average metric values, and last execution timestamp for monitoring rule effectiveness.';
