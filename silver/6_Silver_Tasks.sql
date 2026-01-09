-- ============================================
-- SILVER LAYER TASK PIPELINE (Simplified)
-- ============================================
-- Purpose: Automated task pipeline for Silver transformations
-- 
-- This script creates:
--   1. Bronze completion sensor task
--   2. Silver discovery task (identifies new Bronze data)
--   3. Silver transformation task (calls transformation procedures)
--   4. Helper procedures for task management
--
-- Task Dependencies:
--   bronze_completion_sensor → silver_discovery_task → silver_transformation_task
--
-- Note: Simplified to avoid complex cursor logic in tasks
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';
SET WAREHOUSE_NAME = '$WAREHOUSE_NAME';
SET SILVER_TRANSFORM_SCHEDULE_MINUTES = '$SILVER_TRANSFORM_SCHEDULE_MINUTES';

-- Set role name
SET role_admin = (SELECT '$DATABASE_NAME' || '_ADMIN');

USE ROLE IDENTIFIER($role_admin);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- TASK: Bronze Completion Sensor
-- ============================================
-- Purpose: Check for new Bronze data
-- Schedule: Every 5 minutes
-- Dependencies: None

CREATE OR REPLACE TASK bronze_completion_sensor
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    SCHEDULE = '5 MINUTE'
AS
    SELECT 'Checking for new Bronze data' as status;

-- ============================================
-- TASK: Silver Discovery Task
-- ============================================
-- Purpose: Discover new Bronze data ready for transformation
-- Schedule: Triggered by bronze_completion_sensor
-- Dependencies: bronze_completion_sensor

CREATE OR REPLACE TASK silver_discovery_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    AFTER bronze_completion_sensor
AS
    INSERT INTO silver_processing_log (
        batch_id, source_table, target_table, status, start_timestamp,
        processing_metadata
    )
    SELECT 
        'DISCOVERY_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'),
        'RAW_DATA_TABLE',
        'ALL_TARGETS',
        'PROCESSING',
        CURRENT_TIMESTAMP(),
        OBJECT_CONSTRUCT(
            'bronze_records', (SELECT COUNT(*) FROM IDENTIFIER('$BRONZE_SCHEMA_NAME.RAW_DATA_TABLE')),
            'target_tables', (SELECT COUNT(DISTINCT table_name) FROM target_schemas WHERE active = TRUE)
        );

-- ============================================
-- PROCEDURE: Transform All Target Tables
-- ============================================
-- Purpose: Transform Bronze data for all active target tables
-- Called by: silver_transformation_task

CREATE OR REPLACE PROCEDURE transform_all_targets(
    bronze_schema VARCHAR,
    batch_size INTEGER
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'transform_all_targets'
AS
$$
def transform_all_targets(session, bronze_schema, batch_size):
    """Transform Bronze data for all active target tables"""
    
    # Get all active target tables
    tables_result = session.sql("""
        SELECT DISTINCT table_name
        FROM target_schemas
        WHERE active = TRUE
        ORDER BY table_name
    """).collect()
    
    success_count = 0
    failure_count = 0
    results = []
    
    for table_row in tables_result:
        table_name = table_row['TABLE_NAME']
        
        try:
            # Transform one batch for this table
            result = session.call(
                'transform_bronze_to_silver',
                'RAW_DATA_TABLE',
                table_name,
                bronze_schema,
                batch_size,
                True,  # apply_rules
                True   # incremental
            )
            
            if 'completed successfully' in result or 'No new records' in result:
                success_count += 1
                results.append(f"{table_name}: SUCCESS")
            else:
                failure_count += 1
                results.append(f"{table_name}: FAILED - {result}")
                 
        except Exception as e:
            failure_count += 1
            results.append(f"{table_name}: ERROR - {str(e)}")
            
            # Log error
            try:
                session.sql(f"""
                    INSERT INTO silver_processing_log (
                        batch_id, source_table, target_table, status,
                        start_timestamp, end_timestamp, error_message
                    )
                    VALUES (
                        'ERROR_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'),
                        'RAW_DATA_TABLE',
                        '{table_name}',
                        'FAILED',
                        CURRENT_TIMESTAMP(),
                        CURRENT_TIMESTAMP(),
                        '{str(e).replace("'", "''")}'
                    )
                """).collect()
            except:
                pass
    
    # Log overall results
    try:
        import json
        session.sql(f"""
            INSERT INTO silver_processing_log (
                batch_id, source_table, target_table, status,
                start_timestamp, end_timestamp, processing_metadata
            )
            VALUES (
                'TRANSFORM_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'),
                'RAW_DATA_TABLE',
                'ALL_TARGETS',
                '{"SUCCESS" if failure_count == 0 else "PARTIAL_SUCCESS"}',
                CURRENT_TIMESTAMP(),
                CURRENT_TIMESTAMP(),
                PARSE_JSON('{json.dumps({"success_count": success_count, "failure_count": failure_count})}')
            )
        """).collect()
    except:
        pass
    
    return f"Transformed {len(tables_result)} tables. Success: {success_count}, Failed: {failure_count}"
$$;

-- ============================================
-- TASK: Silver Transformation Task
-- ============================================
-- Purpose: Transform Bronze data to Silver for all target tables
-- Schedule: After silver_discovery_task
-- Dependencies: silver_discovery_task

CREATE OR REPLACE TASK silver_transformation_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    AFTER silver_discovery_task
AS
    CALL transform_all_targets('$BRONZE_SCHEMA_NAME', 10000);

-- ============================================
-- PROCEDURE: Resume All Silver Tasks
-- ============================================
-- Purpose: Resume all Silver layer tasks in correct order

CREATE OR REPLACE PROCEDURE resume_all_silver_tasks()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Resume tasks in dependency order (leaf to root)
    ALTER TASK IF EXISTS silver_transformation_task RESUME;
    ALTER TASK IF EXISTS silver_discovery_task RESUME;
    ALTER TASK IF EXISTS bronze_completion_sensor RESUME;
    
    RETURN 'All Silver tasks resumed';
END;
$$;

-- ============================================
-- PROCEDURE: Suspend All Silver Tasks
-- ============================================
-- Purpose: Suspend all Silver layer tasks

CREATE OR REPLACE PROCEDURE suspend_all_silver_tasks()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Suspend tasks in reverse dependency order (root to leaf)
    ALTER TASK IF EXISTS bronze_completion_sensor SUSPEND;
    ALTER TASK IF EXISTS silver_discovery_task SUSPEND;
    ALTER TASK IF EXISTS silver_transformation_task SUSPEND;
    
    RETURN 'All Silver tasks suspended';
END;
$$;

-- ============================================
-- PROCEDURE: Get Task Status
-- ============================================
-- Purpose: Get status of all Silver layer tasks

CREATE OR REPLACE PROCEDURE get_silver_task_status()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    result_msg VARCHAR;
BEGIN
    SELECT LISTAGG(
        name || ': ' || state || ' (Schedule: ' || COALESCE(schedule, 'N/A') || ')',
        '\n'
    )
    INTO result_msg
    FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
    WHERE name IN ('bronze_completion_sensor', 'silver_discovery_task', 'silver_transformation_task')
    ORDER BY name;
    
    RETURN COALESCE(result_msg, 'No task information available');
END;
$$;

-- Note: Tasks are created in SUSPENDED state by default
-- Use resume_all_silver_tasks() to start them

