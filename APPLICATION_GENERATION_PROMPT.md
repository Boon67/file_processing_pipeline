# Complete Application Generation Prompt

**Purpose**: This document contains a comprehensive prompt that can be used to regenerate the entire Snowflake File Processing Pipeline application, including all code, documentation, architecture, and system design.

**Version**: 1.0  
**Date**: January 15, 2026

---

## Master Prompt

Create a complete, production-ready **Snowflake File Processing Pipeline** with the following specifications:

### 1. PROJECT OVERVIEW

Build a **100% Snowflake-native data pipeline** with Bronze and Silver layers that:
- Automatically ingests CSV and Excel files
- Transforms raw data into clean, business-ready datasets
- Uses **TPA (Third Party Administrator) as a first-class dimension** throughout
- Requires no external orchestration (no Airflow, Dagster, etc.)
- Includes modern web UIs built with Streamlit in Snowflake
- Provides comprehensive documentation and architecture diagrams

**Key Innovation**: Every table, mapping, rule, and configuration has a **TPA dimension**, enabling complete multi-tenant isolation where different healthcare providers/administrators can have completely different schemas, mappings, and business rules.

---

### 2. ARCHITECTURE PRINCIPLES

#### Core Design Principles
1. **Snowflake Native**: Use only Snowflake features (Tasks, Stages, Stored Procedures, Streamlit)
2. **TPA-First Design**: TPA is a required dimension in all metadata tables
3. **Serverless**: No infrastructure to manage, auto-scaling
4. **Cost-Effective**: Pay only for compute during execution
5. **Production-Ready**: Comprehensive error handling, monitoring, audit trails
6. **Self-Documenting**: Code includes detailed comments and documentation

#### TPA-Aware Architecture
- **Bronze Layer**: Files organized by TPA in stage folders (`@SRC/provider_a/`, `@SRC/provider_b/`)
- **Silver Layer**: All metadata tables include `tpa` column as part of unique constraints
- **Target Tables**: TPA-specific tables (e.g., `CLAIMS_PROVIDER_A`, `CLAIMS_PROVIDER_B`)
- **Field Mappings**: Same source field can map differently per TPA
- **Transformation Rules**: Different validation/business rules per TPA
- **UI Navigation**: TPA selection at top level affects all operations

---

### 3. BRONZE LAYER (RAW INGESTION)

#### Purpose
Automated file discovery, processing, and archival with complete TPA isolation.

#### Components

**Stages (5)**:
1. `@SRC` - Landing zone for incoming files (organized by TPA folders)
2. `@COMPLETED` - Successfully processed files (30-day retention)
3. `@ERROR` - Failed files (30-day retention)
4. `@ARCHIVE` - Long-term archive (files older than 30 days)
5. `@STREAMLIT_STAGE` - Streamlit application files

**Tables (2)**:
1. **`TPA_MASTER`** - Master reference table for valid TPAs
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

2. **`RAW_DATA_TABLE`** - Stores ingested data as VARIANT (JSON)
   ```sql
   CREATE TABLE RAW_DATA_TABLE (
       RECORD_ID NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
       FILE_NAME VARCHAR(500) NOT NULL,
       FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
       TPA VARCHAR(500) NOT NULL,  -- REQUIRED: Extracted from file path
       RAW_DATA VARIANT NOT NULL,
       FILE_TYPE VARCHAR(50),
       LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
       LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER(),
       CONSTRAINT uk_file_row UNIQUE (FILE_NAME, FILE_ROW_NUMBER)
   );
   ```

3. **`file_processing_queue`** - Tracks file processing status
   ```sql
   CREATE TABLE file_processing_queue (
       queue_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
       file_name VARCHAR(500) NOT NULL UNIQUE,
       tpa VARCHAR(500) NOT NULL,  -- TPA from file path
       file_type VARCHAR(50),
       file_size_bytes NUMBER(38,0),
       status VARCHAR(50) DEFAULT 'PENDING',  -- PENDING, PROCESSING, SUCCESS, FAILED
       discovered_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
       processed_timestamp TIMESTAMP_NTZ,
       error_message VARCHAR(5000),
       process_result VARCHAR(5000),
       retry_count NUMBER(38,0) DEFAULT 0
   );
   ```

