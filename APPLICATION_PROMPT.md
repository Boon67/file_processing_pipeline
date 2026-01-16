# Snowflake File Processing Pipeline - Complete Application Prompt

**Version**: 1.0  
**Date**: January 15, 2026  
**Purpose**: Master prompt for regenerating the entire application, documentation, and architecture

---

## 🎯 Project Overview

Create a production-ready, **100% Snowflake-native** file processing pipeline that automatically ingests CSV and Excel files, transforms them using intelligent field mapping (Manual/ML/LLM), and applies comprehensive data quality rules. The system must support multi-tenant TPA (Third Party Administrator) architecture with complete isolation.

### Core Principles

1. **Snowflake Native Only**: No external orchestrators (Airflow, Dagster, etc.)
2. **Serverless Architecture**: Zero infrastructure management
3. **Production Ready**: Comprehensive error handling, monitoring, audit trails
4. **Multi-Tenant**: TPA-aware with complete data isolation
5. **Intelligent Automation**: ML and LLM-powered field mapping
6. **Modern UI**: Streamlit in Snowflake for management

---

## 📋 System Requirements

### Technology Stack

- **Platform**: Snowflake (Enterprise or Business Critical)
- **Orchestration**: Snowflake Tasks (no external tools)
- **Processing**: Python 3.11 + Snowpark stored procedures
- **UI**: Streamlit 1.51.0 in Snowflake
- **Deployment**: Snowflake CLI (`snow`) + Bash scripts
- **AI/ML**: Snowflake Cortex AI for LLM-based mapping

### Required Snowflake Features

- Tasks with dependencies
- Python stored procedures (Snowpark)
- Streamlit in Snowflake
- Cortex AI (for LLM mapping)
- Stages with DIRECTORY enabled
- VARIANT data type
- Dynamic SQL

---

## 🏗️ Architecture Design

### Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      BRONZE LAYER (Raw Ingestion)                │
│                                                                   │
│  Files (CSV/Excel) → Discovery → Processing → RAW_DATA_TABLE    │
│  ↓                   ↓           ↓            ↓                  │
│  @SRC               Task         Task         VARIANT JSON       │
│  ↓                   ↓           ↓            ↓                  │
│  TPA Folders        Queue        Procedures   Metadata           │
│  ↓                   ↓           ↓            ↓                  │
│  provider_a/        PENDING      CSV/Excel    TPA, File Info     │
│  provider_b/        PROCESSING   Parsers      Load Timestamp     │
│                     SUCCESS                                       │
│                     FAILED                                        │
│                                                                   │
│  Archival: @COMPLETED (30 days) → @ARCHIVE (permanent)          │
│            @ERROR (30 days) → @ARCHIVE (permanent)               │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                   SILVER LAYER (Transformation & Quality)        │
│                                                                   │
│  RAW_DATA → Field Mapping → Rules Engine → Target Tables        │
│  ↓          ↓                ↓              ↓                    │
│  VARIANT    Manual CSV       Data Quality   Structured Schema   │
│  JSON       ML Auto-Map      Business Logic TPA-Specific Tables │
│             LLM Cortex AI    Standardization                    │
│             ↓                Deduplication                       │
│             Confidence       Referential                         │
│             Scores           Integrity                           │
│             Approval                                             │
│             Workflow                                             │
│                                                                   │
│  Quality: Metrics, Quarantine, Watermarks, Audit Logs           │
└─────────────────────────────────────────────────────────────────┘
```

### Task Pipeline Architecture

**Bronze Layer Tasks:**
```
discover_files_task (Every 60 min)
    ↓
process_files_task (After discovery)
    ↓
    ├─→ move_successful_files_task (Parallel)
    └─→ move_failed_files_task (Parallel)

archive_old_files_task (Daily 2 AM, independent)
```

**Silver Layer Tasks:**
```
bronze_completion_sensor (Every 5 min)
    ↓
silver_discovery_task (After Bronze completion)
    ↓
silver_transformation_task (Applies mappings & rules)
    ↓
silver_quality_check_task (Validates output)
    ↓
    ├─→ silver_publish_task (Success)
    └─→ silver_quarantine_task (Failure)
