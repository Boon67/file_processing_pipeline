# Snowflake File Processing Pipeline

An automated file ingestion pipeline built entirely on **Snowflake Native Features** - no external orchestration required. This project demonstrates how to build a production-ready data pipeline using Snowflake Tasks, Python stored procedures, and Streamlit in Snowflake.

## 🚀 Quick Links

- **[Quick Start Guide](QUICK_START.md)** - Get started in 10 minutes
- **[Deployment Checklist](DEPLOYMENT_CHECKLIST.md)** - Step-by-step deployment verification
- **[User Guide](docs/USER_GUIDE.md)** - Detailed usage instructions
- **[Architecture](docs/architecture/ARCHITECTURE.md)** - System design and components
- **[Deployment Verification](silver/DEPLOYMENT_VERIFICATION.md)** - Post-deployment validation
- **[Documentation Index](DOCUMENTATION_INDEX.md)** - Complete documentation guide

## 🎯 Overview

This project showcases a complete **Bronze and Silver layer data pipeline** that:
- **Bronze Layer**: Automatically discovers, processes, and archives CSV and Excel files using Snowflake's native task scheduling
- **Silver Layer**: Transforms raw Bronze data into clean, standardized datasets using intelligent field mapping (Manual/ML/LLM) and a comprehensive rules engine

Both layers include modern web interfaces built with Streamlit in Snowflake for monitoring and management.

### What Makes This Pipeline Special

- **100% Snowflake Native**: No external orchestrators (Airflow, Dagster, etc.) required
- **Zero Infrastructure**: Serverless architecture with automatic scaling
- **Intelligent Automation**: ML and LLM-powered field mapping and transformation
- **Production Ready**: Comprehensive error handling, monitoring, and audit trails
- **Cost Effective**: Pay only for compute during execution
- **Easy Deployment**: Single-command deployment with configuration management

## ✨ Key Features

### Pipeline Automation
- ⏰ **Automated File Discovery**: Scans stages every 60 minutes for new files (configurable)
- 📊 **Multi-Format Support**: Handles CSV and Excel (.xlsx, .xls) files
- 🔄 **Queue-Based Processing**: Tracks status (PENDING → PROCESSING → SUCCESS/FAILED)
- 🔗 **Task Dependencies**: Five tasks with dependencies and parallel processing
- ⚠️ **Error Handling**: Failed files automatically quarantined with detailed logging
- 🔒 **Deduplication**: MERGE-based approach prevents duplicate data loads
- 📁 **File Archival**: Automatic file movement after processing (30-day retention)
- 🗄️ **Long-Term Archive**: Files older than 30 days moved to archive stage daily
- 🛡️ **RBAC Security**: Three-tier role hierarchy (ADMIN, READWRITE, READONLY)

### Streamlit Web Application
- 📤 **File Upload**: Drag-and-drop interface for CSV/Excel files
- 📊 **Processing Status**: Real-time monitoring with comprehensive statistics
- 📂 **Stage Management**: Browse files across all stages (Source, Completed, Error, Archive)
- ⚙️ **Task Control**: Pause, resume, and execute tasks on-demand
- 📈 **Task History**: View execution history with runtime metrics
- ⏱️ **Performance Metrics**: Average, min, max runtime for each task
- 🔍 **Error Tracking**: Detailed error messages and troubleshooting
- 📋 **Compact UI**: Collapsible task views with efficient layout

## 🏗️ Architecture

### Visual Architecture Diagrams

#### Bronze Layer - File Ingestion Pipeline
![Bronze Layer Workflow](docs/diagrams/workflow_diagram_bronze_professional.png)

The Bronze layer handles automated file discovery, processing, and archival with a 5-task pipeline.

#### Silver Layer - Data Transformation Pipeline
![Silver Layer Workflow](docs/diagrams/workflow_diagram_silver_professional.png)

The Silver layer provides intelligent data transformation with ML/LLM field mapping and a comprehensive rules engine.

> 📁 **All diagrams are available in**: [`docs/diagrams/`](docs/diagrams/)

---

## 📸 Application Screenshots

### Bronze Ingestion Pipeline

**Processing Status Dashboard:**
![Bronze Processing Status](docs/screenshots/bronze_processing_status.png)
*Real-time monitoring of file processing with success/failure metrics*

**File Upload Interface:**
![Bronze Upload Files](docs/screenshots/bronze_upload_files.png)
*Drag-and-drop file upload with automatic discovery*

### Silver Transformation Manager

**Data Viewer:**
![Silver Data Viewer](docs/screenshots/silver_data_viewer.png)
*View and explore transformed data in Silver tables*

**Field Mapper:**
![Silver Field Mapper](docs/screenshots/silver_field_mapper.png)
*Intelligent field mapping with Manual/ML/LLM options*

> 📁 **More screenshots available in**: [`docs/screenshots/`](docs/screenshots/)

---

### Multi-Layer Data Pipeline

```
Bronze Layer (Raw Ingestion)
    ↓
Silver Layer (Transformation & Quality)
    ↓
Ready for Analytics & Reporting
```

### Bronze Layer Components

**Stages:**
- `@SRC` - Landing zone for incoming files
- `@COMPLETED` - Archive for successfully processed files (30-day retention)
- `@ERROR` - Quarantine for failed files (30-day retention)
- `@ARCHIVE` - Long-term archive for files older than 30 days
- `@STREAMLIT_STAGE` - Streamlit application files
- `@CONFIG_STAGE` - Configuration files

**Tables:**
- `RAW_DATA_TABLE` - Stores ingested data as VARIANT (JSON) with metadata
- `file_processing_queue` - Tracks file processing status and audit trail

**Stored Procedures:**
- Python procedures for CSV and Excel file parsing
- SQL procedures for file discovery and orchestration

**Task Pipeline:**
```
discover_files_task (Every 60 minutes - configurable)
    ↓
process_files_task (After discovery)
    ↓
    ├─→ move_successful_files_task (Parallel)
    └─→ move_failed_files_task (Parallel)
    
archive_old_files_task (Daily at 2 AM - independent)
```

### Silver Layer Components

**Stages:**
- `@SILVER_STAGE` - Intermediate transformation files
- `@SILVER_CONFIG` - Mapping and rules configuration files
- `@SILVER_STREAMLIT` - Silver Streamlit application files

**Metadata Tables:**
- `target_schemas` - Dynamic target table definitions
- `field_mappings` - Bronze → Silver field mappings with confidence scores
- `transformation_rules` - Data quality and business logic rules
- `silver_processing_log` - Transformation batch audit trail
- `data_quality_metrics` - Quality tracking and metrics
- `quarantine_records` - Failed validation records
- `processing_watermarks` - Incremental processing state

**Field Mapping Methods:**
- **Manual CSV**: User-defined mappings loaded from CSV files
- **ML Pattern Matching**: Auto-suggest using similarity algorithms (exact, substring, TF-IDF)
- **LLM Cortex AI**: Semantic understanding using Snowflake Cortex AI models

