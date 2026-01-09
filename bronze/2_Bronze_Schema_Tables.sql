-- ============================================
-- BRONZE LAYER SETUP AND FILE PROCESSING LOGIC
-- ============================================
-- Purpose: Set up Bronze layer infrastructure and file ingestion procedures
-- 
-- This script creates:
--   1. Bronze schema with stages (SRC, SRC_COMPLETED, SRC_ERROR)
--   2. RAW_DATA_TABLE for storing ingested data as VARIANT
--   3. Python stored procedures for CSV and Excel file processing
--
-- Architecture:
--   - Files land in @SRC stage
--   - Stored procedures read, parse, and load data into RAW_DATA_TABLE
--   - Successfully processed files move to @SRC_COMPLETED
--   - Failed files move to @SRC_ERROR
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

-- Set environment variables
SET DATABASE_NAME = 'db_ingest_pipeline';
SET SCHEMA_NAME = 'BRONZE';
SET SRC_STAGE_NAME = 'SRC';
SET COMPLETED_STAGE_NAME = 'SRC_COMPLETED';
SET ERROR_STAGE_NAME = 'SRC_ERROR';

-- ============================================
-- DATABASE AND SCHEMA SETUP
-- ============================================

-- Use admin role for full permissions
USE ROLE db_ingest_pipeline_ADMIN;

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS IDENTIFIER($DATABASE_NAME);
USE DATABASE IDENTIFIER($DATABASE_NAME);

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($SCHEMA_NAME);
USE SCHEMA IDENTIFIER($SCHEMA_NAME);

-- ============================================
-- STAGE CREATION
-- ============================================

-- Create source stage for incoming files
-- DIRECTORY = TRUE enables DIRECTORY() function for file listing
CREATE STAGE IF NOT EXISTS IDENTIFIER($SRC_STAGE_NAME)
DIRECTORY = (ENABLE = TRUE)
ENCRYPTION = (TYPE='SNOWFLAKE_SSE');

-- Create completed stage for successfully processed files
CREATE STAGE IF NOT EXISTS IDENTIFIER($COMPLETED_STAGE_NAME)
DIRECTORY = (ENABLE = TRUE)
ENCRYPTION = (TYPE='SNOWFLAKE_SSE');

-- Create error stage for failed files
CREATE STAGE IF NOT EXISTS IDENTIFIER($ERROR_STAGE_NAME)
DIRECTORY = (ENABLE = TRUE)
ENCRYPTION = (TYPE='SNOWFLAKE_SSE');

-- Create archive stage for files older than 30 days
CREATE STAGE IF NOT EXISTS IDENTIFIER($ARCHIVE_STAGE_NAME)
DIRECTORY = (ENABLE = TRUE)
ENCRYPTION = (TYPE='SNOWFLAKE_SSE')
COMMENT = 'Archive stage for files older than 30 days from completed and error stages';

-- Create Streamlit stage for hosting Streamlit app
CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE
DIRECTORY = (ENABLE = TRUE)
ENCRYPTION = (TYPE='SNOWFLAKE_SSE')
COMMENT = 'Stage for Streamlit in Snowflake application files';

-- ============================================
-- RAW DATA TABLE
-- ============================================

-- Create raw data table with metadata
-- Stores each file row as JSON (VARIANT) with tracking metadata
CREATE OR REPLACE TABLE RAW_DATA_TABLE (
    RAW_ID NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,  -- Unique ID for each row
    RAW_DATA VARIANT,                                -- JSON data from source file
    FILE_NAME VARCHAR(500),                          -- Original filename
    FILE_ROW_NUMBER NUMBER(38,0),                    -- Row number in source file
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), -- When loaded
    STAGE_NAME VARCHAR(500),                         -- Source stage path
    FILE_SIZE NUMBER(38,0),                          -- File size in bytes
    FILE_LAST_MODIFIED TIMESTAMP_NTZ,                -- File last modified timestamp
    TPA VARCHAR(500)                                 -- File path extracted from stage
);

-- ============================================
-- FILE PROCESSING QUEUE TABLE
-- ============================================
-- Purpose: Track file processing status and provide audit trail
-- Used by: Automated task pipeline (3a. Bronze_Stored_Procedures.sql)
-- Status Values:
--   - PENDING: File discovered, awaiting processing
--   - PROCESSING: Currently being processed
--   - SUCCESS: Processing completed successfully
--   - FAILED: Processing encountered an error
-- ============================================

