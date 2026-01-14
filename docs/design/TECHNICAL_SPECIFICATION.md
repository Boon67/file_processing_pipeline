# Technical Specification

## Snowflake File Processing Pipeline

**Version:** 1.0  
**Date:** January 2026  
**Status:** Production Ready

---

## Table of Contents

1. [Technical Overview](#technical-overview)
2. [Database Schema](#database-schema)
3. [Stored Procedures](#stored-procedures)
4. [Task Definitions](#task-definitions)
5. [Data Types & Structures](#data-types--structures)
6. [API Specifications](#api-specifications)
7. [Configuration Reference](#configuration-reference)
8. [Error Handling](#error-handling)
9. [Performance Specifications](#performance-specifications)

---

## Technical Overview

### Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Database | Snowflake | Current | Data storage and processing |
| Language | SQL | ANSI SQL | DDL, DML operations |
| Procedures | Python | 3.11 | Complex business logic |
| Procedures | SQL | Snowflake SQL | Simple transformations |
| UI | Streamlit | 1.x | Web interfaces |
| Deployment | Bash | 4.0+ | Automation scripts |
| CLI | Snowflake CLI | Latest | Deployment tool |

### System Requirements

**Snowflake Account**:
- Edition: Standard or higher
- Cloud: AWS, Azure, or GCP
- Region: Any

**Required Roles**:
- SYSADMIN: Database and object creation
- SECURITYADMIN: Role management

**Required Privileges**:
- CREATE DATABASE
- CREATE ROLE
- CREATE WAREHOUSE (or access to existing)
- CREATE STREAMLIT

---

## Database Schema

### Bronze Layer Schema

#### Tables

**1. RAW_DATA_TABLE**

```sql
CREATE TABLE RAW_DATA_TABLE (
    file_name VARCHAR(500) NOT NULL,
    row_number INTEGER NOT NULL,
    record_data VARIANT NOT NULL,
    file_format VARCHAR(50),
    load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    batch_id VARCHAR(100),
    PRIMARY KEY (file_name, row_number)
);
```

**Purpose**: Store raw file data in semi-structured format

**Columns**:
- `file_name`: Source file identifier
- `row_number`: Row position in source file
- `record_data`: JSON-like VARIANT containing all fields
- `file_format`: CSV or EXCEL
- `load_timestamp`: When record was loaded
- `batch_id`: Processing batch identifier

**Indexes**: Primary key on (file_name, row_number)

**2. FILE_PROCESSING_QUEUE**

```sql
CREATE TABLE FILE_PROCESSING_QUEUE (
    file_name VARCHAR(500) PRIMARY KEY,
    file_size INTEGER,
    file_format VARCHAR(50),
    discovered_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    processing_started_timestamp TIMESTAMP_NTZ,
    processing_completed_timestamp TIMESTAMP_NTZ,
    status VARCHAR(50) DEFAULT 'PENDING',
    error_message VARCHAR(5000),
    current_stage VARCHAR(100) DEFAULT '@SRC',
    row_count INTEGER,
    retry_count INTEGER DEFAULT 0,
    last_modified_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

**Purpose**: Track file processing lifecycle

**Status Values**:
- PENDING: Discovered, awaiting processing
- PROCESSING: Currently being processed
- SUCCESS: Successfully processed
- FAILED: Processing failed
- ARCHIVED: Moved to long-term storage

#### Stages

```sql
-- Source files
CREATE STAGE SRC
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE='SNOWFLAKE_SSE');

-- Successfully processed files
CREATE STAGE COMPLETED
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE='SNOWFLAKE_SSE');

-- Failed files
CREATE STAGE ERROR
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE='SNOWFLAKE_SSE');

-- Long-term archive
CREATE STAGE ARCHIVE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE='SNOWFLAKE_SSE');

-- Streamlit application
CREATE STAGE STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE='SNOWFLAKE_SSE');

-- Configuration files
CREATE STAGE CONFIG_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE='SNOWFLAKE_SSE');
```

### Silver Layer Schema

#### Metadata Tables

**1. target_schemas**

```sql
CREATE TABLE target_schemas (
    table_name VARCHAR(500) NOT NULL,
    column_name VARCHAR(500) NOT NULL,
    data_type VARCHAR(200) NOT NULL,
    nullable BOOLEAN DEFAULT TRUE,
    default_value VARCHAR(1000),
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    active BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (table_name, column_name)
);
```

**Purpose**: Define target table schemas

**2. field_mappings**

```sql
CREATE TABLE field_mappings (
    mapping_id VARCHAR(100) PRIMARY KEY DEFAULT UUID_STRING(),
    source_field VARCHAR(500) NOT NULL,
    source_table VARCHAR(500) DEFAULT 'RAW_DATA_TABLE',
    target_table VARCHAR(500) NOT NULL,
    target_column VARCHAR(500) NOT NULL,
    mapping_method VARCHAR(50) NOT NULL,
    confidence_score FLOAT,
    transformation_logic VARCHAR(5000),
    description VARCHAR(5000),
    approved BOOLEAN DEFAULT FALSE,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(100),
    UNIQUE (source_field, source_table, target_table, target_column)
);
```

**Purpose**: Map source fields to target columns

**Mapping Methods**:
- MANUAL: User-defined
- ML_EXACT: Exact string match
- ML_FUZZY: Fuzzy string matching
- ML_TFIDF: TF-IDF similarity
- LLM_CORTEX: AI-powered semantic mapping

**3. transformation_rules**

```sql
CREATE TABLE transformation_rules (
    rule_id VARCHAR(50) PRIMARY KEY,
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    target_table VARCHAR(500),
    target_column VARCHAR(500),
    rule_logic VARCHAR(5000) NOT NULL,
    rule_parameters VARIANT,
    priority INTEGER DEFAULT 100,
    error_action VARCHAR(50) DEFAULT 'LOG',
    description VARCHAR(5000),
    active BOOLEAN DEFAULT TRUE,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

**Purpose**: Define transformation and validation rules

**Rule Types**:
- NOT_NULL: Field must have value
- FORMAT: Regex pattern validation
- RANGE: Numeric bounds
- REFERENTIAL: Foreign key check
- CALCULATION: Derived field
- LOOKUP: Reference data join
- CONDITIONAL: If-then logic
- DATE_NORMALIZE: Date standardization
- NAME_CASE: Text formatting
- CODE_MAPPING: Value translation

**4. data_quality_metrics**

```sql
CREATE TABLE data_quality_metrics (
    metric_id VARCHAR(100) PRIMARY KEY DEFAULT UUID_STRING(),
    batch_id VARCHAR(100) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    metric_name VARCHAR(200) NOT NULL,
    metric_value FLOAT NOT NULL,
    threshold_value FLOAT,
    passed BOOLEAN,
    measured_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

**Purpose**: Track data quality over time

**5. processing_watermarks**

```sql
CREATE TABLE processing_watermarks (
    watermark_id VARCHAR(100) PRIMARY KEY,
    source_table VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    last_processed_timestamp TIMESTAMP_NTZ,
    last_processed_id VARCHAR(100),
    records_processed INTEGER DEFAULT 0,
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

**Purpose**: Track incremental processing progress

**6. quarantine_records**

```sql
CREATE TABLE quarantine_records (
    quarantine_id VARCHAR(100) PRIMARY KEY DEFAULT UUID_STRING(),
    batch_id VARCHAR(100) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    source_record VARIANT NOT NULL,
    failed_rules VARIANT,
    error_message VARCHAR(5000),
    quarantine_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    resolved BOOLEAN DEFAULT FALSE,
    resolution_notes VARCHAR(5000)
);
```

**Purpose**: Store records that failed validation

**7. silver_processing_log**

```sql
CREATE TABLE silver_processing_log (
    log_id VARCHAR(100) PRIMARY KEY DEFAULT UUID_STRING(),
    batch_id VARCHAR(100) NOT NULL,
    target_table VARCHAR(500),
    operation VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    records_processed INTEGER,
    records_failed INTEGER,
    processing_time_seconds FLOAT,
    error_message VARCHAR(5000),
    log_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

**Purpose**: Detailed processing audit trail

**8. llm_mapping_cache**

```sql
CREATE TABLE llm_mapping_cache (
    cache_key VARCHAR(500) PRIMARY KEY,
    source_field VARCHAR(500) NOT NULL,
    target_schema VARIANT NOT NULL,
    suggested_mapping VARIANT NOT NULL,
    confidence_score FLOAT,
    llm_model VARCHAR(100),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

**Purpose**: Cache LLM mapping results for performance

---

## Stored Procedures

### Bronze Layer Procedures

#### 1. discover_files()

**Signature**:
```sql
CREATE OR REPLACE PROCEDURE discover_files()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
```

**Purpose**: Discover new files in source stage

**Returns**: Message with count of discovered files

**Logic**:
1. List files in @SRC stage using `SnowflakeFile.list_directory()`
2. Query existing files in FILE_PROCESSING_QUEUE
3. Identify new files (not in queue)
4. Extract metadata (size, format from extension)
5. Insert new files with PENDING status
6. Return success message with count

**Error Handling**: Catches all exceptions, returns error message

#### 2. process_queued_files()

**Signature**:
```sql
CREATE OR REPLACE PROCEDURE process_queued_files(batch_size INTEGER DEFAULT 10)
RETURNS VARCHAR
LANGUAGE PYTHON
```

**Purpose**: Process pending files from queue

**Parameters**:
- `batch_size`: Max files to process (default: 10)

**Returns**: Processing summary message

**Logic**:
1. Select PENDING files (LIMIT batch_size)
2. For each file:
   a. Update status to PROCESSING
   b. Detect format (CSV/EXCEL from extension)
   c. Load file into temp table
   d. Transform to VARIANT format
   e. MERGE into RAW_DATA_TABLE (prevents duplicates)
   f. Update queue: status=SUCCESS, row_count, timestamps
   g. On error: status=FAILED, error_message, retry_count++
3. Return summary: processed, succeeded, failed

**Error Handling**: Individual file errors don't stop batch

#### 3. move_files_to_stage()

**Signature**:
```sql
CREATE OR REPLACE PROCEDURE move_files_to_stage(
    source_stage VARCHAR,
    target_stage VARCHAR,
    status_filter VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
```

**Purpose**: Move files between stages

**Parameters**:
- `source_stage`: Source stage name (e.g., '@SRC')
- `target_stage`: Target stage name (e.g., '@COMPLETED')
- `status_filter`: File status to move (e.g., 'SUCCESS')

**Returns**: Count of files moved

**Logic**:
1. Query files with matching status
2. For each file:
   a. COPY FILES from source to target
   b. REMOVE from source
   c. Update queue: current_stage = target
3. Return count moved

#### 4. archive_old_files()

**Signature**:
```sql
CREATE OR REPLACE PROCEDURE archive_old_files(days_threshold INTEGER DEFAULT 30)
RETURNS VARCHAR
LANGUAGE SQL
```

**Purpose**: Archive old completed files

**Parameters**:
- `days_threshold`: Age in days (default: 30)

**Returns**: Count of files archived

**Logic**:
1. Query files in @COMPLETED older than threshold
2. COPY FILES to @ARCHIVE with compression
3. REMOVE from @COMPLETED
4. Update queue: current_stage = '@ARCHIVE'
5. Return count archived

### Silver Layer Procedures

#### 1. suggest_field_mappings_manual()

**Signature**:
```sql
CREATE OR REPLACE PROCEDURE suggest_field_mappings_manual(
    source_table VARCHAR,
    target_table VARCHAR
)
RETURNS TABLE(...)
LANGUAGE SQL
```

**Purpose**: Load manual field mappings from CSV

**Parameters**:
- `source_table`: Source table name
- `target_table`: Target table name

**Returns**: Table of suggested mappings

**Logic**:
1. Query field_mappings table
2. Filter by source/target tables
3. Filter by mapping_method = 'MANUAL'
4. Return with confidence_score = 1.0

#### 2. suggest_field_mappings_ml()

**Signature**:
```sql
CREATE OR REPLACE PROCEDURE suggest_field_mappings_ml(
    source_fields ARRAY,
    target_schema OBJECT,
    method VARCHAR DEFAULT 'FUZZY'
)
RETURNS TABLE(...)
LANGUAGE PYTHON
```

**Purpose**: ML-based field mapping suggestions

**Parameters**:
- `source_fields`: Array of source field names
- `target_schema`: Object with target columns
- `method`: EXACT, FUZZY, or TFIDF

**Returns**: Table of mappings with confidence scores

**Logic**:
1. For each source field:
   a. Compare with each target column
   b. Calculate similarity score based on method
   c. If score > threshold, add to suggestions
2. Sort by confidence score DESC
3. Return top matches

**Algorithms**:
- EXACT: Exact string match (case-insensitive)
- FUZZY: Levenshtein distance
- TFIDF: Term frequency-inverse document frequency

#### 3. suggest_field_mappings_llm()

**Signature**:
```sql
CREATE OR REPLACE PROCEDURE suggest_field_mappings_llm(
    source_fields ARRAY,
    target_schema OBJECT,
    model VARCHAR DEFAULT 'snowflake-arctic'
)
RETURNS TABLE(...)
LANGUAGE PYTHON
```

**Purpose**: LLM-powered semantic field mapping

**Parameters**:
- `source_fields`: Array of source field names
- `target_schema`: Object with target columns and descriptions
- `model`: Snowflake Cortex model name

**Returns**: Table of mappings with confidence scores

**Logic**:
1. Check llm_mapping_cache for existing results
2. If not cached:
   a. Build prompt with source fields and target schema
   b. Call Snowflake Cortex Complete() function
   c. Parse JSON response
   d. Cache results
3. Return mappings with confidence scores

**Models Supported**:
- snowflake-arctic
- llama3.1-70b
- mistral-large

#### 4. transform_bronze_to_silver()

**Signature**:
```sql
CREATE OR REPLACE PROCEDURE transform_bronze_to_silver(
    target_table VARCHAR,
    batch_size INTEGER DEFAULT 10000
)
RETURNS VARCHAR
LANGUAGE PYTHON
```

**Purpose**: Transform Bronze data to Silver table

**Parameters**:
- `target_table`: Silver table name
- `batch_size`: Records per batch (default: 10000)

**Returns**: Processing summary

**Logic**:
1. Get watermark for incremental processing
2. Load approved field mappings for target table
3. Query new Bronze records (after watermark)
4. For each record:
   a. Apply field mappings
   b. Apply transformation rules
   c. Validate data quality
   d. If pass: INSERT into Silver table
   e. If fail: INSERT into quarantine_records
5. Update watermark
6. Log processing metrics
7. Return summary

#### 5. apply_quality_rules()

**Signature**:
```sql
CREATE OR REPLACE PROCEDURE apply_quality_rules(
    batch_id VARCHAR,
    target_table VARCHAR,
    temp_table_name VARCHAR
)
RETURNS TABLE(...)
LANGUAGE PYTHON
```

**Purpose**: Apply data quality validation rules

**Parameters**:
- `batch_id`: Batch identifier
- `target_table`: Target table name
- `temp_table_name`: Temp table with data to validate

**Returns**: Table of validation results

**Logic**:
1. Load active rules for target table
2. For each rule:
   a. Execute validation query
   b. Count pass/fail
   c. Calculate quality score
   d. Log to data_quality_metrics
3. Return summary with pass/fail counts

---

## Task Definitions

### Bronze Layer Tasks

#### Task Dependency Graph

```
discover_files_task (ROOT, Every 60 min)
    ↓
process_files_task (AFTER discover_files_task)
    ↓
    ├─→ move_successful_files_task (AFTER process_files_task)
    └─→ move_failed_files_task (AFTER process_files_task)

archive_old_files_task (INDEPENDENT, Daily)
```

#### Task Specifications

**1. discover_files_task**

```sql
CREATE TASK discover_files_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '60 MINUTE'
AS
    CALL discover_files();
```

- **Type**: ROOT task (no dependencies)
- **Schedule**: Every 60 minutes
- **Warehouse**: COMPUTE_WH
- **Action**: Call discover_files()

**2. process_files_task**

```sql
CREATE TASK process_files_task
    WAREHOUSE = COMPUTE_WH
    AFTER discover_files_task
AS
    CALL process_queued_files(10);
```

- **Type**: CHILD task
- **Dependency**: AFTER discover_files_task
- **Warehouse**: COMPUTE_WH
- **Action**: Process up to 10 files

**3. move_successful_files_task**

```sql
CREATE TASK move_successful_files_task
    WAREHOUSE = COMPUTE_WH
    AFTER process_files_task
AS
    CALL move_files_to_stage('@SRC', '@COMPLETED', 'SUCCESS');
```

- **Type**: CHILD task
- **Dependency**: AFTER process_files_task
- **Action**: Move SUCCESS files to COMPLETED

**4. move_failed_files_task**

```sql
CREATE TASK move_failed_files_task
    WAREHOUSE = COMPUTE_WH
    AFTER process_files_task
AS
    CALL move_files_to_stage('@SRC', '@ERROR', 'FAILED');
```

- **Type**: CHILD task
- **Dependency**: AFTER process_files_task
- **Action**: Move FAILED files to ERROR

**5. archive_old_files_task**

```sql
CREATE TASK archive_old_files_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 2 * * * UTC'
AS
    CALL archive_old_files(30);
```

- **Type**: ROOT task (independent)
- **Schedule**: Daily at 2 AM UTC
- **Action**: Archive files older than 30 days

### Silver Layer Tasks

#### Task Dependency Graph

```
bronze_completion_sensor (ROOT, Every 5 min)
    ↓
silver_discovery_task (AFTER bronze_completion_sensor)
    ↓
silver_transformation_task (AFTER silver_discovery_task)
    ↓
silver_quality_check_task (AFTER silver_transformation_task)
    ↓
    ├─→ silver_publish_task (AFTER silver_quality_check_task)
    └─→ silver_quarantine_task (AFTER silver_quality_check_task)
```

---

## Data Types & Structures

### VARIANT Structure Examples

**Bronze RAW_DATA_TABLE.record_data**:

```json
{
  "claim_id": "CLM-2024-001",
  "patient_name": "John Doe",
  "claim_date": "2024-01-15",
  "claim_amount": 1500.00,
  "provider_id": "PRV-123",
  "diagnosis_code": "A01.1",
  "status": "PENDING"
}
```

**Silver field_mappings.transformation_logic**:

```sql
-- Simple field extraction
record_data:claim_id::VARCHAR

-- Type conversion
record_data:claim_amount::NUMBER(10,2)

-- Date parsing
TO_DATE(record_data:claim_date::VARCHAR, 'YYYY-MM-DD')

-- Conditional logic
CASE 
    WHEN record_data:status::VARCHAR = 'PENDING' THEN 'P'
    WHEN record_data:status::VARCHAR = 'APPROVED' THEN 'A'
    ELSE 'U'
END
```

**Silver transformation_rules.rule_parameters**:

```json
{
  "pattern": "^[A-Z]{3}-\\d{4}-\\d{3}$",
  "min_value": 0,
  "max_value": 999999.99,
  "reference_table": "providers",
  "reference_column": "provider_id",
  "date_format": "YYYY-MM-DD",
  "calculation": "field1 * field2 / 100"
}
```

---

## Configuration Reference

### default.config

```bash
# Database Configuration
DATABASE_NAME="db_ingest_pipeline"
SCHEMA_NAME="BRONZE"
WAREHOUSE_NAME="COMPUTE_WH"

# Bronze Stage Configuration
SRC_STAGE_NAME="SRC"
COMPLETED_STAGE_NAME="COMPLETED"
ERROR_STAGE_NAME="ERROR"
ARCHIVE_STAGE_NAME="ARCHIVE"

# Bronze Task Configuration
DISCOVER_TASK_SCHEDULE_MINUTES="60"

# Silver Configuration
SILVER_SCHEMA_NAME="SILVER"
SILVER_TRANSFORM_SCHEDULE_MINUTES="15"
DEFAULT_LLM_MODEL="snowflake-arctic"
DEFAULT_BATCH_SIZE="10000"
```

### Environment Variables

```bash
# Snowflake CLI
SNOWFLAKE_ACCOUNT="myaccount"
SNOWFLAKE_USER="myuser"
SNOWFLAKE_ROLE="SYSADMIN"
SNOWFLAKE_WAREHOUSE="COMPUTE_WH"

# Python
PYTHONIOENCODING="utf-8"  # Windows encoding
```

---

## Error Handling

### Error Categories

**1. System Errors**:
- Snowflake connection failures
- Warehouse suspension
- Resource limits exceeded

**2. Data Errors**:
- Invalid file format
- Schema mismatch
- Data type conversion failures

**3. Business Logic Errors**:
- Validation rule failures
- Referential integrity violations
- Calculation errors

### Error Response Codes

| Code | Category | Description | Action |
|------|----------|-------------|--------|
| E001 | File | File not found | Check stage |
| E002 | File | Invalid format | Review file |
| E003 | Data | Schema mismatch | Update mappings |
| E004 | Data | Type conversion | Fix data |
| E005 | Validation | Rule failed | Review rules |
| E006 | System | Warehouse error | Check warehouse |
| E007 | System | Permission denied | Check roles |

### Retry Logic

**Bronze Processing**:
- Max retries: 3
- Backoff: Exponential (1min, 5min, 15min)
- After 3 failures: Move to ERROR stage

**Silver Processing**:
- Max retries: 2
- Backoff: Linear (5min, 10min)
- After 2 failures: Move to quarantine

---

## Performance Specifications

### Throughput Targets

**Bronze Layer**:
- File discovery: < 1 second per 1000 files
- File processing: < 10 seconds per 100MB file
- File movement: < 5 seconds per file

**Silver Layer**:
- Field mapping: < 1 second per 100 fields
- Transformation: < 30 seconds per 10,000 records
- Quality validation: < 10 seconds per 10,000 records

### Latency Targets

**End-to-End**:
- File upload to Bronze: < 5 minutes
- Bronze to Silver: < 15 minutes
- Total latency: < 20 minutes

### Resource Limits

**Warehouse Sizing**:
- X-Small: Up to 1GB files, 10K records/batch
- Small: Up to 5GB files, 50K records/batch
- Medium: Up to 10GB files, 100K records/batch

**Concurrency**:
- Max concurrent tasks: 8 (Snowflake limit)
- Max concurrent file processing: 10 (configurable)
- Max concurrent transformations: 5 (configurable)

---

**Document Status**: APPROVED  
**Version**: 1.0  
**Last Updated**: 2026-01-14