**Rules Engine:**
- **Data Quality**: Null checks, format validation, range checks, referential integrity
- **Business Logic**: Calculations, lookups, conditional transformations
- **Standardization**: Date normalization, name casing, code mapping
- **Deduplication**: Exact/fuzzy matching with conflict resolution

**Task Pipeline:**
```
bronze_completion_sensor (Every 5 minutes)
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

## 🚀 Quick Start

### Prerequisites

- Snowflake account with appropriate permissions
- `SYSADMIN` and `SECURITYADMIN` roles
- Access to a warehouse (default: `COMPUTE_WH`)
- **Snowflake CLI** installed and configured
- **Python** (python or python3)
- **Bash-compatible shell** (see Platform Support below)

#### Platform Support

The deployment scripts support multiple platforms:

| Platform | Shell Environment | Status |
|----------|------------------|--------|
| **macOS** | Terminal (bash/zsh) | ✅ Fully Supported |
| **Linux** | bash | ✅ Fully Supported |
| **Windows** | Git Bash | ✅ **Recommended** |
| **Windows** | WSL (Windows Subsystem for Linux) | ✅ Supported |
| **Windows** | Cygwin | ✅ Supported |
| **Windows** | Command Prompt | ❌ Not Supported |
| **Windows** | PowerShell | ❌ Not Supported |

> **Windows Users**: Install [Git for Windows](https://git-scm.com/download/win) which includes **Git Bash**. This provides a bash-compatible environment and is the recommended way to run the deployment scripts on Windows. See the [Windows-Specific Setup](#windows-specific-setup) section below for detailed instructions.

#### Install Snowflake CLI

**macOS / Linux / Git Bash (Windows):**
```bash
pip install snowflake-cli-labs

# Configure connection
snow connection add

# Test connection
snow connection test
```

**Windows-Specific Setup:**
1. Install [Git for Windows](https://git-scm.com/download/win) (includes Git Bash)
2. Install [Python](https://www.python.org/downloads/) (if not already installed)
3. Open **Git Bash** (not Command Prompt or PowerShell)
4. Run the pip install command above

For more information: [Snowflake CLI Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)

#### Windows-Specific Setup

If you're on Windows, follow these additional steps:

1. **Install Git for Windows**: Download from [git-scm.com](https://git-scm.com/download/win)
2. **Open Git Bash**: Right-click in your project folder → "Git Bash Here"
3. **Make scripts executable**:
   ```bash
   chmod +x deploy.sh deploy_bronze.sh deploy_silver.sh undeploy.sh
   ```
4. **Run deployment**: All commands must be run in Git Bash, not Command Prompt or PowerShell

**Common Windows Issues:**
- **Character encoding errors**: Scripts automatically handle Unicode characters
- **File path errors**: Scripts automatically convert Git Bash paths to Windows paths
- **Line ending issues**: Configure git: `git config --global core.autocrlf input`

See the [Platform-Specific Issues](#platform-specific-issues) section in Troubleshooting for detailed solutions.

### Deployment

#### Deploy Complete Solution (Recommended)

```bash
# Deploy both Bronze and Silver layers
./deploy.sh

# Deploy with custom configuration
./deploy.sh custom.config

# Deploy Bronze layer only
./deploy.sh --bronze-only

# Deploy Silver layer only (Bronze must exist)
./deploy.sh --silver-only
```

#### Deploy Individual Layers

**Bronze Layer Only:**
```bash
./deploy_bronze.sh

# Use custom configuration
./deploy.sh production.config
```

**Silver Layer Only:**
```bash
./deploy_silver.sh

# With custom configuration
./deploy_silver.sh custom.config
```

**Note**: The master `deploy.sh` script orchestrates both layer deployments with beautiful progress indicators and comprehensive error handling. Use layer-specific scripts (`deploy_bronze.sh`, `deploy_silver.sh`) for targeted deployments or redeployments.

**Windows Users**: Run all deployment commands in **Git Bash**, not Command Prompt or PowerShell. The scripts automatically detect your platform and adjust accordingly.

### Deployment Scripts Overview

| Script | Purpose | Duration | Use Case |
|--------|---------|----------|----------|
| `deploy.sh` | Complete solution | 5-12 min | **Recommended for first-time deployment** |
| `deploy.sh --bronze-only` | Bronze layer | 2-5 min | Bronze-only deployment |
| `deploy.sh --silver-only` | Silver layer | 3-7 min | Silver-only (Bronze exists) |
| `deploy_bronze.sh` | Bronze layer | 2-5 min | Direct Bronze deployment/redeployment |
| `deploy_silver.sh` | Silver layer | 3-7 min | Direct Silver deployment/redeployment |
| `undeploy.sh` | Remove all | 1-2 min | Complete cleanup |

**Master Script Features:**
- 🎨 Beautiful colored output with ASCII box borders
- 📊 Progress indicators for each layer (🥉 Bronze, 🥈 Silver)
- ⏱️ Deployment timing and duration tracking
- ✅ Comprehensive deployment summary
- 📋 Next steps guidance
- ⚠️ Graceful error handling with continuation options

The deployment script will:
1. ✅ Load configuration from config file
2. ✅ Verify SYSADMIN and SECURITYADMIN permissions
3. ✅ Deploy database, roles, schemas, stages, and tables
4. ✅ Create Python and SQL stored procedures
5. ✅ Set up the task pipeline
6. ✅ Deploy Streamlit app to PUBLIC schema
7. ✅ Grant permissions to all roles

#### Complete Removal (Undeploy)

To completely remove all deployed components:

```bash
./undeploy.sh
```

**⚠️ WARNING**: This will permanently delete:
- Streamlit application
- Database and ALL data
- All stages and files
- Custom roles

The script will:
1. ⚠️ Show warning and require confirmation
2. 🗑️ Remove Streamlit app
3. 🗑️ Suspend and drop all tasks
4. 🗑️ Drop database (including all schemas, tables, stages)
5. 🗑️ Drop custom roles
6. ✅ Clean up temporary files

**Safety Features:**
- Requires typing "yes" to confirm
- Requires typing database name to confirm
- Uses same configuration as deploy.sh
- Shows detailed progress and results

#### Configuration

Edit `default.config` to customize:

```bash
# Database Configuration
DATABASE_NAME="db_ingest_pipeline"
SCHEMA_NAME="BRONZE"
WAREHOUSE_NAME="COMPUTE_WH"

# Stage Configuration
SRC_STAGE_NAME="SRC"
COMPLETED_STAGE_NAME="COMPLETED"
ERROR_STAGE_NAME="ERROR"

# Task Configuration
DISCOVER_TASK_NAME="discover_files_task"
PROCESS_TASK_NAME="process_files_task"
MOVE_SUCCESS_TASK_NAME="move_successful_files_task"
MOVE_FAILED_TASK_NAME="move_failed_files_task"