CREATE TABLE IF NOT EXISTS file_processing_queue (
    queue_id NUMBER AUTOINCREMENT,
    file_name VARCHAR,                          -- Filename only (no path)
    file_type VARCHAR,                          -- 'CSV' or 'EXCEL'
    status VARCHAR,                             -- PENDING, PROCESSING, SUCCESS, FAILED
    process_result VARCHAR,                     -- Result message from processing procedure
    discovered_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    processed_timestamp TIMESTAMP_NTZ,          -- When processing completed
    moved_timestamp TIMESTAMP_NTZ,              -- When file was moved to completed/error
    error_message VARCHAR,                      -- Error details if failed
    PRIMARY KEY (queue_id)
);

-- ============================================
-- REPROCESS QUEUE TABLE
-- ============================================
-- Purpose: Temporary queue for files to be reprocessed
-- Used by: reprocess_error_files_task
-- ============================================

CREATE TABLE IF NOT EXISTS reprocess_queue (
    reprocess_id NUMBER AUTOINCREMENT,
    file_name VARCHAR NOT NULL,                 -- Filename to reprocess
    status VARCHAR DEFAULT 'PENDING_REPROCESS', -- PENDING_REPROCESS, MOVED
    requested_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (reprocess_id)
);

-- ============================================
-- CSV FILE PROCESSING STORED PROCEDURE
-- ============================================
-- Purpose: Process a single CSV file from stage and load into RAW_DATA_TABLE
-- Parameters:
--   - source_stage_name: Stage name (e.g., 'SRC')
--   - file_name: Filename to process
-- Returns: SUCCESS/FAILURE message with row counts
-- ============================================

CREATE OR REPLACE PROCEDURE process_single_csv_file(
    source_stage_name VARCHAR,
    file_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'numpy')
HANDLER = 'process_csv'
AS
$$
# ============================================
# CSV Processing Logic
# ============================================
# Process Flow:
#   1. List stage files and get metadata
#   2. Read CSV file using pandas
#   3. Convert each row to JSON
#   4. Create temporary staging table
#   5. MERGE into RAW_DATA_TABLE (dedup on FILE_NAME + FILE_ROW_NUMBER)
#   6. Return success/failure message with row counts
# ============================================

import pandas as pd
from snowflake.snowpark import Session
from snowflake.snowpark.files import SnowflakeFile
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType
from snowflake.snowpark.functions import parse_json, current_timestamp, to_timestamp
import io
import json
import numpy as np
from datetime import datetime