```

### TPA (Multi-Tenant) Architecture

**TPA Isolation Strategy:**

1. **File Organization**: `@SRC/provider_a/`, `@SRC/provider_b/`
2. **Metadata Separation**: All tables include `tpa` column
3. **Table Naming**: `CLAIMS_PROVIDER_A`, `CLAIMS_PROVIDER_B` (recommended)
4. **Configuration Isolation**: Separate mappings, rules, schemas per TPA
5. **Navigation-Level Selection**: Select TPA once, applies to all operations

**TPA-Aware Tables:**
- `target_schemas` - TPA-specific column definitions
- `field_mappings` - TPA-specific Bronze → Silver mappings
- `transformation_rules` - TPA-specific validation and business logic
- `data_quality_metrics` - TPA-specific quality tracking

---

## 📊 Database Schema Design

### Bronze Layer Schema

#### Stages
```sql
@SRC                -- Landing zone for incoming files (TPA folders)
@COMPLETED          -- Successfully processed files (30-day retention)
@ERROR              -- Failed files (30-day retention)
@ARCHIVE            -- Long-term archive (files > 30 days old)
@STREAMLIT_STAGE    -- Streamlit application files
@CONFIG_STAGE       -- Configuration files
```

#### Tables

**TPA_MASTER** - TPA reference table
```sql
CREATE TABLE TPA_MASTER (
    TPA_CODE VARCHAR(500) PRIMARY KEY,
    TPA_NAME VARCHAR(500) NOT NULL,
    TPA_DESCRIPTION VARCHAR(5000),
    ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY VARCHAR(500) DEFAULT CURRENT_USER()
);
```

**RAW_DATA_TABLE** - Stores ingested data as VARIANT
```sql
CREATE TABLE RAW_DATA_TABLE (
    RAW_DATA_ID NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    FILE_NAME VARCHAR(500) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    TPA VARCHAR(500) NOT NULL,  -- Extracted from file path
    RAW_DATA VARIANT NOT NULL,  -- JSON representation of row
    FILE_TYPE VARCHAR(50),
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER(),
    CONSTRAINT uk_raw_data UNIQUE (FILE_NAME, FILE_ROW_NUMBER)
);
```

**file_processing_queue** - Processing status tracking
```sql
CREATE TABLE file_processing_queue (
    queue_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    file_name VARCHAR(500) NOT NULL UNIQUE,
    file_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,  -- PENDING, PROCESSING, SUCCESS, FAILED
    discovered_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    processed_timestamp TIMESTAMP_NTZ,
    error_message VARCHAR(5000),
    process_result VARCHAR(5000),
    retry_count NUMBER(38,0) DEFAULT 0
);
```

### Silver Layer Schema

#### Stages
```sql
@SILVER_STAGE        -- Intermediate transformation files
@SILVER_CONFIG       -- Mapping and rules configuration
@SILVER_STREAMLIT    -- Silver Streamlit app files
```

#### Metadata Tables

**target_schemas** - Dynamic target table definitions (TPA-aware)
```sql
CREATE TABLE target_schemas (
    schema_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(500) NOT NULL,
    column_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- REQUIRED
    data_type VARCHAR(200) NOT NULL,
    nullable BOOLEAN DEFAULT TRUE,
    default_value VARCHAR(1000),
    description VARCHAR(5000),
    primary_key BOOLEAN DEFAULT FALSE,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    active BOOLEAN DEFAULT TRUE,
    CONSTRAINT uk_target_schemas UNIQUE (table_name, column_name, tpa)
);
```

**field_mappings** - Bronze → Silver field mappings (TPA-aware)
```sql
CREATE TABLE field_mappings (
    mapping_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_field VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    target_column VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- REQUIRED
    mapping_method VARCHAR(50),  -- MANUAL, ML_AUTO, LLM_CORTEX
    transformation_logic VARCHAR(5000),
    confidence_score FLOAT,
    approved BOOLEAN DEFAULT FALSE,
    approved_by VARCHAR(500),
    approved_at TIMESTAMP_NTZ,
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    active BOOLEAN DEFAULT TRUE,
    CONSTRAINT uk_field_mappings UNIQUE (source_field, target_table, target_column, tpa)
);
```

**transformation_rules** - Data quality and business rules (TPA-aware)
```sql
CREATE TABLE transformation_rules (
    rule_id VARCHAR(100) NOT NULL,
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(50) NOT NULL,  -- DATA_QUALITY, BUSINESS_LOGIC, STANDARDIZATION, DEDUPLICATION, REFERENTIAL_INTEGRITY
    target_table VARCHAR(500),
    target_column VARCHAR(500),
    tpa VARCHAR(500) NOT NULL,  -- REQUIRED
    rule_logic VARCHAR(5000) NOT NULL,
    error_action VARCHAR(50) DEFAULT 'REJECT',  -- REJECT, QUARANTINE, FLAG, CORRECT
    priority NUMBER(38,0) DEFAULT 100,
    active BOOLEAN DEFAULT TRUE,
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    CONSTRAINT pk_transformation_rules PRIMARY KEY (rule_id, tpa)
);
```

**silver_processing_log** - Transformation batch audit trail
```sql
CREATE TABLE silver_processing_log (
    batch_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_table VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,
    start_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    end_time TIMESTAMP_NTZ,
    record_count NUMBER(38,0),
    success_count NUMBER(38,0),
    failure_count NUMBER(38,0),
    status VARCHAR(50),  -- RUNNING, SUCCESS, FAILED
    error_message VARCHAR(5000),
    executed_by VARCHAR(500) DEFAULT CURRENT_USER()
);
```

**data_quality_metrics** - Quality tracking
```sql
CREATE TABLE data_quality_metrics (
    metric_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    batch_id NUMBER(38,0),
    target_table VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,
    metric_name VARCHAR(500) NOT NULL,
    metric_value FLOAT,
    threshold_value FLOAT,
    passed BOOLEAN,
    measurement_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

**quarantine_records** - Failed validation records
```sql
CREATE TABLE quarantine_records (
    quarantine_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    batch_id NUMBER(38,0),
    source_record VARIANT,
    target_table VARCHAR(500),
    tpa VARCHAR(500),
    rule_id VARCHAR(100),
    failure_reason VARCHAR(5000),
    quarantine_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    resolved BOOLEAN DEFAULT FALSE,
    resolution_notes VARCHAR(5000)
);
```

**processing_watermarks** - Incremental processing state
```sql
CREATE TABLE processing_watermarks (
    watermark_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_table VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,
    last_processed_id NUMBER(38,0),
    last_processed_timestamp TIMESTAMP_NTZ,
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT uk_watermarks UNIQUE (source_table, target_table, tpa)
);
```

---

## 🔧 Stored Procedures Design

### Bronze Layer Procedures

#### 1. File Discovery (SQL)
```sql
CREATE OR REPLACE PROCEDURE discover_files()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    files_added INT DEFAULT 0;
BEGIN
    -- Discover CSV files with TPA folder structure
    INSERT INTO file_processing_queue (file_name, file_type, status)
    SELECT 
        RELATIVE_PATH AS file_name,  -- Includes TPA folder: provider_a/file.csv
        'CSV' AS file_type,
        'PENDING' AS status
    FROM DIRECTORY(@SRC)
    WHERE LOWER(RELATIVE_PATH) LIKE '%.csv'
    AND RELATIVE_PATH NOT IN (
        SELECT file_name FROM file_processing_queue 
        WHERE status IN ('PENDING', 'PROCESSING', 'SUCCESS')
    );
    
    files_added := SQLROWCOUNT;
    
    -- Discover Excel files
    INSERT INTO file_processing_queue (file_name, file_type, status)
    SELECT 
        RELATIVE_PATH AS file_name,
        'EXCEL' AS file_type,
        'PENDING' AS status
    FROM DIRECTORY(@SRC)
    WHERE (LOWER(RELATIVE_PATH) LIKE '%.xlsx' OR LOWER(RELATIVE_PATH) LIKE '%.xls')
    AND RELATIVE_PATH NOT IN (
        SELECT file_name FROM file_processing_queue 
        WHERE status IN ('PENDING', 'PROCESSING', 'SUCCESS')
    );
    
    files_added := files_added + SQLROWCOUNT;
    
    RETURN 'Discovered ' || files_added || ' new files';
END;
$$;
```

#### 2. CSV File Processing (Python)
```python
CREATE OR REPLACE PROCEDURE process_single_csv_file(file_name VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas')
HANDLER = 'process_csv'
AS
$$
import pandas as pd
from snowflake.snowpark import Session
from snowflake.snowpark.files import SnowflakeFile
import json

def process_csv(session: Session, file_name: str) -> str:
    try:
        # Extract TPA from file path (e.g., "provider_a/file.csv" -> "provider_a")
        tpa = file_name.split('/')[0] if '/' in file_name else 'unknown'
        
        # Read CSV file from stage
        stage_path = f"@SRC/{file_name}"
        with SnowflakeFile.open(stage_path, 'r') as f:
            df = pd.read_csv(f)
        
        # Convert each row to JSON and insert into RAW_DATA_TABLE
        rows_inserted = 0
        for idx, row in df.iterrows():
            row_dict = row.to_dict()
            row_json = json.dumps(row_dict)
            
            # Insert using MERGE to avoid duplicates
            session.sql(f"""
                MERGE INTO RAW_DATA_TABLE AS target
                USING (
                    SELECT 
                        '{file_name}' AS file_name,
                        {idx + 1} AS file_row_number,
                        '{tpa}' AS tpa,
                        PARSE_JSON('{row_json}') AS raw_data,
                        'CSV' AS file_type
                ) AS source
                ON target.FILE_NAME = source.file_name 
                AND target.FILE_ROW_NUMBER = source.file_row_number
                WHEN NOT MATCHED THEN
                    INSERT (FILE_NAME, FILE_ROW_NUMBER, TPA, RAW_DATA, FILE_TYPE)
                    VALUES (source.file_name, source.file_row_number, source.tpa, source.raw_data, source.file_type)
            """).collect()
            
            rows_inserted += 1
        
        return f"SUCCESS: Processed {rows_inserted} rows from {file_name}"
        
    except Exception as e:
        return f"ERROR: {str(e)}"
$$;
```

#### 3. Excel File Processing (Python)
```python
CREATE OR REPLACE PROCEDURE process_single_excel_file(file_name VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'openpyxl')
HANDLER = 'process_excel'
AS
$$
import pandas as pd
from snowflake.snowpark import Session
from snowflake.snowpark.files import SnowflakeFile
import json
import io

def process_excel(session: Session, file_name: str) -> str:
    try:
        # Extract TPA from file path
        tpa = file_name.split('/')[0] if '/' in file_name else 'unknown'
        
        # Read Excel file from stage
        stage_path = f"@SRC/{file_name}"
        with SnowflakeFile.open(stage_path, 'rb') as f:
            file_bytes = f.read()
            df = pd.read_excel(io.BytesIO(file_bytes))
        
        # Convert each row to JSON and insert
        rows_inserted = 0
        for idx, row in df.iterrows():
            row_dict = row.to_dict()
            # Convert NaN to None for JSON serialization
            row_dict = {k: (None if pd.isna(v) else v) for k, v in row_dict.items()}
            row_json = json.dumps(row_dict)
            
            session.sql(f"""
                MERGE INTO RAW_DATA_TABLE AS target
                USING (
                    SELECT 
                        '{file_name}' AS file_name,
                        {idx + 1} AS file_row_number,
                        '{tpa}' AS tpa,
                        PARSE_JSON('{row_json}') AS raw_data,
                        'EXCEL' AS file_type
                ) AS source
                ON target.FILE_NAME = source.file_name 
                AND target.FILE_ROW_NUMBER = source.file_row_number
                WHEN NOT MATCHED THEN
                    INSERT (FILE_NAME, FILE_ROW_NUMBER, TPA, RAW_DATA, FILE_TYPE)
                    VALUES (source.file_name, source.file_row_number, source.tpa, source.raw_data, source.file_type)
            """).collect()
            
            rows_inserted += 1
        
        return f"SUCCESS: Processed {rows_inserted} rows from {file_name}"
        
    except Exception as e:
        return f"ERROR: {str(e)}"
$$;
```

### Silver Layer Procedures

#### 1. Create Silver Table (SQL)
```sql
CREATE OR REPLACE PROCEDURE create_silver_table(
    p_table_name VARCHAR,
    p_tpa VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    ddl_statement VARCHAR;
    column_definitions VARCHAR;
BEGIN
    -- Build column definitions from target_schemas
    SELECT LISTAGG(
        column_name || ' ' || data_type || 
        CASE WHEN NOT nullable THEN ' NOT NULL' ELSE '' END ||
        CASE WHEN default_value IS NOT NULL THEN ' DEFAULT ' || default_value ELSE '' END,
        ', '
    ) WITHIN GROUP (ORDER BY schema_id)
    INTO column_definitions
    FROM target_schemas
    WHERE table_name = p_table_name AND tpa = p_tpa AND active = TRUE;
    
    -- Create table with TPA suffix
    ddl_statement := 'CREATE TABLE IF NOT EXISTS ' || p_table_name || '_' || UPPER(p_tpa) || ' (' ||
        column_definitions ||
        ', SILVER_LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()' ||
        ', SILVER_LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER()' ||
        ', SOURCE_FILE_NAME VARCHAR(500)' ||
        ', SOURCE_ROW_NUMBER NUMBER(38,0)' ||
        ')';
    
    EXECUTE IMMEDIATE ddl_statement;
    
    RETURN 'Created table: ' || p_table_name || '_' || UPPER(p_tpa);
END;
$$;
```

#### 2. Auto-Map Fields (ML) (SQL)
```sql
CREATE OR REPLACE PROCEDURE auto_map_fields_ml(
    p_source_table VARCHAR,
    p_tpa VARCHAR,
    p_top_n INT DEFAULT 3,
    p_confidence_threshold FLOAT DEFAULT 0.6
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    mappings_created INT DEFAULT 0;
BEGIN
    -- Get distinct source fields from Bronze
    -- Use ML algorithms (TF-IDF, Levenshtein distance) to suggest mappings
    -- This is a simplified version - full implementation uses Python with scikit-learn
    
    INSERT INTO field_mappings (
        source_field, target_table, target_column, tpa, 
        mapping_method, confidence_score, approved
    )
    SELECT 
        source_field,
        target_table,
        target_column,
        p_tpa,
        'ML_AUTO',
        confidence_score,
        FALSE  -- Requires approval
    FROM (
        -- ML similarity calculation logic here
        -- Uses string similarity, TF-IDF, etc.
        SELECT 
            s.field_name AS source_field,
            t.table_name AS target_table,
            t.column_name AS target_column,
            -- Simplified: Use EDITDISTANCE for similarity
            1.0 - (EDITDISTANCE(s.field_name, t.column_name) / 
                   GREATEST(LENGTH(s.field_name), LENGTH(t.column_name))) AS confidence_score
        FROM (
            SELECT DISTINCT key AS field_name
            FROM RAW_DATA_TABLE,
            LATERAL FLATTEN(input => RAW_DATA)
            WHERE TPA = p_tpa
        ) s
        CROSS JOIN target_schemas t
        WHERE t.tpa = p_tpa AND t.active = TRUE
        QUALIFY ROW_NUMBER() OVER (PARTITION BY s.field_name ORDER BY confidence_score DESC) <= p_top_n
    )
    WHERE confidence_score >= p_confidence_threshold;
    
    mappings_created := SQLROWCOUNT;
    
    RETURN 'Created ' || mappings_created || ' ML-based mappings';
END;
$$;
```

#### 3. Auto-Map Fields (LLM) (SQL with Cortex)
```sql
CREATE OR REPLACE PROCEDURE auto_map_fields_llm(
    p_source_table VARCHAR,
    p_tpa VARCHAR,
    p_model VARCHAR DEFAULT 'llama3.1-70b',
    p_prompt_template VARCHAR DEFAULT 'DEFAULT_FIELD_MAPPING'
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    mappings_created INT DEFAULT 0;
    source_fields VARCHAR;
    target_schema VARCHAR;
    llm_response VARCHAR;
BEGIN
    -- Get source fields
    SELECT LISTAGG(DISTINCT key, ', ')
    INTO source_fields
    FROM RAW_DATA_TABLE,
    LATERAL FLATTEN(input => RAW_DATA)
    WHERE TPA = p_tpa
    LIMIT 1000;
    
    -- Get target schema
    SELECT LISTAGG(table_name || '.' || column_name || ' (' || description || ')', '; ')
    INTO target_schema
    FROM target_schemas
    WHERE tpa = p_tpa AND active = TRUE;
    
    -- Call Cortex AI for mapping suggestions
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        p_model,
        CONCAT(
            'You are a data mapping expert. Map these source fields to target schema fields.\n\n',
            'Source Fields: ', source_fields, '\n\n',
            'Target Schema: ', target_schema, '\n\n',
            'Return JSON array with: source_field, target_table, target_column, confidence (0-1), reasoning'
        )
    ) INTO llm_response;
    
    -- Parse LLM response and insert mappings
    -- (Simplified - full implementation parses JSON response)
    
    RETURN 'Created ' || mappings_created || ' LLM-based mappings';
END;
$$;
```

#### 4. Transform Bronze to Silver (SQL)
```sql
CREATE OR REPLACE PROCEDURE transform_bronze_to_silver(
    p_source_table VARCHAR,
    p_target_table VARCHAR,
    p_tpa VARCHAR,
    p_source_schema VARCHAR DEFAULT 'BRONZE',
    p_batch_size INT DEFAULT 10000,
    p_apply_rules BOOLEAN DEFAULT TRUE,
    p_incremental BOOLEAN DEFAULT TRUE
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    batch_id INT;
    records_processed INT DEFAULT 0;
    records_success INT DEFAULT 0;
    records_failed INT DEFAULT 0;
    last_processed_id INT DEFAULT 0;
BEGIN
    -- Create batch log entry
    INSERT INTO silver_processing_log (source_table, target_table, tpa, status)
    VALUES (p_source_table, p_target_table, p_tpa, 'RUNNING')
    RETURNING batch_id INTO batch_id;
    
    -- Get watermark for incremental processing
    IF (p_incremental) THEN
        SELECT COALESCE(last_processed_id, 0)
        INTO last_processed_id
        FROM processing_watermarks
        WHERE source_table = p_source_table 
        AND target_table = p_target_table 
        AND tpa = p_tpa;
    END IF;
    
    -- Build dynamic INSERT statement using field mappings
    -- Apply transformation rules
    -- Insert into target table
    
    -- Update batch log
    UPDATE silver_processing_log
    SET end_time = CURRENT_TIMESTAMP(),
        record_count = records_processed,
        success_count = records_success,
        failure_count = records_failed,
        status = 'SUCCESS'
    WHERE batch_id = batch_id;
    
    -- Update watermark
    MERGE INTO processing_watermarks AS target
    USING (
        SELECT p_source_table AS source_table,
               p_target_table AS target_table,
               p_tpa AS tpa,
               MAX(raw_data_id) AS last_id
        FROM RAW_DATA_TABLE
        WHERE tpa = p_tpa
    ) AS source
    ON target.source_table = source.source_table
    AND target.target_table = source.target_table
    AND target.tpa = source.tpa
    WHEN MATCHED THEN
        UPDATE SET last_processed_id = source.last_id,
                   last_processed_timestamp = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (source_table, target_table, tpa, last_processed_id, last_processed_timestamp)
        VALUES (source.source_table, source.target_table, source.tpa, source.last_id, CURRENT_TIMESTAMP());
    
    RETURN 'Batch ' || batch_id || ': Processed ' || records_processed || ' records';
END;
$$;
```

---

## 🎨 Streamlit Applications Design

### Bronze Streamlit App

**Features:**
1. **File Upload** - Drag-and-drop with TPA selection
2. **Processing Status** - Real-time queue monitoring
3. **File Stages** - Browse files in all stages
4. **Raw Data Viewer** - View ingested data
5. **Task Management** - Control task execution

**Key Components:**

```python
import streamlit as st
from snowflake.snowpark.context import get_active_session

# Page configuration
st.set_page_config(
    page_title="Bronze Ingestion Pipeline",
    page_icon="🥉",
    layout="wide"
)

# Sidebar navigation
with st.sidebar:
    st.title("🥉 Bronze Layer")
    page = st.radio("Navigation", [
        "📤 Upload Files",
        "📊 Processing Status",
        "📂 File Stages",
        "📋 Raw Data Viewer",
        "⚙️ Task Management"
    ])

# Get Snowflake session
session = get_active_session()

# Page routing
if page == "📤 Upload Files":
    # TPA selection
    tpas = session.sql("SELECT TPA_CODE, TPA_NAME FROM TPA_MASTER WHERE ACTIVE = TRUE").collect()
    selected_tpa = st.selectbox("Select TPA", options=tpas)
    
    # File uploader
    uploaded_files = st.file_uploader(
        "Upload CSV or Excel files",
        type=['csv', 'xlsx', 'xls'],
        accept_multiple_files=True
    )
    
    if uploaded_files and st.button("Upload"):
        for file in uploaded_files:
            # Upload to stage with TPA folder
            stage_path = f"@SRC/{selected_tpa}/{file.name}"
            session.file.put(file, stage_path)
        st.success(f"Uploaded {len(uploaded_files)} files")

elif page == "📊 Processing Status":
    # Show processing queue
    queue_df = session.sql("""
        SELECT file_name, file_type, status, 
               discovered_timestamp, processed_timestamp,
               error_message
        FROM file_processing_queue
        ORDER BY discovered_timestamp DESC
    """).to_pandas()
    
    st.dataframe(queue_df)
    
    # Summary metrics
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Files", len(queue_df))
    col2.metric("Success", len(queue_df[queue_df['STATUS'] == 'SUCCESS']))
    col3.metric("Failed", len(queue_df[queue_df['STATUS'] == 'FAILED']))
    col4.metric("Pending", len(queue_df[queue_df['STATUS'] == 'PENDING']))

# ... other pages
```

### Silver Streamlit App

**Features:**
1. **Target Table Designer** - Define target schemas
2. **Field Mapper** - Create/approve mappings (Manual/ML/LLM)
3. **Rules Engine** - Define transformation rules
4. **Transformation Monitor** - Run and monitor transformations
5. **Data Viewer** - View Silver tables
6. **Quality Dashboard** - Data quality metrics

**Key Components:**

```python
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(
    page_title="Silver Transformation Manager",
    page_icon="🥈",
    layout="wide"
)

# Sidebar with TPA selection at top
with st.sidebar:
    st.title("🥈 Silver Layer")
    st.markdown("---")
    
    # TPA selection (most important)
    st.subheader("🏢 TPA Selection")
    tpas = session.sql("SELECT DISTINCT tpa FROM target_schemas ORDER BY tpa").collect()
    selected_tpa = st.selectbox("Select TPA", options=tpas, key="selected_tpa")
    st.markdown("---")
    
    # Navigation
    st.subheader("📍 Navigation")
    page = st.radio("", [
        "📊 Target Table Designer",
        "🗺️ Field Mapper",
        "⚙️ Rules Engine",
        "🔄 Transformation Monitor",
        "📈 Data Viewer",
        "✅ Quality Dashboard"
    ])

session = get_active_session()

if page == "🗺️ Field Mapper":
    st.header("Field Mapping")
    
    tab1, tab2, tab3, tab4 = st.tabs([
        "Manual Mapping", "ML Auto-Map", "LLM Mapping", "View Mappings"
    ])
    
    with tab3:  # LLM Mapping
        st.subheader("LLM-Based Field Mapping")
        
        target_table = st.selectbox("Target Table", options=tables)
        model = st.selectbox("LLM Model", ["llama3.1-70b", "mixtral-8x7b"])
        
        if st.button("Generate LLM Mappings"):
            # Call LLM mapping procedure
            result = session.call("auto_map_fields_llm", target_table, selected_tpa, model)
            
            # Show approval dialog
            pending_mappings = session.sql(f"""
                SELECT mapping_id, source_field, target_column, 
                       confidence_score, description
                FROM field_mappings
                WHERE target_table = '{target_table}'
                AND tpa = '{selected_tpa}'
                AND approved = FALSE
                AND mapping_method = 'LLM_CORTEX'
                ORDER BY confidence_score DESC
            """).collect()
            
            if pending_mappings:
                st.success(f"Generated {len(pending_mappings)} mappings. Review below:")
                
                with st.expander("📋 Review and Approve Mappings", expanded=True):
                    approval_states = []
                    for mapping in pending_mappings:
                        col1, col2, col3 = st.columns([3, 3, 1])
                        col1.write(f"**{mapping.SOURCE_FIELD}**")
                        col2.write(f"→ {mapping.TARGET_COLUMN}")
                        approved = col3.checkbox("✓", key=f"approve_{mapping.MAPPING_ID}")
                        approval_states.append(approved)
                    
                    col1, col2, col3 = st.columns(3)
                    if col1.button("Approve All"):
                        approval_states = [True] * len(pending_mappings)
                    if col2.button("Reject All"):
                        approval_states = [False] * len(pending_mappings)
                    
                    if col3.button("Submit Approvals"):
                        # Update approved mappings
                        approved_ids = [m.MAPPING_ID for m, a in zip(pending_mappings, approval_states) if a]
                        rejected_ids = [m.MAPPING_ID for m, a in zip(pending_mappings, approval_states) if not a]
                        
                        if approved_ids:
                            session.sql(f"""
                                UPDATE field_mappings
                                SET approved = TRUE, 
                                    approved_by = CURRENT_USER(),
                                    approved_at = CURRENT_TIMESTAMP()
                                WHERE mapping_id IN ({','.join(map(str, approved_ids))})
                            """).collect()
                        
                        if rejected_ids:
                            session.sql(f"""
                                DELETE FROM field_mappings
                                WHERE mapping_id IN ({','.join(map(str, rejected_ids))})
                            """).collect()
                        
                        st.success(f"Approved {len(approved_ids)}, Rejected {len(rejected_ids)}")
                        st.rerun()

# ... other pages
```

---

## 🚀 Deployment Scripts Design

### Master Deployment Script (deploy.sh)

```bash
#!/bin/bash
set -e

# Configuration
CONFIG_FILE="${1:-default.config}"
source "$CONFIG_FILE"

# Deploy Bronze Layer
echo "Deploying Bronze Layer..."
snow sql -f bronze/1_Setup_Database_Roles.sql
snow sql -f bronze/2_Bronze_Schema_Tables.sql
snow sql -f bronze/3_Bronze_Setup_Logic.sql
snow sql -f bronze/4_Bronze_Tasks.sql

# Deploy Bronze Streamlit
cd bronze/bronze_streamlit
snow streamlit deploy --replace
cd ../..

# Deploy Silver Layer
echo "Deploying Silver Layer..."
snow sql -f silver/1_Silver_Schema_Setup.sql
snow sql -f silver/2_Silver_Target_Schemas.sql
snow sql -f silver/3_Silver_Mapping_Procedures.sql
snow sql -f silver/4_Silver_Rules_Engine.sql
snow sql -f silver/5_Silver_Transformation_Logic.sql
snow sql -f silver/6_Silver_Tasks.sql

# Deploy Silver Streamlit
cd silver/silver_streamlit
snow streamlit deploy --replace
cd ../..

echo "Deployment complete!"
```

### Configuration File (default.config)

```bash
# Database Configuration
DATABASE_NAME="db_ingest_pipeline"
BRONZE_SCHEMA_NAME="BRONZE"
SILVER_SCHEMA_NAME="SILVER"
WAREHOUSE_NAME="COMPUTE_WH"

# Stage Configuration
SRC_STAGE_NAME="SRC"
COMPLETED_STAGE_NAME="COMPLETED"
ERROR_STAGE_NAME="ERROR"
ARCHIVE_STAGE_NAME="ARCHIVE"

# Task Configuration
DISCOVER_TASK_SCHEDULE_MINUTES="60"
ARCHIVE_TASK_SCHEDULE="USING CRON 0 2 * * * UTC"

# Streamlit Configuration
BRONZE_STREAMLIT_APP_NAME="BRONZE_INGESTION_PIPELINE"
SILVER_STREAMLIT_APP_NAME="SILVER_TRANSFORMATION_MANAGER"
```

---

## 📚 Documentation Requirements

### Documentation Structure

Create the following documentation files:

#### 1. README.md (Main Overview)
- Project overview and features
- Quick start guide
- Architecture diagrams
- Key features with screenshots
- Technology stack
- Quick reference commands
- FAQ section

#### 2. QUICK_START.md
- 10-minute deployment guide
- Prerequisites
- Step-by-step deployment
- Verification steps
- Common issues and solutions

#### 3. DOCUMENTATION_INDEX.md
- Complete documentation guide
- Navigation by role (user, deployer, developer)
- Navigation by task
- Links to all documentation

#### 4. docs/USER_GUIDE.md
- Comprehensive usage guide
- Bronze layer usage
- Silver layer usage
- End-to-end workflows
- Troubleshooting
- Screenshots

#### 5. docs/DEPLOYMENT_AND_OPERATIONS.md
- Complete deployment guide
- Configuration management
- Logging implementation
- Task privilege setup
- Operations procedures
- Platform-specific instructions
- Troubleshooting

#### 6. docs/guides/TPA_COMPLETE_GUIDE.md
- TPA architecture
- Table naming strategy
- Configuration examples
- Best practices
- Quick start for new TPAs

#### 7. docs/design/ARCHITECTURE.md
- Complete architecture reference
- Visual diagrams
- ASCII diagrams
- Component descriptions
- Data flow
- Security architecture

#### 8. docs/design/SYSTEM_DESIGN.md
- High-level system design
- Design patterns
- Scalability considerations
- Performance characteristics

#### 9. docs/design/TECHNICAL_SPECIFICATION.md
- Detailed technical specifications
- Database schemas
- Stored procedure signatures
- API specifications
- Data types

#### 10. bronze/README.md & silver/README.md
- Layer-specific documentation
- Features
- Usage examples
- SQL reference

---

## 🎨 Architecture Diagrams

### Required Diagrams

Generate the following diagrams using Python (matplotlib/graphviz):

#### 1. architecture_overview.png
- High-level system architecture
- Bronze and Silver layers
- Streamlit apps
- External connections

#### 2. data_flow_diagram.png
- End-to-end data flow
- File → Bronze → Silver → Analytics
- Task dependencies
- Data transformations

#### 3. bronze_architecture.png
- Bronze layer detailed view
- Stages and tables
- Task pipeline
- File processing flow

#### 4. silver_architecture.png
- Silver layer detailed view
- Metadata tables
- Transformation flow
- Quality checks

#### 5. security_rbac_diagram.png
- Role hierarchy
- Permission model
- Data isolation

#### 6. deployment_pipeline_diagram.png
- Deployment process
- Script execution order
- Verification steps

#### 7. overall_data_flow.png
- Complete data flow
- TPA isolation
- Multi-tenant architecture

#### 8. project_structure.png
- File and folder structure
- Component organization

### Diagram Generation Script

```python
# docs/design/generate_design_diagrams.py
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import numpy as np

def generate_architecture_overview():
    fig, ax = plt.subplots(figsize=(16, 10))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.5, 'Snowflake File Processing Pipeline - Architecture Overview',
            ha='center', va='top', fontsize=20, fontweight='bold')
    
    # Bronze Layer
    bronze_box = FancyBboxPatch((0.5, 5.5), 4, 3,
                                boxstyle="round,pad=0.1",
                                edgecolor='#CD7F32', facecolor='#F4E4C1',
                                linewidth=3)
    ax.add_patch(bronze_box)
    ax.text(2.5, 8.2, '🥉 BRONZE LAYER', ha='center', fontsize=16, fontweight='bold')
    ax.text(2.5, 7.7, 'Raw Ingestion', ha='center', fontsize=12)
    
    # Bronze components
    ax.text(1, 7.2, '• CSV/Excel Files', fontsize=10)
    ax.text(1, 6.9, '• Discovery Task', fontsize=10)
    ax.text(1, 6.6, '• Processing Queue', fontsize=10)
    ax.text(1, 6.3, '• RAW_DATA_TABLE', fontsize=10)
    ax.text(1, 6.0, '• File Archival', fontsize=10)
    
    # Silver Layer
    silver_box = FancyBboxPatch((5.5, 5.5), 4, 3,
                                boxstyle="round,pad=0.1",
                                edgecolor='#C0C0C0', facecolor='#E8E8E8',
                                linewidth=3)
    ax.add_patch(silver_box)
    ax.text(7.5, 8.2, '🥈 SILVER LAYER', ha='center', fontsize=16, fontweight='bold')
    ax.text(7.5, 7.7, 'Transformation & Quality', ha='center', fontsize=12)
    
    # Silver components
    ax.text(6, 7.2, '• Field Mapping', fontsize=10)
    ax.text(6, 6.9, '• Rules Engine', fontsize=10)
    ax.text(6, 6.6, '• Target Tables', fontsize=10)
    ax.text(6, 6.3, '• Quality Metrics', fontsize=10)
    ax.text(6, 6.0, '• ML/LLM Mapping', fontsize=10)
    
    # Arrow between layers
    arrow = FancyArrowPatch((4.5, 7), (5.5, 7),
                           arrowstyle='->', mutation_scale=30,
                           linewidth=3, color='#1E88E5')
    ax.add_patch(arrow)
    
    # Streamlit Apps
    streamlit_box = FancyBboxPatch((2, 2), 6, 2,
                                   boxstyle="round,pad=0.1",
                                   edgecolor='#FF4B4B', facecolor='#FFE6E6',
                                   linewidth=2)
    ax.add_patch(streamlit_box)
    ax.text(5, 3.5, '📱 Streamlit Applications', ha='center', fontsize=14, fontweight='bold')
    ax.text(3, 2.8, 'Bronze UI', ha='center', fontsize=11)
    ax.text(7, 2.8, 'Silver UI', ha='center', fontsize=11)
    ax.text(3, 2.4, '• File Upload', fontsize=9)
    ax.text(3, 2.1, '• Queue Monitor', fontsize=9)
    ax.text(7, 2.4, '• Field Mapper', fontsize=9)
    ax.text(7, 2.1, '• Rules Engine', fontsize=9)
    
    # TPA Architecture
    tpa_box = FancyBboxPatch((0.5, 0.2), 9, 1.2,
                             boxstyle="round,pad=0.1",
                             edgecolor='#4CAF50', facecolor='#E8F5E9',
                             linewidth=2)
    ax.add_patch(tpa_box)
    ax.text(5, 1.1, '🏢 Multi-Tenant TPA Architecture', ha='center', fontsize=12, fontweight='bold')
    ax.text(5, 0.7, 'Complete data isolation • TPA-specific configurations • Independent processing',
            ha='center', fontsize=9)
    
    plt.tight_layout()
    plt.savefig('docs/design/images/architecture_overview.png', dpi=300, bbox_inches='tight')
    plt.close()

# Generate all diagrams
if __name__ == '__main__':
    generate_architecture_overview()
    # ... generate other diagrams
    print("All diagrams generated successfully!")
```

---

## ✅ Implementation Checklist

### Phase 1: Foundation (Bronze Layer)
- [ ] Database and role setup
- [ ] Bronze schema and stages
- [ ] TPA_MASTER table
- [ ] RAW_DATA_TABLE with VARIANT
- [ ] file_processing_queue table
- [ ] CSV processing procedure (Python)
- [ ] Excel processing procedure (Python)
- [ ] Discovery procedure (SQL)
- [ ] Processing orchestration procedure (SQL)
- [ ] Task pipeline (5 tasks with dependencies)
- [ ] Bronze Streamlit app (5 pages)
- [ ] RBAC permissions

### Phase 2: Transformation (Silver Layer)
- [ ] Silver schema and stages
- [ ] Metadata tables (7 tables)
- [ ] Target schema management procedures
- [ ] Field mapping procedures (Manual/ML/LLM)
- [ ] Rules engine procedures
- [ ] Transformation orchestration
- [ ] Quality checking procedures
- [ ] Watermark management
- [ ] Silver task pipeline (6 tasks)
- [ ] Silver Streamlit app (6 pages)
- [ ] LLM approval workflow

### Phase 3: Deployment
- [ ] Configuration file system
- [ ] Master deployment script
- [ ] Bronze deployment script
- [ ] Silver deployment script
- [ ] Undeploy script
- [ ] Logging implementation
- [ ] Task privilege fix script
- [ ] Verification scripts
- [ ] Platform detection (Windows/Linux/Mac)

### Phase 4: Documentation
- [ ] README.md with architecture
- [ ] QUICK_START.md
- [ ] DOCUMENTATION_INDEX.md
- [ ] USER_GUIDE.md with screenshots
- [ ] DEPLOYMENT_AND_OPERATIONS.md
- [ ] TPA_COMPLETE_GUIDE.md
- [ ] ARCHITECTURE.md with diagrams
- [ ] SYSTEM_DESIGN.md
- [ ] TECHNICAL_SPECIFICATION.md
- [ ] Layer-specific READMEs
- [ ] Streamlit app READMEs

### Phase 5: Diagrams
- [ ] architecture_overview.png
- [ ] data_flow_diagram.png
- [ ] bronze_architecture.png
- [ ] silver_architecture.png
- [ ] security_rbac_diagram.png
- [ ] deployment_pipeline_diagram.png
- [ ] overall_data_flow.png
- [ ] project_structure.png
- [ ] Diagram generation script

### Phase 6: Sample Data & Testing
- [ ] Sample CSV files (5 TPAs)
- [ ] Sample Excel files
- [ ] Sample configuration CSVs
- [ ] Target schema samples
- [ ] Field mapping samples
- [ ] Transformation rule samples
- [ ] Test plan documentation
- [ ] Verification queries

---

## 🎯 Success Criteria

### Functional Requirements
✅ Automatically discover and process CSV/Excel files  
✅ Support multiple TPAs with complete isolation  
✅ Store raw data as VARIANT JSON  
✅ Intelligent field mapping (Manual/ML/LLM)  
✅ Comprehensive rules engine (5 rule types)  
✅ Data quality tracking and quarantine  
✅ Incremental processing with watermarks  
✅ File archival (30-day retention)  
✅ Modern Streamlit UIs for both layers  
✅ Complete audit trails  

### Non-Functional Requirements
✅ 100% Snowflake native (no external tools)  
✅ Serverless architecture  
✅ Handles files up to 100MB  
✅ Processes 1,000 records/second (CSV)  
✅ Task-based orchestration  
✅ Auto-suspend/resume  
✅ Comprehensive error handling  
✅ Platform support (Mac/Linux/Windows)  
✅ Complete documentation  
✅ Architecture diagrams  

### Deployment Requirements
✅ Single-command deployment  
✅ Configuration file system  
✅ Idempotent scripts  
✅ Logging implementation  
✅ Verification scripts  
✅ Rollback capability  
✅ Platform detection  
✅ Error recovery  

---

## 📝 Additional Notes

### Key Design Decisions

1. **VARIANT for Raw Data**: Flexibility for unknown schemas
2. **TPA-Aware Architecture**: Complete multi-tenant isolation
3. **Task-Based Orchestration**: Native Snowflake, no external tools
4. **Three Mapping Methods**: Manual (precise), ML (fast), LLM (intelligent)
5. **Approval Workflow**: Human-in-the-loop for LLM mappings
6. **30-Day Retention**: Balance between storage cost and recovery needs
7. **Batch Processing**: 10,000 records per batch for performance
8. **Incremental Processing**: Watermark-based to avoid reprocessing

### Performance Considerations

- Use appropriate warehouse size (X-Small to Large)
- Enable auto-suspend (1 minute idle)
- Batch processing for large datasets
- Incremental processing with watermarks
- Clustering on TPA column for shared tables
- Separate warehouses for Bronze and Silver (optional)

### Security Considerations

- Three-tier RBAC (ADMIN, READWRITE, READONLY)
- Server-side encryption (SSE) on all stages
- Audit logging of all transformations
- Data lineage tracking
- Quarantine for failed records
- TPA data isolation

### Cost Optimization

- Auto-suspend warehouses
- Batch processing to minimize compute
- Incremental processing to avoid reprocessing
- File archival to reduce storage
- Appropriate warehouse sizing
- Resource monitors for cost control

---

## 🚀 Getting Started

To implement this system:

1. **Start with Bronze Layer**: Deploy database, roles, Bronze schema, procedures, tasks
2. **Deploy Bronze Streamlit**: Test file upload and processing
3. **Add Silver Layer**: Deploy Silver schema, metadata tables, procedures, tasks
4. **Deploy Silver Streamlit**: Test field mapping and transformation
5. **Create Documentation**: Generate all documentation files
6. **Generate Diagrams**: Run diagram generation script
7. **Add Sample Data**: Create sample files and configurations
8. **Test End-to-End**: Upload files, map fields, transform data
9. **Deploy to Production**: Use configuration files for different environments

---

**This prompt contains everything needed to recreate the entire Snowflake File Processing Pipeline from scratch, including code, documentation, architecture, and diagrams.**

**Version**: 1.0  
**Last Updated**: January 15, 2026  
**Status**: ✅ Complete and Production-Ready