# Streamlit App Configuration
STREAMLIT_APP_NAME="BRONZE_INGESTION_PIPELINE"

# Deployment Settings
ACCEPT_DEFAULTS="true"                  # Skip prompts
USE_DEFAULT_CLI_CONNECTION="true"       # Use default connection
```

## 📱 Streamlit Application

### Accessing the App

1. Navigate to **Snowsight**
2. Click **"Streamlit"** in the left sidebar
3. Open **"BRONZE_INGESTION_PIPELINE"**

Or use the direct URL:
```
https://<account>.snowflakecomputing.com/streamlit/<database>/PUBLIC/BRONZE_INGESTION_PIPELINE
```

### App Features

#### 📤 Upload Files Tab
- Drag-and-drop or browse to upload files
- Support for CSV and Excel formats
- Multi-file upload capability
- Files retain original names
- Direct upload to `@SRC` stage
- Dynamic message showing discovery schedule

#### 📊 Processing Status Tab
- Real-time processing status with comprehensive statistics
- Summary metrics (Total Files, Success, Failed, Pending)
- Detailed file-level status table with timestamps
- Error messages for failed files
- Refresh button for latest status
- Complete historical view of all processed files

#### 📂 File Stages Tab
- View files in all stages: Source, Completed, Error, Archive
- File metadata (name, size, last modified, MD5 hash)
- Stage selector dropdown
- File count per stage
- Detailed file information table

#### ⚙️ Task Management Tab
- **Compact View**: Only first task expanded by default
- **Task Status**: Real-time state (STARTED/SUSPENDED) for all 5 tasks
- **Process Now**: Execute tasks immediately on-demand
- **Resume/Suspend**: Control individual task scheduling
- **Task History**: View recent executions (last 24 hours)
- **Runtime Metrics**: Average, min, max runtime, and total runs
- **Performance Monitoring**: Track task execution times
- **Bulk Actions**: Resume All, Suspend All tasks

### Use Cases

**Upload and Process Files:**
1. Go to "File Upload" tab
2. Drag and drop CSV or Excel files
3. Go to "Task Management" tab
4. Click "Execute Discovery Now" to process immediately
5. Monitor progress in "Processing Queue" tab

**Pause Pipeline for Maintenance:**
1. Go to "Task Management" tab
2. Click "Suspend All Tasks"
3. Perform maintenance
4. Click "Resume All Tasks" when ready

**Troubleshoot Failures:**
1. Go to "Processing Queue" tab to see failed files
2. Go to "Task Management" tab to view task execution history
3. Check error messages in task history
4. Go to "Stage Files" tab to view/delete error files

## 📊 Monitoring

### Task Execution History (SQL)

```sql
SELECT 
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    ERROR_CODE,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())
))
WHERE NAME LIKE '%_files_task'
ORDER BY SCHEDULED_TIME DESC
LIMIT 100;
```

### Processing Queue Status

```sql
SELECT 
    status,
    file_type,
    COUNT(*) AS file_count,
    SUM(CASE WHEN error_message IS NOT NULL THEN 1 ELSE 0 END) AS errors
FROM file_processing_queue
GROUP BY status, file_type
ORDER BY status;
```

### Stage File Counts

```sql
SELECT 'SRC' AS stage, COUNT(*) AS file_count FROM DIRECTORY(@SRC)
UNION ALL
SELECT 'COMPLETED', COUNT(*) FROM DIRECTORY(@COMPLETED)
UNION ALL
SELECT 'ERROR', COUNT(*) FROM DIRECTORY(@ERROR)
UNION ALL
SELECT 'ARCHIVE', COUNT(*) FROM DIRECTORY(@ARCHIVE);
```

## 🎮 Pipeline Control

### Start Pipeline

```sql
-- Resume all tasks (in reverse dependency order)
ALTER TASK move_failed_files_task RESUME;
ALTER TASK move_successful_files_task RESUME;
ALTER TASK process_files_task RESUME;
ALTER TASK discover_files_task RESUME;
ALTER TASK archive_old_files_task RESUME;  -- Independent task
```

### Stop Pipeline

```sql
-- Suspend all tasks (in dependency order)
ALTER TASK discover_files_task SUSPEND;
ALTER TASK process_files_task SUSPEND;
ALTER TASK move_successful_files_task SUSPEND;
ALTER TASK move_failed_files_task SUSPEND;
ALTER TASK archive_old_files_task SUSPEND;  -- Independent task
```

### Execute Task Manually

```sql
-- Process files immediately without waiting for schedule
EXECUTE TASK discover_files_task;

-- Manually trigger archival
EXECUTE TASK archive_old_files_task;
```

## 📁 Project Structure

```
file_processing_pipeline/
├── README.md                           # This file
├── default.config                      # Default configuration
├── custom.config.example               # Example custom config
├── deploy.sh                           # Bronze layer deployment
├── deploy_silver.sh                    # Silver layer deployment
├── undeploy.sh                         # Complete removal script
│
├── sample_data/                        # Example CSV and Excel files
│   ├── aetna_dental-claims-20240301.csv
│   ├── anthem_bluecross-claims-20240115.csv
│   ├── cigna_healthcare-claims-20240215.xlsx
│   ├── kaiser_permanente-claims-20240315.xlsx
│   └── unitedhealth-claims-20240201.csv
│
├── bronze/                             # 🥉 Bronze Layer (Raw Ingestion)
│   ├── README.md                       # Bronze documentation
│   ├── 1_Setup_Database_Roles.sql      # RBAC setup
│   ├── 2_Bronze_Schema_Tables.sql      # Schema, stages, tables
│   ├── 3_Bronze_Setup_Logic.sql        # Stored procedures
│   ├── 4_Bronze_Tasks.sql              # Task pipeline
│   ├── Reset.sql                       # SQL-only cleanup
│   ├── diagnose_discover_files.sql     # Diagnostic script
│   ├── validate_structure.sh           # Structure validator
│   └── bronze_streamlit/               # Bronze Streamlit app
│       ├── streamlit_app.py            # Main application
│       ├── environment.yml             # Python environment
│       ├── snowflake.yml               # Snowflake CLI config
│       ├── deploy_streamlit.sql        # Manual deployment
│       ├── README.md                   # App documentation
│       └── DEPLOYMENT.md               # Deployment guide
│
├── silver/                             # 🥈 Silver Layer (Transformation)
│   ├── README.md                       # Silver documentation
│   ├── 1_Silver_Schema_Setup.sql       # Schema & metadata tables
│   ├── 2_Silver_Target_Schemas.sql     # Dynamic table creation
│   ├── 3_Silver_Mapping_Procedures.sql # Field mapping engine
│   ├── 4_Silver_Rules_Engine.sql       # Transformation rules
│   ├── 5_Silver_Transformation_Logic.sql # Orchestration
│   ├── 6_Silver_Tasks.sql              # Task pipeline
│   ├── test_silver_deployment.sql      # Deployment validator
│   ├── mappings/                       # Mapping configuration
│   │   ├── target_tables.csv           # Table definitions
│   │   ├── field_mappings.csv          # Field mappings
│   │   └── transformation_rules.csv    # Transformation rules
│   └── silver_streamlit/               # Silver Streamlit app
│       ├── streamlit_app.py            # Main application
│       ├── environment.yml             # Python environment
│       ├── snowflake.yml               # Snowflake CLI config
│       ├── README.md                   # App documentation
│       └── DEPLOYMENT.md               # Deployment guide
│
└── docs/                               # 📚 Documentation
    ├── README.md                       # Documentation index
    ├── architecture/
    │   └── ARCHITECTURE.md             # System architecture
    ├── deployment/
    │   └── QUICK_DEPLOYMENT_GUIDE.md   # Deployment guide
    ├── testing/
    │   ├── TEST_PLAN_BRONZE.md         # Bronze test plan
    │   └── TEST_PLAN_SILVER.md         # Silver test plan
    ├── diagrams/                       # Architecture diagrams
    │   ├── bronze_architecture.png
    │   ├── silver_architecture.png
    │   ├── overall_data_flow.png
    │   ├── project_structure.png
    │   └── generate_diagrams.py        # Diagram generator
    ├── COMPLETE_DOCUMENTATION_SUMMARY.md
    ├── SILVER_IMPLEMENTATION_SUMMARY.md
    ├── PROJECT_STRUCTURE_ANALYSIS.md
    └── STRUCTURE_CONSISTENCY_CHANGES.md