**Stored Procedures (Python + SQL)**:
1. `process_single_csv_file(file_path, tpa)` - Parse CSV files with pandas
2. `process_single_excel_file(file_path, tpa)` - Parse Excel files with openpyxl
3. `discover_files()` - Scan @SRC stage, extract TPA from path, add to queue
4. `process_queued_files()` - Process PENDING files (batch of 10)
5. `move_processed_files()` - Move SUCCESS files to @COMPLETED
6. `move_failed_files()` - Move FAILED files to @ERROR
7. `archive_old_files()` - Move files older than 30 days to @ARCHIVE

**Task Pipeline (5 tasks)**:
```
discover_files_task (Every 60 minutes - configurable)
    ↓
process_files_task (After discovery)
    ↓
    ├─→ move_successful_files_task (Parallel)
    └─→ move_failed_files_task (Parallel)
    
archive_old_files_task (Daily at 2 AM - independent)
```

**Key Features**:
- TPA extracted from file path: `@SRC/provider_a/claims.csv` → TPA = 'provider_a'
- Deduplication via MERGE on (FILE_NAME, FILE_ROW_NUMBER)
- Automatic file archival (30-day retention in COMPLETED/ERROR)
- Comprehensive error handling and logging
- Queue-based processing with status tracking

---

### 4. SILVER LAYER (TRANSFORMATION & QUALITY)

#### Purpose
Transform Bronze raw data into clean, standardized Silver tables using TPA-specific mappings and rules.

#### Components

**Stages (3)**:
1. `@SILVER_STAGE` - Intermediate transformation files
2. `@SILVER_CONFIG` - Mapping and rules configuration CSVs
3. `@SILVER_STREAMLIT` - Silver Streamlit application files

**Metadata Tables (8)** - All include TPA dimension:

1. **`target_schemas`** - Dynamic target table definitions per TPA
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
       created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
       updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
       created_by VARCHAR(500) DEFAULT CURRENT_USER(),
       active BOOLEAN DEFAULT TRUE,
       CONSTRAINT uk_target_schemas UNIQUE (table_name, column_name, tpa)
   );
   ```

2. **`field_mappings`** - Bronze → Silver field mappings per TPA
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

3. **`transformation_rules`** - Data quality and business rules per TPA
   ```sql
   CREATE TABLE transformation_rules (
       rule_id VARCHAR(100) NOT NULL,
       tpa VARCHAR(500) NOT NULL,  -- REQUIRED
       rule_name VARCHAR(500) NOT NULL,
       rule_type VARCHAR(50) NOT NULL,  -- DATA_QUALITY, BUSINESS_LOGIC, STANDARDIZATION, DEDUPLICATION, REFERENTIAL_INTEGRITY
       target_table VARCHAR(500),
       target_column VARCHAR(500),
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

4. **`silver_processing_log`** - Transformation batch audit trail
5. **`data_quality_metrics`** - Quality tracking per TPA and batch
6. **`quarantine_records`** - Failed validation records
7. **`processing_watermarks`** - Incremental processing state per TPA
8. **`llm_prompts`** - LLM prompt templates for field mapping

**Stored Procedures (34 total)** - Key procedures:

**Target Table Management**:
- `create_silver_table(table_name, tpa)` - Dynamically create target table from metadata
- `add_column_to_silver_table(table_name, column_name, tpa)` - Add column dynamically
- `get_target_schema(table_name, tpa)` - Retrieve schema definition

**Field Mapping**:
- `auto_map_fields_ml(source_table, tpa, top_n, threshold)` - ML-based auto-mapping using TF-IDF
- `auto_map_fields_llm(source_table, tpa, model, prompt_name)` - LLM-based semantic mapping
- `approve_mappings_for_table(table_name, tpa, min_confidence)` - Bulk approve mappings
- `get_approved_mappings(target_table, tpa)` - Retrieve approved mappings

**Rules Engine**:
- `apply_transformation_rules(target_table, tpa, batch_id)` - Apply all active rules
- `validate_data_quality(target_table, tpa, batch_id)` - Run quality checks
- `apply_business_logic(target_table, tpa, batch_id)` - Apply business rules
- `apply_standardization(target_table, tpa, batch_id)` - Standardize data

**Transformation**:
- `transform_bronze_to_silver(source_table, target_table, tpa, source_schema, batch_size, apply_rules, incremental)` - Main transformation procedure
- `get_transformation_status(batch_id)` - Check transformation status
- `reprocess_quarantined_records(batch_id, tpa)` - Retry failed records

**Task Management**:
- `resume_all_silver_tasks()` - Resume all Silver tasks
- `suspend_all_silver_tasks()` - Suspend all Silver tasks

**Task Pipeline (5 tasks)**:
```
bronze_completion_sensor (Every 5 minutes)
    ↓
silver_discovery_task (After Bronze completion)
    ↓
silver_transformation_task (Applies mappings & rules per TPA)
    ↓
silver_quality_check_task (Validates output)
    ↓
    ├─→ silver_publish_task (Success)
    └─→ silver_quarantine_task (Failure)
```

**Field Mapping Methods**:
1. **Manual CSV**: User-defined mappings loaded from CSV files
2. **ML Pattern Matching**: Auto-suggest using similarity algorithms (exact, substring, TF-IDF)
3. **LLM Cortex AI**: Semantic understanding using Snowflake Cortex AI models

**Rule Types**:
1. **DATA_QUALITY**: Null checks, format validation, range checks
2. **BUSINESS_LOGIC**: Calculations, lookups, conditional transformations
3. **STANDARDIZATION**: Date normalization, name casing, code mapping
4. **DEDUPLICATION**: Exact/fuzzy matching with conflict resolution
5. **REFERENTIAL_INTEGRITY**: Foreign key validation, lookup validation

---

### 5. RBAC SECURITY MODEL

**Three-Tier Role Hierarchy**:
```
<DATABASE>_ADMIN (Full administrative access)
    ↓ inherits
<DATABASE>_READWRITE (Execute procedures, operate tasks, read/write data)
    ↓ inherits
<DATABASE>_READONLY (Read-only access to tables and stages)
```

**Permissions**:
- **ADMIN**: CREATE, ALTER, DROP all objects; EXECUTE TASK privilege
- **READWRITE**: EXECUTE procedures, OPERATE tasks, SELECT/INSERT/UPDATE/DELETE data
- **READONLY**: SELECT on tables, LIST on stages

**Task Privilege Delegation**:
```
ACCOUNTADMIN (one-time)
    ↓ WITH GRANT OPTION
SYSADMIN (can delegate to other roles)
    ↓
<DATABASE>_ADMIN (project role)
```

---

### 6. STREAMLIT APPLICATIONS

#### Bronze Ingestion Pipeline

**Features**:
- 📤 **Upload Files**: Drag-and-drop interface with TPA selection
- 📊 **Processing Status**: Real-time monitoring with success/failure metrics
- 📂 **File Stages**: Browse files across all stages (Source, Completed, Error, Archive)
- 📋 **Raw Data Viewer**: View ingested data with TPA filtering
- ⚙️ **Task Management**: Pause, resume, execute tasks on-demand; view task history

**Key UI Elements**:
- TPA dropdown at top of sidebar (mandatory selection)
- Files automatically uploaded to `@SRC/{tpa}/`
- Processing status filtered by TPA
- Task execution metrics and history

**Technology**:
- Streamlit 1.51.0
- Snowflake Snowpark Python
- Pandas for data display

#### Silver Transformation Manager

**Features**:
- 🎯 **Target Table Designer**: Define target schemas per TPA
- 🗺️ **Field Mapper**: Create mappings using Manual/ML/LLM methods
- 📜 **Rules Engine**: Define transformation rules per TPA
- 🔄 **Transformation Monitor**: Run and monitor transformations
- 📊 **Data Viewer**: Browse transformed data
- 📈 **Quality Dashboard**: View data quality metrics per TPA

**Key UI Elements**:
- TPA selection at top of sidebar (affects all operations)
- Tables/mappings/rules filtered by selected TPA
- LLM mapping approval dialog (review and approve immediately)
- Batch transformation with progress tracking
- Quality metrics dashboard per TPA

**Technology**:
- Streamlit 1.51.0
- Snowflake Snowpark Python
- Pandas for data manipulation
- Custom CSS for dropdown behavior (disable text input)

**Critical UI Fixes**:
1. TPA dropdown triggers immediate page refresh
2. All data filtered by selected TPA
3. Selectboxes prevent text input (dropdown-only)
4. Sidebar organized: Branding → TPA Selection → Navigation → Quick Actions → Information

---

### 7. DEPLOYMENT SYSTEM

#### Deployment Scripts

**Master Script**: `deploy.sh`
- Deploys both Bronze and Silver layers
- Beautiful colored output with ASCII box borders
- Progress indicators (🥉 Bronze, 🥈 Silver)
- Deployment timing and duration tracking
- Comprehensive deployment summary
- Graceful error handling

**Layer Scripts**: `deploy_bronze.sh`, `deploy_silver.sh`
- Individual layer deployment
- Idempotent (can be run multiple times)
- Detailed logging to `logs/` directory

**Undeploy Script**: `undeploy.sh`
- Complete cleanup (database, roles, Streamlit apps)
- Double confirmation required
- Safe removal of all components

**Configuration**:
- `default.config` - Default settings
- `custom.config.example` - Template for custom configs
- Environment-specific configs (dev, staging, prod)

**Logging**:
- Automatic log files: `logs/{layer}_deployment_{YYYYMMDD}_{HHMMSS}.log`
- Log levels: INFO, SUCCESS, WARNING, ERROR
- Performance tracking (execution time per script)
- Complete audit trail

**Platform Support**:
- macOS: Fully supported
- Linux: Fully supported
- Windows: Git Bash required (automatic Unicode handling)

---

### 8. TPA IMPLEMENTATION DETAILS

#### TPA Data Flow

```
1. File Upload
   User selects TPA → Uploads file → Stored in @SRC/{tpa}/

2. Bronze Processing
   discover_files() extracts TPA from path → Stores in RAW_DATA_TABLE.TPA

3. Silver Configuration
   User selects TPA in UI → All operations filtered by TPA

4. Field Mapping
   Mappings defined per TPA → Same source field can map differently

5. Transformation
   Rules applied per TPA → Different validation per provider

6. Target Tables
   TPA-specific tables → CLAIMS_PROVIDER_A, CLAIMS_PROVIDER_B
```

#### TPA Naming Convention

**TPA Codes**: Lowercase with underscores (e.g., `provider_a`, `blue_cross`)
**Target Tables**: `{TABLE_NAME}_{TPA_CODE}` (e.g., `CLAIMS_PROVIDER_A`)

#### TPA Benefits

1. **Complete Isolation**: Each TPA has independent schemas, mappings, rules
2. **Parallel Processing**: Different TPAs processed simultaneously
3. **Flexible Evolution**: TPAs can change independently
4. **Clear Governance**: Easy to audit TPA-specific transformations
5. **Performance**: Queries only scan relevant TPA data
6. **Compliance**: Physical data segregation for audits
7. **Cost Allocation**: Track storage/compute per TPA

---

### 9. SAMPLE DATA

**Structure**:
```
sample_data/
├── claims_data/
│   ├── provider_a/
│   │   └── dental-claims-20240301.csv
│   ├── provider_b/
│   │   └── medical-claims-20240115.csv
│   ├── provider_c/
│   │   └── medical-claims-20240215.xlsx
│   ├── provider_d/
│   │   └── medical-claims-20240315.xlsx
│   └── provider_e/
│       └── pharmacy-claims-20240201.csv
└── config/
    ├── silver_target_schemas.csv
    ├── silver_field_mappings.csv
    ├── silver_transformation_rules.csv
    ├── silver_llm_prompts.csv
    └── silver_data_quality_metrics.csv
```

**Claims Data Fields** (varies by TPA):
- Claim identifiers (CLAIM_NUM, CLAIM_ID, etc.)
- Patient info (FIRST_NAME, LAST_NAME, DOB, etc.)
- Provider info (PROVIDER_NAME, NPI, etc.)
- Service details (SERVICE_DATE, DIAGNOSIS, PROCEDURE, etc.)
- Financial (BILLED_AMOUNT, PAID_AMOUNT, etc.)

**Default TPAs**:
- `provider_a` - Provider A Healthcare (Dental)
- `provider_b` - Provider B Insurance (Medical)
- `provider_c` - Provider C Medical (Medical)
- `provider_d` - Provider D Dental (Medical)
- `provider_e` - Provider E Pharmacy (Pharmacy)

---

### 10. DOCUMENTATION STRUCTURE

#### Core Documents

1. **README.md** - Complete project overview, features, quick reference
2. **QUICK_START.md** - 10-minute deployment guide
3. **DOCUMENTATION_INDEX.md** - Complete documentation navigation

#### Comprehensive Guides

4. **docs/USER_GUIDE.md** - Complete usage guide with screenshots
5. **docs/DEPLOYMENT_AND_OPERATIONS.md** - Deployment, configuration, logging, troubleshooting
6. **docs/guides/TPA_COMPLETE_GUIDE.md** - TPA architecture, naming, configuration, best practices

#### Architecture & Design

7. **docs/design/ARCHITECTURE.md** - Complete architecture reference with diagrams
8. **docs/design/SYSTEM_DESIGN.md** - High-level system design
9. **docs/design/TECHNICAL_SPECIFICATION.md** - Detailed technical specifications
10. **docs/design/DEPLOYMENT_GUIDE.md** - Operations manual
11. **docs/design/README.md** - Design documentation overview

#### Layer-Specific

12. **bronze/README.md** - Bronze layer documentation
13. **silver/README.md** - Silver layer documentation
14. **bronze/bronze_streamlit/README.md** - Bronze UI documentation
15. **silver/silver_streamlit/README.md** - Silver UI documentation
16. **bronze/TPA_UPLOAD_GUIDE.md** - TPA file upload guide
17. **silver/TPA_MAPPING_GUIDE.md** - TPA mapping guide

#### Specialized

18. **docs/guides/SNOWFLAKE_PERFORMANCE_NOTE.md** - Performance optimization
19. **silver/DEPLOYMENT_VERIFICATION.md** - Post-deployment checks
20. **docs/testing/TEST_PLAN_BRONZE.md** - Testing procedures
21. **sample_data/README.md** - Sample data documentation

#### Changelogs

22. **docs/changelogs/2026-01-15_features_and_fixes.md** - Recent updates

---

### 11. ARCHITECTURE DIAGRAMS

Generate the following diagrams using Python (diagrams library):

1. **architecture_overview.png** - High-level system architecture
   - Show Bronze and Silver layers
   - Data flow from files to target tables
   - Snowflake components (Stages, Tasks, Procedures, Streamlit)

2. **data_flow_diagram.png** - End-to-end data flow
   - File upload → Bronze → Silver → Analytics
   - Show TPA dimension at each stage

3. **security_rbac_diagram.png** - Security and RBAC model
   - Three-tier role hierarchy
   - Permission grants
   - Task privilege delegation

4. **deployment_pipeline_diagram.png** - CI/CD deployment pipeline
   - Deployment scripts flow
   - Configuration management
   - Logging and verification

5. **bronze_architecture.png** - Bronze layer detailed view
   - 5 stages
   - 3 tables
   - 5 tasks with dependencies
   - Stored procedures

6. **silver_architecture.png** - Silver layer detailed view
   - 3 stages
   - 8 metadata tables
   - 5 tasks with dependencies
   - 34 stored procedures
   - Field mapping methods

7. **overall_data_flow.png** - Complete data flow
   - Multi-TPA data flow
   - Parallel processing
   - Quality checks and quarantine

8. **project_structure.png** - Project file structure
   - Directory tree
   - Key files and folders

**Diagram Requirements**:
- Use professional color scheme (blues, greens, grays)
- Include icons for components
- Show data flow direction with arrows
- Label all components clearly
- Include TPA dimension where relevant

---

### 12. CODE STRUCTURE

```
file_processing_pipeline/
├── README.md
├── QUICK_START.md
├── DOCUMENTATION_INDEX.md
├── APPLICATION_GENERATION_PROMPT.md (this file)
├── default.config
├── custom.config.example
├── deploy.sh
├── deploy_bronze.sh
├── deploy_silver.sh
├── undeploy.sh
├── redeploy_silver_streamlit.sh
├── validate_structure.sh
│
├── bronze/
│   ├── README.md
│   ├── 1_Setup_Database_Roles.sql
│   ├── 2_Bronze_Schema_Tables.sql
│   ├── 3_Bronze_Setup_Logic.sql
│   ├── 4_Bronze_Tasks.sql
│   ├── Fix_Task_Privileges.sql
│   ├── Reset.sql
│   ├── TPA_Management.sql
│   ├── TPA_UPLOAD_GUIDE.md
│   └── bronze_streamlit/
│       ├── streamlit_app.py
│       ├── environment.yml
│       ├── snowflake.yml
│       └── README.md
│
├── silver/
│   ├── README.md
│   ├── 1_Silver_Schema_Setup.sql
│   ├── 2_Silver_Target_Schemas.sql
│   ├── 3_Silver_Mapping_Procedures.sql
│   ├── 4_Silver_Rules_Engine.sql
│   ├── 5_Silver_Transformation_Logic.sql
│   ├── 6_Silver_Tasks.sql
│   ├── 7_Silver_Standard_Metadata_Columns.sql
│   ├── DEPLOYMENT_VERIFICATION.md
│   ├── TPA_MAPPING_GUIDE.md
│   ├── quick_deployment_check.sql
│   ├── verify_silver_deployment.sql
│   ├── mappings/
│   │   ├── target_tables.csv
│   │   ├── field_mappings.csv
│   │   └── transformation_rules.csv
│   └── silver_streamlit/
│       ├── streamlit_app.py
│       ├── environment.yml
│       ├── snowflake.yml
│       └── README.md
│
├── docs/
│   ├── USER_GUIDE.md
│   ├── DEPLOYMENT_AND_OPERATIONS.md
│   ├── design/
│   │   ├── README.md
│   │   ├── ARCHITECTURE.md
│   │   ├── SYSTEM_DESIGN.md
│   │   ├── TECHNICAL_SPECIFICATION.md
│   │   ├── DEPLOYMENT_GUIDE.md
│   │   ├── generate_design_diagrams.py
│   │   └── images/
│   │       ├── architecture_overview.png
│   │       ├── data_flow_diagram.png
│   │       ├── security_rbac_diagram.png
│   │       ├── deployment_pipeline_diagram.png
│   │       ├── bronze_architecture.png
│   │       ├── silver_architecture.png
│   │       ├── overall_data_flow.png
│   │       └── project_structure.png
│   ├── guides/
│   │   ├── TPA_COMPLETE_GUIDE.md
│   │   └── SNOWFLAKE_PERFORMANCE_NOTE.md
│   ├── changelogs/
│   │   └── 2026-01-15_features_and_fixes.md
│   ├── screenshots/
│   │   ├── README.md
│   │   ├── bronze_processing_status.png
│   │   ├── bronze_upload_files.png
│   │   ├── silver_data_viewer.png
│   │   └── silver_field_mapper.png
│   └── testing/
│       └── TEST_PLAN_BRONZE.md
│
├── sample_data/
│   ├── README.md
│   ├── claims_data/
│   │   ├── README.md
│   │   ├── provider_a/
│   │   │   └── dental-claims-20240301.csv
│   │   ├── provider_b/
│   │   │   └── medical-claims-20240115.csv
│   │   ├── provider_c/
│   │   │   └── medical-claims-20240215.xlsx
│   │   ├── provider_d/
│   │   │   └── medical-claims-20240315.xlsx
│   │   └── provider_e/
│   │       └── pharmacy-claims-20240201.csv
│   └── config/
│       ├── README.md
│       ├── silver_target_schemas.csv
│       ├── silver_field_mappings.csv
│       ├── silver_transformation_rules.csv
│       ├── silver_llm_prompts.csv
│       └── silver_data_quality_metrics.csv
│
└── logs/
    └── README.md
```

---

### 13. KEY IMPLEMENTATION REQUIREMENTS

#### Bronze Layer Requirements

1. **File Discovery**:
   - Scan @SRC stage recursively
   - Extract TPA from file path (folder name)
   - Support CSV and Excel formats
   - Detect file type automatically
   - Add to processing queue with TPA

2. **File Processing**:
   - Parse CSV with pandas (auto-detect delimiter)
   - Parse Excel with openpyxl (all sheets)
   - Store as VARIANT (JSON) in RAW_DATA_TABLE
   - Include TPA in every record
   - Deduplication via MERGE on (FILE_NAME, FILE_ROW_NUMBER)

3. **Error Handling**:
   - Catch all exceptions
   - Log detailed error messages
   - Move failed files to @ERROR stage
   - Track retry count
   - Quarantine corrupt files

4. **Task Scheduling**:
   - Discovery every 60 minutes (configurable)
   - Processing after discovery
   - Parallel file movement
   - Daily archival at 2 AM
   - Proper task dependencies

#### Silver Layer Requirements

1. **Dynamic Schema Management**:
   - Create tables from metadata
   - Add columns dynamically
   - Support all Snowflake data types
   - Include standard metadata columns
   - TPA-specific table names

2. **Field Mapping**:
   - Manual CSV import
   - ML-based auto-mapping (TF-IDF, exact, substring)
   - LLM-based semantic mapping (Cortex AI)
   - Confidence scoring
   - Approval workflow

3. **Rules Engine**:
   - 5 rule types (DQ, BL, STD, DD, REF)
   - 4 error actions (REJECT, QUARANTINE, FLAG, CORRECT)
   - Priority-based execution
   - TPA-specific rules
   - Comprehensive logging

4. **Transformation**:
   - Batch processing (configurable size)
   - Incremental processing (watermark-based)
   - Apply mappings and rules
   - Quality validation
   - Quarantine failed records

5. **Quality Tracking**:
   - Record-level metrics
   - Batch-level metrics
   - TPA-level metrics
   - Trend analysis
   - Alerting thresholds

#### Streamlit Requirements

1. **Bronze UI**:
   - TPA selection mandatory
   - File upload with TPA
   - Processing status by TPA
   - Stage file browser
   - Raw data viewer with TPA filter
   - Task management (pause/resume/execute)
   - Task history and metrics

2. **Silver UI**:
   - TPA selection at top of sidebar
   - Target table designer per TPA
   - Field mapper (Manual/ML/LLM)
   - LLM mapping approval dialog
   - Rules engine per TPA
   - Transformation monitor
   - Data viewer by TPA
   - Quality dashboard by TPA

3. **UI Best Practices**:
   - Disable text input in selectboxes
   - TPA change triggers page refresh
   - Clear session state on TPA change
   - Filter all data by selected TPA
   - Organized sidebar layout
   - Responsive design
   - Error handling and validation

#### Deployment Requirements

1. **Configuration Management**:
   - Default config with all settings
   - Custom config support
   - Environment-specific configs
   - Variable substitution in SQL

2. **Logging**:
   - Timestamped log files
   - Log levels (INFO, SUCCESS, WARNING, ERROR)
   - Performance tracking
   - Complete audit trail

3. **Error Handling**:
   - Graceful failures
   - Rollback on error
   - Clear error messages
   - Troubleshooting guidance

4. **Platform Support**:
   - macOS/Linux native
   - Windows Git Bash
   - Unicode handling
   - Path conversion

---

### 14. TESTING REQUIREMENTS

#### Unit Tests
- Test each stored procedure independently
- Mock Snowflake session
- Test TPA filtering
- Test error handling

#### Integration Tests
- End-to-end file processing
- Bronze → Silver transformation
- Multi-TPA scenarios
- Task execution

#### UI Tests
- TPA selection and filtering
- File upload per TPA
- Mapping approval workflow
- Transformation execution

#### Performance Tests
- Large file processing (100MB+)
- Batch transformation (1M+ records)
- Concurrent TPA processing
- Query performance

---

### 15. DOCUMENTATION REQUIREMENTS

Each document must include:

1. **Header**:
   - Title
   - Purpose/Overview
   - Last Updated date
   - Version number

2. **Table of Contents**:
   - For documents > 5 sections
   - Linked navigation

3. **Content**:
   - Clear, concise language
   - Code examples with syntax highlighting
   - Screenshots where helpful
   - Step-by-step instructions
   - Troubleshooting sections

4. **Cross-References**:
   - Links to related documents
   - Consistent link format
   - Relative paths

5. **Footer**:
   - Version
   - Last Updated
   - Status (Draft/Complete/Approved)

---

### 16. QUALITY STANDARDS

#### Code Quality
- Comprehensive comments
- Consistent naming conventions
- Error handling in all procedures
- Logging at key points
- Idempotent operations

#### SQL Quality
- Parameterized queries
- Proper indexing
- Efficient joins
- Avoid SELECT *
- Use CTEs for readability

#### Python Quality
- Type hints
- Docstrings
- Error handling
- Pandas best practices
- Memory efficiency

#### Documentation Quality
- No broken links
- Consistent formatting
- Up-to-date information
- Clear examples
- Complete coverage

---

### 17. SUCCESS CRITERIA

The application is complete when:

✅ All Bronze layer components deployed and tested
✅ All Silver layer components deployed and tested
✅ Both Streamlit apps functional
✅ TPA dimension implemented throughout
✅ Sample data processes successfully
✅ All documentation complete
✅ All architecture diagrams generated
✅ Deployment scripts work on all platforms
✅ RBAC security model implemented
✅ Logging and monitoring functional
✅ Error handling comprehensive
✅ Performance meets requirements
✅ Code is well-commented
✅ Tests pass

---

### 18. DELIVERABLES

1. **Code**:
   - All SQL scripts (Bronze + Silver)
   - All Python code (Streamlit apps)
   - All deployment scripts
   - Configuration files

2. **Documentation**:
   - All 22 documentation files
   - Complete and cross-referenced
   - Screenshots included

3. **Architecture**:
   - All 8 architecture diagrams
   - Professional quality
   - PNG format

4. **Sample Data**:
   - 5 TPA sample files
   - Configuration CSVs
   - README documentation

5. **Tests**:
   - Test plans
   - Verification scripts
   - Sample test data

---

### 19. TECHNOLOGY STACK

**Snowflake Components**:
- Snowflake Tasks (orchestration)
- Snowflake Stages (file storage)
- Snowflake Stored Procedures (Python + SQL)
- Snowflake Cortex AI (LLM mapping)
- Streamlit in Snowflake (UI)

**Python Libraries**:
- snowflake-snowpark-python
- pandas
- openpyxl (Excel)
- streamlit
- scikit-learn (ML mapping)

**Development Tools**:
- Snowflake CLI (snow)
- Git
- Python 3.8+
- Bash

**Deployment**:
- Bash scripts
- Configuration files
- Logging system

---

### 20. SPECIAL NOTES

#### TPA Implementation Critical Points

1. **TPA is REQUIRED**: Every metadata table must have TPA as part of unique constraint
2. **TPA from Path**: Bronze extracts TPA from file path automatically
3. **TPA Selection**: UI must have TPA selection at top level
4. **TPA Filtering**: All queries must filter by selected TPA
5. **TPA Tables**: Use TPA-specific table names (CLAIMS_PROVIDER_A)
6. **TPA Validation**: Validate TPA against TPA_MASTER table
7. **TPA Isolation**: Complete data isolation between TPAs

#### Performance Considerations

1. **Batch Size**: Default 10,000 records, configurable
2. **Parallel Processing**: Process different TPAs in parallel
3. **Incremental**: Use watermarks to avoid reprocessing
4. **Indexes**: Add indexes on TPA columns
5. **Clustering**: Cluster tables by TPA
6. **Warehouse Sizing**: Recommend Medium for production

#### Security Considerations

1. **RBAC**: Three-tier role hierarchy
2. **Task Privileges**: Delegation model to minimize ACCOUNTADMIN
3. **Data Encryption**: SSE for all stages
4. **Audit Logging**: Complete audit trail
5. **Row-Level Security**: TPA-based if using shared tables

---

## END OF PROMPT

This prompt contains all specifications needed to regenerate the complete Snowflake File Processing Pipeline application with full TPA support, documentation, and architecture.

**Key Innovation**: TPA (Third Party Administrator) as a first-class dimension throughout the entire application, enabling true multi-tenant isolation with different schemas, mappings, and rules per provider.

**Result**: A production-ready, Snowflake-native data pipeline that requires no external orchestration and provides complete flexibility for multiple healthcare providers/administrators with different data structures and business requirements.

---

**Version**: 1.0  
**Date**: January 15, 2026  
**Status**: ✅ Complete