def process_csv(session: Session, source_stage_name: str, file_name: str):
    try:
        # Use fully qualified table names to ensure correct schema
        raw_data_table = "db_ingest_pipeline.BRONZE.RAW_DATA_TABLE"
        
        stage_path = f"@{source_stage_name}"
        
        # Get file metadata from stage listing
        files_result = session.sql(f"LIST {stage_path}").collect()
        file_info = next((row for row in files_result if file_name in row['name']), None)
        
        if not file_info:
            return "FAILURE: File not found in stage"
        
        file_path = file_info['name']
        file_size = file_info['size']
        
        # Convert file timestamp to Snowflake format
        file_last_modified = None
        if file_info['last_modified']:
            try:
                dt = datetime.strptime(str(file_info['last_modified']), '%a, %d %b %Y %H:%M:%S %Z')
                file_last_modified = dt.strftime('%Y-%m-%d %H:%M:%S')
            except:
                file_last_modified = None
        
        # Build full stage file path
        if file_path.startswith(source_stage_name):
            full_stage_path = f"@{file_path}"
        else:
            full_stage_path = f"{stage_path}/{file_name}"
        
        # Read CSV file from stage
        with SnowflakeFile.open(full_stage_path, 'r', require_scoped_url=False) as f:
            file_content = f.read()
        
        # Parse CSV with pandas
        csv_df = pd.read_csv(io.StringIO(file_content))
        
        if csv_df.empty:
            return "FAILURE: File is empty"
        
        # Define Snowpark schema for staging
        schema = StructType([
            StructField("RAW_DATA", StringType()),
            StructField("FILE_NAME", StringType()),
            StructField("FILE_ROW_NUMBER", IntegerType()),
            StructField("STAGE_NAME", StringType()),
            StructField("FILE_SIZE", IntegerType()),
            StructField("FILE_LAST_MODIFIED", StringType()),
            StructField("TPA", StringType())
        ])
        
        # Convert each row to JSON and prepare for insert
        rows_to_insert = []
        
        for idx, row in csv_df.iterrows():
            row_dict = row.to_dict()
            
            # Clean numpy data types for JSON serialization
            cleaned_dict = {}
            for k, v in row_dict.items():
                if pd.isna(v):
                    cleaned_dict[k] = None
                elif isinstance(v, (np.integer, np.floating)):
                    cleaned_dict[k] = float(v) if np.isfinite(v) else None
                else:
                    cleaned_dict[k] = str(v) if v is not None else None
            
            row_json = json.dumps(cleaned_dict, ensure_ascii=False)
            
            row_data = (
                row_json,
                file_name,
                idx + 2,  # Row 2 is first data row (1 is header)
                stage_path,
                file_size,
                file_last_modified,
                file_path
            )
            rows_to_insert.append(row_data)
        
        if rows_to_insert:
            # Create Snowpark DataFrame
            df_to_insert = session.create_dataframe(rows_to_insert, schema)
            
            # Transform for final insert (parse JSON, convert timestamps)
            df_final = df_to_insert.select(
                parse_json(df_to_insert["RAW_DATA"]).alias("RAW_DATA"),
                df_to_insert["FILE_NAME"],
                df_to_insert["FILE_ROW_NUMBER"],
                current_timestamp().alias("LOAD_TIMESTAMP"),
                df_to_insert["STAGE_NAME"],
                df_to_insert["FILE_SIZE"],
                to_timestamp(df_to_insert["FILE_LAST_MODIFIED"], "YYYY-MM-DD HH24:MI:SS").alias("FILE_LAST_MODIFIED"),
                df_to_insert["TPA"]
            )
            
            # Create temporary staging table
            temp_table_name = f"TEMP_INSERT_{file_name.replace('.', '_').replace('-', '_').upper()}"
            df_final.write.mode("overwrite").save_as_table(temp_table_name)
            
            # Get counts before merge
            before_count = session.sql(f"SELECT COUNT(*) as cnt FROM {raw_data_table}").collect()[0]['CNT']
            
            # MERGE to deduplicate based on FILE_NAME + FILE_ROW_NUMBER
            merge_sql = f"""
            MERGE INTO {raw_data_table} AS target
            USING {temp_table_name} AS source
            ON target.FILE_NAME = source.FILE_NAME 
               AND target.FILE_ROW_NUMBER = source.FILE_ROW_NUMBER
            WHEN NOT MATCHED THEN
                INSERT (
                    RAW_DATA, FILE_NAME, FILE_ROW_NUMBER, 
                    LOAD_TIMESTAMP, STAGE_NAME, FILE_SIZE, FILE_LAST_MODIFIED, TPA
                )
                VALUES (
                    source.RAW_DATA, source.FILE_NAME, source.FILE_ROW_NUMBER, 
                    source.LOAD_TIMESTAMP, source.STAGE_NAME, source.FILE_SIZE, source.FILE_LAST_MODIFIED, source.TPA
                )
            """
            
            session.sql(merge_sql).collect()
            
            # Get counts after merge
            after_count = session.sql(f"SELECT COUNT(*) as cnt FROM {raw_data_table}").collect()[0]['CNT']
            
            count_result = session.sql(f"SELECT COUNT(*) as cnt FROM {temp_table_name}").collect()
            temp_count = count_result[0]['CNT']
            
            # Clean up temporary table
            session.sql(f"DROP TABLE {temp_table_name}").collect()
            
            rows_inserted = after_count - before_count
            rows_skipped = temp_count - rows_inserted
            
            return f"SUCCESS: Processed {temp_count} rows, Inserted {rows_inserted}, Skipped {rows_skipped}"
        
        return "FAILURE: No data to insert"
    
    except Exception as e:
        return f"FAILURE: {str(e)}"
$$;

-- ============================================
-- EXCEL FILE PROCESSING STORED PROCEDURE
-- ============================================
-- Purpose: Process a single Excel file from stage and load into RAW_DATA_TABLE
-- Parameters:
--   - source_stage_name: Stage name (e.g., 'SRC')
--   - file_name: Filename to process
-- Returns: SUCCESS/FAILURE message with row counts
-- Features:
--   - Reads first sheet only using openpyxl engine
--   - Converts each row to JSON (VARIANT)
--   - Deduplicates based on FILE_NAME + FILE_ROW_NUMBER
--   - Captures file metadata (size, last modified)
-- ============================================

CREATE OR REPLACE PROCEDURE process_single_excel_file(
    source_stage_name VARCHAR,
    file_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'openpyxl', 'pandas', 'numpy')