```

## 🔧 Technical Details

### Technology Stack
- **Platform**: Snowflake (Native)
- **Orchestration**: Snowflake Tasks
- **Data Processing**: Python 3.11 + Snowpark
- **UI**: Streamlit 1.51.0 in Snowflake
- **Deployment**: Snowflake CLI (`snow`)
- **Version Control**: Git-based deployment scripts

### Python Packages

**Bronze Layer:**
- `snowflake-snowpark-python` - Snowpark API
- `pandas` - Data manipulation
- `openpyxl` - Excel file processing (.xlsx, .xls)

**Silver Layer:**
- `snowflake-snowpark-python` - Snowpark API
- `pandas` - Data manipulation and transformation
- `scikit-learn` - ML-based field mapping (TF-IDF, similarity)
- Snowflake Cortex AI - LLM-based semantic mapping

### Data Storage

**Bronze Layer:**
- **Format**: VARIANT (JSON) for schema flexibility
- **Deduplication**: FILE_NAME + FILE_ROW_NUMBER composite key
- **Batch Size**: Up to 10 files per task execution
- **Discovery Schedule**: Every 60 minutes (configurable via `default.config`)
- **Archive Schedule**: Daily at 2 AM (moves files older than 30 days)
- **Retention**: 30 days in COMPLETED/ERROR stages, unlimited in ARCHIVE

**Silver Layer:**
- **Format**: Structured tables with defined schemas
- **Deduplication**: Configurable by table (exact/fuzzy matching)
- **Batch Size**: Configurable (default: 10,000 records)
- **Transform Schedule**: Every 15 minutes (configurable)
- **Incremental Processing**: Watermark-based to avoid reprocessing
- **Quality Tracking**: Metrics stored for all batches

### Security & Compliance

**Role-Based Access Control (RBAC):**
- **`{DATABASE}_ADMIN`**: Full control (create/modify/delete all objects)
- **`{DATABASE}_READWRITE`**: Execute procedures, operate tasks, read/write data
- **`{DATABASE}_READONLY`**: Read-only access to tables and stages

**Data Security:**
- **Encryption**: Snowflake SSE (Server-Side Encryption) for all stages
- **Isolation**: Dedicated database and schemas per environment
- **Audit Trail**: Complete processing history with timestamps and user tracking
- **Quarantine**: Failed records isolated for review before production

**Compliance Features:**
- Audit logging of all transformations
- Data lineage tracking (Bronze → Silver)
- Quality metrics and validation rules
- Quarantine and remediation workflows

### Performance Characteristics

**Bronze Layer:**
- **Throughput**: ~1,000 records/second for CSV files
- **Latency**: File discovery within 60 minutes (or immediate via manual trigger)
- **Scalability**: Handles files up to 100MB (configurable)
- **Concurrency**: Parallel processing of multiple files

**Silver Layer:**
- **Throughput**: ~10,000 records/minute with rules applied
- **Latency**: Transformation within 15 minutes of Bronze completion
- **Scalability**: Batch processing for millions of records
- **Concurrency**: Independent task execution per target table

### Resource Requirements

**Minimum:**
- Snowflake account (any edition)
- 1 warehouse (X-Small or larger)
- SYSADMIN and SECURITYADMIN roles
- ~100 MB storage for sample data

**Recommended for Production:**
- Medium or Large warehouse for processing
- Separate warehouses for Bronze and Silver
- Auto-suspend enabled (1 minute idle)
- Auto-resume enabled
- Resource monitors for cost control

## 💡 Why Snowflake Tasks?

✅ **Native Integration** - No external orchestrators (Airflow, Dagster, etc.)  
✅ **Cost Effective** - Pay only for warehouse compute during execution  
✅ **Serverless** - No infrastructure to manage  
✅ **Reliable** - Built-in monitoring and retry capabilities  
✅ **Scalable** - Automatically scales with Snowflake compute  
✅ **Simple** - Dependency management with `AFTER` clause  

### Comparison with Traditional Approaches

| Feature | Snowflake Tasks | Airflow/Dagster | AWS Glue | Azure Data Factory |
|---------|----------------|-----------------|----------|-------------------|
| **Setup Time** | Minutes | Hours/Days | Hours | Hours |
| **Infrastructure** | None | Servers/K8s | Managed | Managed |
| **Cost Model** | Compute only | Always-on | Per job | Per activity |
| **Monitoring** | Built-in | Custom | CloudWatch | Azure Monitor |
| **Learning Curve** | Low | High | Medium | Medium |
| **Snowflake Integration** | Native | API calls | Connectors | Connectors |
| **Maintenance** | Minimal | High | Medium | Medium |

### When to Use This Approach

**✅ Perfect For:**
- Snowflake-centric data pipelines
- Teams already using Snowflake
- Rapid prototyping and development
- Cost-conscious projects
- Minimal DevOps resources

**❌ Consider Alternatives If:**
- Multi-cloud orchestration required
- Complex cross-system dependencies
- Need for advanced DAG features
- Existing investment in other tools  

## 🔍 Troubleshooting

### Diagnostic Script

If the pipeline is not working as expected, use the diagnostic script:

```bash
snow sql -f diagnose_discover_files.sql
```

This script will check:
- ✓ Stage existence and file count
- ✓ Current queue status
- ✓ Task execution history
- ✓ Permission grants
- ✓ Simulate discovery logic

### Common Issues

#### Platform-Specific Issues

##### Windows: Script Won't Run

**Symptom:** Deployment script fails with syntax errors or "command not found"

**Cause:** Using Command Prompt or PowerShell instead of Git Bash

**Solution:**
1. Install [Git for Windows](https://git-scm.com/download/win) if not already installed
2. Open **Git Bash** (not Command Prompt or PowerShell)
3. Navigate to the project directory: `cd /c/path/to/file_processing_pipeline`
4. Run the deployment script: `./deploy.sh`

##### Windows: Character Encoding Error

**Symptom:** `'charmap' codec can't decode byte 0x90` or similar encoding errors during deployment