HANDLER = 'process_excel'
AS
$$
# ============================================
# Excel Processing Logic
# ============================================
# Process Flow:
#   1. List stage files and get metadata
#   2. Read Excel file (first sheet only) using openpyxl
#   3. Convert each row to JSON
#   4. Create temporary staging table
#   5. MERGE into RAW_DATA_TABLE (dedup on FILE_NAME + FILE_ROW_NUMBER)
#   6. Return success/failure message with row counts
# ============================================

import pandas as pd
import openpyxl
from snowflake.snowpark import Session
from snowflake.snowpark.files import SnowflakeFile
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType, VariantType, TimestampType
from snowflake.snowpark.functions import parse_json, lit, current_timestamp, to_timestamp
import io
import json
import numpy as np
from datetime import datetime

def process_excel(session: Session, source_stage_name: str, file_name: str):
    try:
        # Use fully qualified table names to ensure correct schema
        raw_data_table = "db_ingest_pipeline.BRONZE.RAW_DATA_TABLE"
        
        stage_path = f"@{source_stage_name}"
        
        # Get file metadata from stage listing
        files_result = session.sql(f"LIST {stage_path}").collect()
        file_info = next((row for row in files_result if file_name in row['name']), None)
        
        if not file_info:
            return "FAILURE: File not found in stage"
        
        file_path = file_info['name']
        file_size = file_info['size']
        
        # Convert file timestamp to Snowflake format
        file_last_modified = None
        if file_info['last_modified']:
            try:
                dt = datetime.strptime(str(file_info['last_modified']), '%a, %d %b %Y %H:%M:%S %Z')
                file_last_modified = dt.strftime('%Y-%m-%d %H:%M:%S')
            except:
                file_last_modified = None
        
        # Build full stage file path
        if file_path.startswith(source_stage_name):
            full_stage_path = f"@{file_path}"
        else:
            full_stage_path = f"{stage_path}/{file_name}"
        
        # Read Excel file from stage (binary mode for Excel)
        with SnowflakeFile.open(full_stage_path, 'rb', require_scoped_url=False) as f:
            file_content = f.read()
        
        # Parse Excel with pandas (first sheet only)
        excel_df = pd.read_excel(io.BytesIO(file_content), sheet_name=0, engine='openpyxl')
        
        if excel_df.empty:
            return "FAILURE: File is empty"
        
        # Define Snowpark schema for staging
        schema = StructType([
            StructField("RAW_DATA", StringType()),
            StructField("FILE_NAME", StringType()),
            StructField("FILE_ROW_NUMBER", IntegerType()),
            StructField("STAGE_NAME", StringType()),
            StructField("FILE_SIZE", IntegerType()),
            StructField("FILE_LAST_MODIFIED", StringType()),
            StructField("TPA", StringType())
        ])
        
        # Convert each row to JSON and prepare for insert
        rows_to_insert = []
        
        for idx, row in excel_df.iterrows():
            row_dict = row.to_dict()
            
            # Clean numpy data types for JSON serialization
            cleaned_dict = {}
            for k, v in row_dict.items():
                if pd.isna(v):
                    cleaned_dict[k] = None
                elif isinstance(v, (np.integer, np.floating)):
                    cleaned_dict[k] = float(v) if np.isfinite(v) else None
                else:
                    cleaned_dict[k] = str(v) if v is not None else None
            
            row_json = json.dumps(cleaned_dict, ensure_ascii=False)
            
            row_data = (
                row_json,
                file_name,
                idx + 2,  # Row 2 is first data row (1 is header)
                stage_path,
                file_size,
                file_last_modified,
                file_path
            )
            rows_to_insert.append(row_data)
        
        if rows_to_insert:
            # Create Snowpark DataFrame
            df_to_insert = session.create_dataframe(rows_to_insert, schema)
            
            # Transform for final insert (parse JSON, convert timestamps)
            df_final = df_to_insert.select(
                parse_json(df_to_insert["RAW_DATA"]).alias("RAW_DATA"),
                df_to_insert["FILE_NAME"],
                df_to_insert["FILE_ROW_NUMBER"],
                current_timestamp().alias("LOAD_TIMESTAMP"),
                df_to_insert["STAGE_NAME"],
                df_to_insert["FILE_SIZE"],
                to_timestamp(df_to_insert["FILE_LAST_MODIFIED"], "YYYY-MM-DD HH24:MI:SS").alias("FILE_LAST_MODIFIED"),
                df_to_insert["TPA"]
            )
            
            # Create temporary staging table
            temp_table_name = f"TEMP_INSERT_{file_name.replace('.', '_').replace('-', '_').upper()}"
            df_final.write.mode("overwrite").save_as_table(temp_table_name)
            
            # Get counts before merge
            before_count = session.sql(f"SELECT COUNT(*) as cnt FROM {raw_data_table}").collect()[0]['CNT']
            
            # MERGE to deduplicate based on FILE_NAME + FILE_ROW_NUMBER
            merge_sql = f"""
            MERGE INTO {raw_data_table} AS target
            USING {temp_table_name} AS source
            ON target.FILE_NAME = source.FILE_NAME 
               AND target.FILE_ROW_NUMBER = source.FILE_ROW_NUMBER
            WHEN NOT MATCHED THEN
                INSERT (
                    RAW_DATA, FILE_NAME, FILE_ROW_NUMBER, 
                    LOAD_TIMESTAMP, STAGE_NAME, FILE_SIZE, FILE_LAST_MODIFIED, TPA
                )
                VALUES (
                    source.RAW_DATA, source.FILE_NAME, source.FILE_ROW_NUMBER, 
                    source.LOAD_TIMESTAMP, source.STAGE_NAME, source.FILE_SIZE, source.FILE_LAST_MODIFIED, source.TPA
                )
            """
            
            session.sql(merge_sql).collect()
            
            # Get counts after merge
            after_count = session.sql(f"SELECT COUNT(*) as cnt FROM {raw_data_table}").collect()[0]['CNT']
            
            count_result = session.sql(f"SELECT COUNT(*) as cnt FROM {temp_table_name}").collect()
            temp_count = count_result[0]['CNT']
            
            # Clean up temporary table
            session.sql(f"DROP TABLE {temp_table_name}").collect()
            
            rows_inserted = after_count - before_count
            rows_skipped = temp_count - rows_inserted
            
            return f"SUCCESS: Processed {temp_count} rows, Inserted {rows_inserted}, Skipped {rows_skipped}"
        
        return "FAILURE: No data to insert"
    
    except Exception as e:
        return f"FAILURE: {str(e)}"
$$;

-- ============================================
-- GRANT PERMISSIONS TO ROLES
-- ============================================
-- Purpose: Grant appropriate permissions on BRONZE schema objects
-- to READWRITE and READONLY roles

-- Build role names from database name
SET role_admin = (SELECT $DATABASE_NAME || '_ADMIN');
SET role_readwrite = (SELECT $DATABASE_NAME || '_READWRITE');
SET role_readonly = (SELECT $DATABASE_NAME || '_READONLY');

-- Grant schema usage to all roles
GRANT USAGE ON SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);
GRANT USAGE ON SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT ALL PRIVILEGES ON SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);

-- ============================================
-- READONLY ROLE GRANTS
-- ============================================

-- SELECT on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- SELECT on all future tables
GRANT SELECT ON FUTURE TABLES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- READ on all existing stages
GRANT READ ON ALL STAGES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- READ on all future stages
GRANT READ ON FUTURE STAGES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- USAGE on all existing procedures
GRANT USAGE ON ALL PROCEDURES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- USAGE on all future procedures
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- MONITOR on all existing tasks
GRANT MONITOR ON ALL TASKS IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- MONITOR on all future tasks
GRANT MONITOR ON FUTURE TASKS IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- ============================================
-- READWRITE ROLE GRANTS
-- ============================================

-- DML on all existing tables
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- DML on all future tables
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- READ and WRITE on all existing stages
GRANT READ, WRITE ON ALL STAGES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- READ and WRITE on all future stages
GRANT READ, WRITE ON FUTURE STAGES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- CREATE privileges on schema
GRANT CREATE TABLE ON SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE VIEW ON SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE STAGE ON SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE PROCEDURE ON SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE FUNCTION ON SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- OPERATE on all existing tasks
GRANT OPERATE ON ALL TASKS IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- OPERATE on all future tasks
GRANT OPERATE ON FUTURE TASKS IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- ============================================
-- ADMIN ROLE GRANTS
-- ============================================

-- ALL PRIVILEGES on all existing objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL STAGES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL TASKS IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);

-- ALL PRIVILEGES on all future objects
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE STAGES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE PROCEDURES IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE FUNCTIONS IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE TASKS IN SCHEMA IDENTIFIER($SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