**Cause:** SQL files contain Unicode box-drawing characters that Windows Python can't decode with the default charmap encoding

**Solution:**
The deployment scripts now **automatically** handle this on Windows by creating temporary ASCII-safe versions of the SQL files. Simply run the deployment normally:

```bash
./deploy.sh
```

The scripts detect Windows and automatically convert Unicode characters to ASCII equivalents before execution.

##### Windows: Line Ending Issues

**Symptom:** Scripts fail with `^M: bad interpreter` or similar errors

**Cause:** Files have Windows line endings (CRLF) instead of Unix line endings (LF)

**Solution:**
```bash
# In Git Bash, convert line endings
dos2unix deploy.sh deploy_bronze.sh deploy_silver.sh

# Or configure git to handle line endings automatically
git config --global core.autocrlf input
```

##### Windows/Linux: Python Not Found

**Symptom:** "Python is not installed or not in PATH"

**Solution:**
- **Windows**: Install [Python](https://www.python.org/downloads/) and ensure "Add Python to PATH" is checked
- **Linux**: `sudo apt-get install python3` (Ubuntu/Debian) or `sudo yum install python3` (RHEL/CentOS)
- **macOS**: Python 3 is pre-installed, or install via Homebrew: `brew install python3`

After installation, verify:
```bash
python --version
# or
python3 --version
```

##### Permission Denied

**Symptom:** "Permission denied" when running scripts

**Solution:**
```bash
# Make scripts executable
chmod +x deploy.sh deploy_bronze.sh deploy_silver.sh undeploy.sh
```

#### Issue 1: Files Not Being Discovered

**Symptom:** `discover_files()` returns "Discovered 0 new files"

**Possible Causes:**
1. **No files in @SRC stage**
   ```sql
   -- Check if files exist
   SELECT * FROM DIRECTORY(@SRC);
   ```
   **Solution:** Upload files via Streamlit or `PUT file:///path/to/file.csv @SRC;`

2. **Files already processed**
   ```sql
   -- Check queue
   SELECT * FROM file_processing_queue;
   ```
   **Solution:** Files with SUCCESS status are skipped. To reprocess:
   ```sql
   UPDATE file_processing_queue SET status = 'PENDING' WHERE file_name = 'yourfile.csv';
   ```

3. **Task not running**
   ```sql
   -- Check task state
   SHOW TASKS LIKE 'discover_files_task';
   ```
   **Solution:** Resume task:
   ```sql
   ALTER TASK discover_files_task RESUME;
   ```

#### Issue 2: Files Stuck in PENDING Status

**Symptom:** Files remain in PENDING status indefinitely

**Possible Causes:**
1. **process_files_task not running**
   ```sql
   SHOW TASKS LIKE 'process_files_task';
   ```
   **Solution:** Resume task:
   ```sql
   ALTER TASK process_files_task RESUME;
   ```

2. **Task dependency issue**
   ```sql
   -- Check task dependencies
   SELECT name, state, predecessors FROM TABLE(INFORMATION_SCHEMA.TASKS_IN_SCHEMA('db_ingest_pipeline', 'BRONZE'));
   ```

#### Issue 3: Files Failing to Process

**Symptom:** Files move to FAILED status

**Diagnosis:**
```sql
-- Check error messages
SELECT file_name, error_message, process_result 
FROM file_processing_queue 
WHERE status = 'FAILED' 
ORDER BY processed_timestamp DESC;
```

**Common Solutions:**
- **Invalid file format:** Ensure CSV/Excel files are properly formatted
- **Empty files:** Check file has data rows
- **Encoding issues:** Ensure UTF-8 encoding for CSV files
- **Corrupted Excel files:** Re-save Excel files

#### Issue 4: Task History Not Showing

**Symptom:** Task Management tab shows no history

**Cause:** Task history has 45-minute latency (uses ACCOUNT_USAGE)

**Solutions:**
- Wait 45 minutes for history to appear
- Use Snowsight: Activity → Query History → Tasks
- Execute task manually and check queue:
  ```sql
  EXECUTE TASK discover_files_task;
  SELECT * FROM file_processing_queue ORDER BY discovered_timestamp DESC;
  ```

### Manual Testing

Test the pipeline manually:

```sql
-- 1. Upload a test file to @SRC
PUT file:///path/to/test.csv @SRC;

-- 2. Verify file is in stage
SELECT * FROM DIRECTORY(@SRC);

-- 3. Run discovery
CALL discover_files();

-- 4. Check queue
SELECT * FROM file_processing_queue WHERE status = 'PENDING';

-- 5. Process files
CALL process_queued_files();

-- 6. Check results
SELECT * FROM file_processing_queue ORDER BY processed_timestamp DESC;
SELECT * FROM RAW_DATA_TABLE ORDER BY LOAD_TIMESTAMP DESC LIMIT 10;
```

## 🥈 Silver Layer Usage

### Define Target Schema

```sql
USE SCHEMA SILVER;

-- Add table definition
INSERT INTO target_schemas (table_name, column_name, data_type, nullable, primary_key, description)
VALUES 
    ('CUSTOMER', 'CUSTOMER_ID', 'NUMBER(38,0) AUTOINCREMENT', FALSE, TRUE, 'Unique customer ID'),
    ('CUSTOMER', 'FIRST_NAME', 'VARCHAR(100)', FALSE, FALSE, 'Customer first name'),
    ('CUSTOMER', 'EMAIL', 'VARCHAR(200)', TRUE, FALSE, 'Customer email');

-- Create the table
CALL create_silver_table('CUSTOMER');
```

### Create Field Mappings

**Option 1: Manual Mapping**
```sql
INSERT INTO field_mappings (source_field, target_table, target_column, mapping_method, approved)
VALUES ('CUST_ID', 'CUSTOMER', 'CUSTOMER_ID', 'MANUAL', TRUE);
```

**Option 2: ML Auto-Mapping**
```sql
-- Generate ML-based mappings
CALL auto_map_fields_ml('RAW_DATA_TABLE', 3, 0.6);

-- Review and approve
SELECT * FROM field_mappings WHERE mapping_method = 'ML_AUTO';
CALL approve_mappings_for_table('CUSTOMER', 0.8);
```

**Option 3: LLM Mapping**
```sql
-- Use Cortex AI for semantic mapping
CALL auto_map_fields_llm('RAW_DATA_TABLE', 'llama3.1-70b', 'DEFAULT_FIELD_MAPPING');

-- Review results
SELECT * FROM field_mappings WHERE mapping_method = 'LLM_CORTEX';
```

### Configure Transformation Rules

```sql
-- Data quality rule
INSERT INTO transformation_rules (rule_id, rule_name, rule_type, target_column, rule_logic, priority)
VALUES ('DQ001', 'Email Format', 'DATA_QUALITY', 'EMAIL', 
        'RLIKE ''^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$''', 1);

-- Standardization rule
INSERT INTO transformation_rules (rule_id, rule_name, rule_type, target_column, rule_logic, priority)
VALUES ('STD001', 'Uppercase Name', 'STANDARDIZATION', 'FIRST_NAME', 'UPPER', 10);
```

### Run Transformation

```sql
-- Transform one batch
CALL transform_bronze_to_silver('RAW_DATA_TABLE', 'CUSTOMER', 10000, TRUE, TRUE);

-- Check results
SELECT * FROM v_transformation_status_summary;
SELECT * FROM v_data_quality_dashboard;
```

### Monitor Quality

```sql
-- View quality metrics
SELECT * FROM v_data_quality_dashboard;

-- Check quarantined records
SELECT * FROM quarantine_records WHERE resolved = FALSE;

-- View transformation history
SELECT * FROM v_recent_transformation_batches;
```

### Manage Tasks

```sql
-- Start Silver tasks
CALL resume_all_silver_tasks();

-- Stop Silver tasks
CALL suspend_all_silver_tasks();

-- Check task status
SELECT * FROM v_silver_task_status;
```

### Access Streamlit Apps

- **Bronze Management**: Snowsight → Streamlit → BRONZE_INGESTION_PIPELINE
- **Silver Management**: Snowsight → Streamlit → SILVER_DATA_MANAGER

## 🧹 Cleanup

### Complete Removal (Recommended)

Use the automated undeploy script:

```bash
./undeploy.sh
```

This will safely remove:
- Streamlit application
- All tasks (suspended first)
- Database and all data
- Custom roles

**Safety features:**
- Requires double confirmation
- Shows what will be deleted
- Detailed progress reporting

### SQL-Only Cleanup

Alternatively, run the SQL reset script:

```sql
-- Run the reset script
@bronze/Reset.sql
```

This drops the database and all associated roles.

Or use the Snowflake CLI:

```bash
snow sql -q "DROP DATABASE IF EXISTS db_ingest_pipeline CASCADE;"
snow sql -q "DROP ROLE IF EXISTS db_ingest_pipeline_ADMIN;"
snow sql -q "DROP ROLE IF EXISTS db_ingest_pipeline_READWRITE;"
snow sql -q "DROP ROLE IF EXISTS db_ingest_pipeline_READONLY;"
```

## 📚 Documentation

### 📖 Complete Documentation Guide
All documentation is organized in the `docs/` folder. Start here:
- **[📘 Complete User Guide](docs/USER_GUIDE.md)** - **⭐ START HERE** - Comprehensive guide with screenshots
- **[Documentation Index](DOCUMENTATION_INDEX.md)** - Complete guide to all documentation

### 🏗️ Architecture & Design
- **[System Architecture](docs/architecture/ARCHITECTURE.md)** - Detailed system design
- **[Architecture Diagrams](docs/diagrams/)** - Visual representations
- **[Project Structure Analysis](docs/PROJECT_STRUCTURE_ANALYSIS.md)** - Organization details

### 🚀 Deployment & Setup
- **[Quick Deployment Guide](docs/deployment/QUICK_DEPLOYMENT_GUIDE.md)** - Fast setup
- **[Deployment Checklist](DEPLOYMENT_CHECKLIST.md)** - Pre/post deployment verification

### 🥉 Bronze Layer
- **[Bronze README](bronze/README.md)** - Bronze layer overview
- **[Bronze Streamlit App](bronze/bronze_streamlit/README.md)** - UI documentation
- **[Bronze Test Plan](docs/testing/TEST_PLAN_BRONZE.md)** - Testing procedures

### 🥈 Silver Layer
- **[Silver README](silver/README.md)** - Silver layer overview and quick start
- **[Silver Streamlit App](silver/silver_streamlit/README.md)** - UI documentation
- **[Silver Test Plan](docs/testing/TEST_PLAN_SILVER.md)** - Testing procedures

### 📊 Implementation Details
- **[Complete Documentation Summary](docs/COMPLETE_DOCUMENTATION_SUMMARY.md)** - Full overview
- **[Silver Implementation Summary](docs/SILVER_IMPLEMENTATION_SUMMARY.md)** - Silver details
- **[Structure Consistency Changes](docs/STRUCTURE_CONSISTENCY_CHANGES.md)** - Recent updates

### 🔗 External Resources
- [Snowflake Tasks Documentation](https://docs.snowflake.com/en/user-guide/tasks-intro)
- [Snowpark Python Guide](https://docs.snowflake.com/en/developer-guide/snowpark/python/index)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)
- [Snowflake CLI Reference](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)

## 🔧 Troubleshooting

### Deployment Issues

**Problem**: `deploy.sh` not found or permission denied
```bash
# Make scripts executable
chmod +x deploy.sh deploy_bronze.sh deploy_silver.sh undeploy.sh
```

**Problem**: Bronze deployment fails
```bash
# Run diagnostics
snow sql -f bronze/diagnose_discover_files.sql

# Check permissions
snow sql -q "SHOW GRANTS TO USER CURRENT_USER();"
```

**Problem**: Silver deployment fails
```bash
# Validate deployment
snow sql -f silver/test_silver_deployment.sql

# Check Bronze layer exists
snow sql -q "SHOW SCHEMAS IN DATABASE db_ingest_pipeline;"
```

**Problem**: Streamlit app not deploying
```bash
# Check Streamlit files exist
ls -la bronze/bronze_streamlit/
ls -la silver/silver_streamlit/

# Check deployment logs
cat /tmp/streamlit_deploy.log
```

### Runtime Issues

**Problem**: Files not being discovered
```bash
# Check stage has files
snow sql -q "LIST @db_ingest_pipeline.BRONZE.SRC;"

# Refresh stage metadata
snow sql -q "ALTER STAGE db_ingest_pipeline.BRONZE.SRC REFRESH;"

# Execute discovery manually
snow sql -q "CALL db_ingest_pipeline.BRONZE.discover_files();"
```

**Problem**: Tasks not running
```bash
# Check task status
snow sql -q "SHOW TASKS IN SCHEMA db_ingest_pipeline.BRONZE;"

# Resume tasks
snow sql -q "ALTER TASK db_ingest_pipeline.BRONZE.discover_files_task RESUME;"
```

**Problem**: Processing failures
```bash
# Check error messages
snow sql -q "SELECT * FROM db_ingest_pipeline.BRONZE.file_processing_queue WHERE status = 'FAILED';"

# Check error stage
snow sql -q "LIST @db_ingest_pipeline.BRONZE.ERROR;"
```

### Diagnostic Tools

**Bronze Layer Diagnostics:**
```bash
snow sql -f bronze/diagnose_discover_files.sql
```

**Silver Layer Validation:**
```bash
snow sql -f silver/test_silver_deployment.sql
```

**Check All Components:**
```sql
-- Database and schemas
SHOW DATABASES LIKE 'db_ingest_pipeline';
SHOW SCHEMAS IN DATABASE db_ingest_pipeline;

-- Stages
SHOW STAGES IN SCHEMA db_ingest_pipeline.BRONZE;
SHOW STAGES IN SCHEMA db_ingest_pipeline.SILVER;

-- Tables
SHOW TABLES IN SCHEMA db_ingest_pipeline.BRONZE;
SHOW TABLES IN SCHEMA db_ingest_pipeline.SILVER;

-- Tasks
SHOW TASKS IN SCHEMA db_ingest_pipeline.BRONZE;
SHOW TASKS IN SCHEMA db_ingest_pipeline.SILVER;

-- Streamlit apps
SHOW STREAMLITS IN DATABASE db_ingest_pipeline;
```

## ⚠️ Known Limitations

### File Deletion in Streamlit
File deletion is **not available** in the Streamlit in Snowflake app due to Snowflake's architecture:
- Streamlit in Snowflake runs as a stored procedure
- `REMOVE` command cannot be executed from stored procedure contexts
- Even `EXECUTE AS CALLER` cannot bypass this limitation

**Workarounds:**
- Use **Snowsight UI**: Navigate to Data → Databases → Stage → Select files → Delete
- Use **SQL Worksheet**: `REMOVE @stage_name/filename.csv;`
- Use **SnowSQL CLI** or external Python scripts with Snowpark
- **Automatic Archival**: Files older than 30 days are automatically moved to archive stage

### Task History Latency
Task execution history has up to **45 minutes latency**:
- Uses `SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY` view
- `INFORMATION_SCHEMA.TASK_HISTORY()` is not accessible from Streamlit in Snowflake
- For real-time task monitoring, use Snowsight UI (Activity → Query History → Tasks)

## 📚 Additional Resources

- [Streamlit App Documentation](bronze/bronze_streamlit/README.md)
- [Streamlit Deployment Guide](bronze/bronze_streamlit/DEPLOYMENT.md)
- [Snowflake Tasks Documentation](https://docs.snowflake.com/en/user-guide/tasks-intro)
- [Snowflake CLI Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)

## 📝 Quick Reference

### Essential Commands

**Deployment:**
```bash
./deploy.sh                    # Deploy complete solution
./deploy.sh --bronze-only      # Bronze layer only
./deploy.sh --silver-only      # Silver layer only
./undeploy.sh                  # Remove everything
```

**File Upload:**
```bash
# Via CLI
snow sql -q "PUT file:///path/to/file.csv @db_ingest_pipeline.BRONZE.SRC;"

# Via Streamlit
# Open Snowsight → Streamlit → Bronze_Ingestion_Pipeline
```

**Manual Processing:**
```bash
# Discover files
snow sql -q "CALL db_ingest_pipeline.BRONZE.discover_files();"

# Process queue
snow sql -q "CALL db_ingest_pipeline.BRONZE.process_queued_files();"
```

**Task Management:**
```bash
# Resume all tasks
snow sql -q "ALTER TASK db_ingest_pipeline.BRONZE.discover_files_task RESUME;"

# Suspend all tasks
snow sql -q "ALTER TASK db_ingest_pipeline.BRONZE.discover_files_task SUSPEND;"

# Execute task manually
snow sql -q "EXECUTE TASK db_ingest_pipeline.BRONZE.discover_files_task;"
```

**Monitoring:**
```bash
# Check processing queue
snow sql -q "SELECT * FROM db_ingest_pipeline.BRONZE.file_processing_queue ORDER BY discovered_timestamp DESC LIMIT 10;"

# Check task history
snow sql -q "SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY()) WHERE DATABASE_NAME = 'DB_INGEST_PIPELINE' ORDER BY SCHEDULED_TIME DESC LIMIT 10;"

# Check data quality
snow sql -q "SELECT * FROM db_ingest_pipeline.SILVER.data_quality_metrics ORDER BY measurement_timestamp DESC LIMIT 10;"
```

### Configuration Files

**default.config** - Default settings
```bash
DATABASE_NAME="db_ingest_pipeline"
SCHEMA_NAME="BRONZE"
WAREHOUSE_NAME="COMPUTE_WH"
DISCOVER_TASK_SCHEDULE_MINUTES="60"
```

**custom.config** - Your custom settings
```bash
cp custom.config.example my.config
vim my.config
./deploy.sh my.config
```

### Project Structure

```
file_processing_pipeline/
├── deploy.sh                    # Master deployment
├── deploy_bronze.sh             # Bronze deployment
├── deploy_silver.sh             # Silver deployment
├── undeploy.sh                  # Cleanup
├── default.config               # Configuration
├── bronze/                      # Bronze layer
│   ├── *.sql                    # SQL scripts
│   └── bronze_streamlit/        # Streamlit app
├── silver/                      # Silver layer
│   ├── *.sql                    # SQL scripts
│   ├── mappings/                # CSV configs
│   └── silver_streamlit/        # Streamlit app
│       ├── streamlit_app.py
│       ├── environment.yml
│       ├── snowflake.yml
│       ├── README.md
│       └── DEPLOYMENT.md
├── docs/                        # Documentation
│   ├── architecture/            # Architecture docs
│   ├── diagrams/                # Visual diagrams
│   ├── deployment/              # Deployment guides
│   └── testing/                 # Test plans
└── sample_data/                 # Example files
```

## ❓ Frequently Asked Questions (FAQ)

### General Questions

**Q: Is this production-ready?**  
A: Yes! The pipeline includes comprehensive error handling, monitoring, audit trails, and has been tested with real-world data patterns. However, always test thoroughly in your environment before production use.

**Q: What file sizes can it handle?**  
A: Bronze layer handles files up to 100MB by default (configurable). For larger files, split them or adjust warehouse size. Silver layer processes millions of records using batch processing.

**Q: Can I use this with my existing Snowflake account?**  
A: Absolutely! The pipeline creates its own database and roles, so it won't interfere with existing objects. You can customize database names in `default.config`.

**Q: How much does it cost to run?**  
A: Costs depend on your warehouse size and usage. With X-Small warehouse and auto-suspend, expect minimal costs. Bronze processing is very efficient; Silver depends on transformation complexity.

### Bronze Layer Questions

**Q: What file formats are supported?**  
A: CSV (.csv) and Excel (.xlsx, .xls) files. The pipeline auto-detects format and uses appropriate parser.

**Q: How do I handle files with different delimiters?**  
A: The CSV parser auto-detects common delimiters (comma, semicolon, tab, pipe). For custom delimiters, modify the `process_single_csv_file()` procedure.

**Q: What happens if a file fails to process?**  
A: Failed files move to `@ERROR` stage with error details in `file_processing_queue`. Review errors, fix issues, and reprocess.

**Q: Can I reprocess files?**  
A: Yes! Update the file status to 'PENDING' in `file_processing_queue` or delete the queue entry and re-upload the file.

**Q: How do I change the discovery schedule?**  
A: Edit `DISCOVER_TASK_SCHEDULE_MINUTES` in `default.config` and redeploy, or use `ALTER TASK` to change the schedule directly.

### Silver Layer Questions

**Q: Which field mapping method should I use?**  
A: Start with **Manual CSV** for known mappings, use **ML** for auto-suggestions on similar field names, and use **LLM** for complex semantic relationships. Often a combination works best.

**Q: How accurate is the LLM mapping?**  
A: LLM mapping (using Snowflake Cortex) is highly accurate for semantic understanding but should always be reviewed. Confidence scores help prioritize review.

**Q: Can I mix mapping methods?**  
A: Yes! You can use manual mappings for critical fields, ML for bulk suggestions, and LLM for complex cases. All methods coexist in the same pipeline.

**Q: What happens to records that fail quality rules?**  
A: Depends on the rule's `error_action`:
- **REJECT**: Record is not loaded (fails batch)
- **QUARANTINE**: Record moves to `quarantine_records` table for review
- **FLAG**: Record is loaded but flagged for review
- **CORRECT**: Rule attempts to fix the issue automatically

**Q: How do I add custom transformation rules?**  
A: Insert into `transformation_rules` table or use the Streamlit UI. Rules support SQL expressions, so you can implement complex logic.

### Deployment Questions

**Q: Can I deploy Bronze and Silver separately?**  
A: Yes! Use `./deploy.sh --bronze-only` or `./deploy.sh --silver-only`. Silver requires Bronze to be deployed first.

**Q: How do I deploy to multiple environments (dev/test/prod)?**  
A: Create separate config files (e.g., `dev.config`, `prod.config`) with different database names and deploy using `./deploy.sh dev.config`.

**Q: Can I customize the database/schema names?**  
A: Yes! Edit `default.config` or create a custom config file with your preferred names.

**Q: What if deployment fails partway through?**  
A: The deployment scripts are idempotent - you can safely re-run them. Use `./undeploy.sh` to clean up and start fresh if needed.

### Troubleshooting Questions

**Q: Files aren't being discovered. What's wrong?**  
A: Check:
1. Files are in `@SRC` stage (`LIST @SRC`)
2. Task is running (`SHOW TASKS`)
3. Stage metadata is refreshed (`ALTER STAGE @SRC REFRESH`)
4. No errors in task history

**Q: Transformation is slow. How can I speed it up?**  
A: Try:
1. Increase warehouse size
2. Increase batch size (default: 10,000)
3. Optimize transformation rules
4. Use incremental processing
5. Partition large tables

**Q: How do I monitor pipeline health?**  
A: Use:
1. Streamlit apps for visual monitoring
2. `v_transformation_status_summary` view for batch status
3. `v_data_quality_dashboard` for quality metrics
4. Task history views for execution tracking

**Q: Can I get alerts for failures?**  
A: Yes! Set up Snowflake email notifications on task failures or query the error tables and integrate with your alerting system (PagerDuty, Slack, etc.).

### Integration Questions

**Q: Can this integrate with dbt?**  
A: Yes! Silver tables can be used as sources in dbt models. The Silver layer essentially replaces dbt's staging layer.

**Q: Can I use this with Snowpipe?**  
A: Yes! You can use Snowpipe to land files in `@SRC` stage, and the Bronze layer will process them. This enables near real-time ingestion.

**Q: How does this work with Snowflake Streams and Tasks?**  
A: The pipeline uses Tasks for orchestration. You could enhance it with Streams for CDC (Change Data Capture) if needed.

**Q: Can I export data to other systems?**  
A: Yes! Silver tables are standard Snowflake tables. Use `COPY INTO` to export to S3/Azure/GCS, or use Snowflake connectors for other systems.

### Advanced Questions

**Q: Can I add a Gold layer?**  
A: Absolutely! Create a new schema (GOLD) and build aggregation/business logic on top of Silver tables. Follow the same patterns used in Bronze/Silver.

**Q: How do I implement incremental loading?**  
A: Silver layer includes watermark-based incremental processing. Enable it by setting `incremental_processing=TRUE` in transformation calls.

**Q: Can I use this for streaming data?**  
A: The pipeline is batch-oriented but can handle micro-batches. For true streaming, consider Snowpipe + this pipeline or Snowflake Streams.

**Q: How do I implement slowly changing dimensions (SCD)?**  
A: Implement SCD Type 2 in Silver layer using transformation rules. Add effective dates and current flag columns to your target schemas.

**Q: Can I use this with Snowflake's Dynamic Tables?**  
A: Yes! You could replace some Silver transformation logic with Dynamic Tables for automatic incremental refresh.

---

## 📝 License

This is an example project for demonstration and learning purposes.

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with clear description

---

## 📞 Support

- **Documentation**: Start with this README and layer-specific READMEs
- **Issues**: Check existing issues or create new ones
- **Discussions**: Use GitHub Discussions for questions
- **Snowflake Community**: Ask questions in Snowflake Community forums

---

**Built with ❄️ Snowflake Native Features**

## 🎓 Learning Resources

### For Beginners
1. **Start Here**: Read this README top to bottom
2. **Quick Test**: Follow the [Sample Data Quick Start](sample_data/README.md#-quick-start-5-10-minutes) (5-10 minutes)
3. **Deploy**: Use the [Quick Deployment Guide](docs/deployment/QUICK_DEPLOYMENT_GUIDE.md)
4. **Explore**: Open the Streamlit apps and experiment

### For Developers
1. **Architecture**: Review [System Architecture](docs/architecture/ARCHITECTURE.md)
2. **Code Structure**: Check [Project Structure Analysis](docs/PROJECT_STRUCTURE_ANALYSIS.md)
3. **Bronze Layer**: Deep dive into [Bronze README](bronze/README.md)
4. **Silver Layer**: Understand [Silver README](silver/README.md)
5. **Testing**: Follow [Test Plans](docs/testing/)

### For Data Engineers
1. **Field Mapping**: Explore the three mapping methods (Manual/ML/LLM)
2. **Rules Engine**: Learn about the 5 rule types (DQ/BL/STD/DD/REF)
3. **Task Orchestration**: Understand Snowflake Tasks dependencies
4. **Performance Tuning**: Optimize batch sizes and warehouse sizing

### Video Tutorials (Coming Soon)
- Bronze Layer Deployment Walkthrough
- Silver Layer Configuration Guide
- Field Mapping Methods Comparison
- Troubleshooting Common Issues

---

*Last Updated: January 5, 2026*
