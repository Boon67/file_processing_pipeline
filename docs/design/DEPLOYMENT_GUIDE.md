# Deployment Guide

## Snowflake File Processing Pipeline

**Version:** 1.0  
**Date:** January 2026  
**Audience:** DevOps, Data Engineers, System Administrators

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Deployment Process](#deployment-process)
4. [Post-Deployment Verification](#post-deployment-verification)
5. [Configuration Management](#configuration-management)
6. [Rollback Procedures](#rollback-procedures)
7. [Troubleshooting](#troubleshooting)
8. [Platform-Specific Instructions](#platform-specific-instructions)

---

## Prerequisites

### Snowflake Requirements

**Account Access**:
- Snowflake account (any edition)
- Account URL (e.g., `myorg-myaccount.snowflakecomputing.com`)
- Valid credentials (username/password or key-pair)

**Required Roles**:
- `SYSADMIN`: For creating databases, schemas, tables, stages, tasks
- `SECURITYADMIN`: For creating and managing custom roles

**Required Privileges**:
```sql
-- Check your current roles
SHOW GRANTS TO USER CURRENT_USER();

-- Required grants
GRANT ROLE SYSADMIN TO USER <your_username>;
GRANT ROLE SECURITYADMIN TO USER <your_username>;
```

**Warehouse Access**:
- Access to an existing warehouse (e.g., `COMPUTE_WH`)
- OR ability to create a new warehouse

### Local Environment

**Required Software**:

| Software | Version | Purpose | Installation |
|----------|---------|---------|--------------|
| Snowflake CLI | Latest | Deployment tool | `pip install snowflake-cli-labs` |
| Python | 3.8+ | Script execution | https://python.org |
| Bash | 4.0+ | Shell scripts | Pre-installed (macOS/Linux) |
| Git | 2.0+ | Version control | https://git-scm.com |

**Platform-Specific Requirements**:

**macOS**:
- Terminal (built-in)
- Python 3 (via Homebrew: `brew install python3`)

**Linux**:
- Bash shell (built-in)
- Python 3 (via package manager: `apt install python3` or `yum install python3`)

**Windows**:
- Git Bash (from Git for Windows: https://git-scm.com/download/win)
- Python 3 (from python.org)
- **Important**: Use Git Bash, NOT Command Prompt or PowerShell

### Network Requirements

**Outbound Connectivity**:
- HTTPS (443) to Snowflake account
- HTTPS (443) to PyPI (for pip installs)

**Firewall Rules**:
- Allow outbound to `*.snowflakecomputing.com`
- Allow outbound to `pypi.org`

---

## Pre-Deployment Checklist

### 1. Environment Setup

- [ ] **Snowflake CLI Installed**
  ```bash
  snow --version
  # Expected: snowflake-cli version X.X.X
  ```

- [ ] **Snowflake Connection Configured**
  ```bash
  snow connection add
  # Follow prompts to configure connection
  
  snow connection test
  # Expected: Connection test passed
  ```

- [ ] **Python Installed**
  ```bash
  python --version  # or python3 --version
  # Expected: Python 3.8 or higher
  ```

- [ ] **Git Installed**
  ```bash
  git --version
  # Expected: git version 2.x.x
  ```

### 2. Snowflake Account Verification

- [ ] **Role Access Verified**
  ```sql
  -- Run in Snowsight or SnowSQL
  USE ROLE SYSADMIN;
  SELECT 'SYSADMIN access confirmed' AS status;
  
  USE ROLE SECURITYADMIN;
  SELECT 'SECURITYADMIN access confirmed' AS status;
  ```

- [ ] **Warehouse Access Verified**
  ```sql
  USE WAREHOUSE COMPUTE_WH;  -- or your warehouse name
  SELECT 'Warehouse access confirmed' AS status;
  ```

### 3. Code Repository

- [ ] **Repository Cloned**
  ```bash
  git clone <repository-url>
  cd file_processing_pipeline
  ```

- [ ] **Scripts Executable**
  ```bash
  chmod +x deploy.sh deploy_bronze.sh deploy_silver.sh undeploy.sh
  ```

- [ ] **Configuration File Ready**
  ```bash
  # Option 1: Use defaults
  ls -la default.config
  
  # Option 2: Create custom config
  cp custom.config.example custom.config
  # Edit custom.config with your settings
  ```

### 4. Environment-Specific Configuration

- [ ] **Database Name Decided**
  - Development: `dev_ingest_pipeline`
  - Staging: `stg_ingest_pipeline`
  - Production: `prod_ingest_pipeline`

- [ ] **Warehouse Selected**
  - Development: X-Small or Small
  - Production: Small or Medium

- [ ] **Task Schedules Configured**
  - Development: Longer intervals (e.g., 120 min)
  - Production: Standard intervals (e.g., 60 min)

---

## Deployment Process

### Option 1: Full Stack Deployment (Recommended)

Deploy both Bronze and Silver layers in one command:

```bash
# Using default configuration
./deploy.sh

# Using custom configuration
./deploy.sh custom.config

# Using environment-specific configuration
./deploy.sh prod.config
```

**Expected Output**:
```
╔════════════════════════════════════════════════════════════════╗
║   Snowflake File Processing Pipeline - Master Deployment       ║
╚════════════════════════════════════════════════════════════════╝

Configuration: default.config
Deployment Mode: Full Stack (Bronze + Silver)

╔════════════════════════════════════════════════════════════════╗
║   🥉 BRONZE LAYER - File Ingestion Pipeline                    ║
╚════════════════════════════════════════════════════════════════╝

Step 1: Setting up Snowflake connection
✓ Connected to Snowflake

Step 2: Verifying required roles
✓ SYSADMIN role: Available
✓ SECURITYADMIN role: Available

Step 3: Executing Bronze layer deployment
✓ Database and roles created
✓ Stages configured
✓ Tables created
✓ Stored procedures deployed
✓ Tasks created
✓ Streamlit app deployed

╔════════════════════════════════════════════════════════════════╗
║   🥈 SILVER LAYER - Data Transformation Pipeline               ║
╚════════════════════════════════════════════════════════════════╝

[Similar output for Silver layer]

╔════════════════════════════════════════════════════════════════╗
║   🎉 DEPLOYMENT SUMMARY                                         ║
╚════════════════════════════════════════════════════════════════╝

✓ Bronze Layer: DEPLOYED
✓ Silver Layer: DEPLOYED

Overall Status: SUCCESS
Deployment Time: 5m 23s
```

### Option 2: Layer-Specific Deployment

Deploy only Bronze or Silver layer:

```bash
# Bronze layer only
./deploy.sh --bronze-only

# Silver layer only (requires Bronze to be deployed first)
./deploy.sh --silver-only
```

### Option 3: Manual Deployment

Deploy using individual scripts:

```bash
# Deploy Bronze layer
./deploy_bronze.sh default.config

# Deploy Silver layer
./deploy_silver.sh default.config
```

### Deployment Steps Breakdown

#### Bronze Layer Deployment

**Step 1: Database and RBAC Setup** (1_Setup_Database_Roles.sql)
- Creates database: `DB_INGEST_PIPELINE`
- Creates custom roles:
  - `DB_INGEST_PIPELINE_ADMIN`
  - `DB_INGEST_PIPELINE_READWRITE`
  - `DB_INGEST_PIPELINE_READONLY`
- Grants role hierarchy
- Grants permissions

**Step 2: Schema, Stages, and Tables** (2_Bronze_Schema_Tables.sql)
- Creates BRONZE schema
- Creates 6 stages (SRC, COMPLETED, ERROR, ARCHIVE, STREAMLIT_STAGE, CONFIG_STAGE)
- Creates 2 tables (RAW_DATA_TABLE, FILE_PROCESSING_QUEUE)
- Grants permissions to roles

**Step 3: File Processing Stored Procedures** (3_Bronze_Setup_Logic.sql)
- Creates 4+ stored procedures:
  - `discover_files()`
  - `process_queued_files()`
  - `move_files_to_stage()`
  - `archive_old_files()`
- Grants USAGE to roles

**Step 4: Task Pipeline Creation** (4_Bronze_Tasks.sql)
- Creates 5 tasks:
  - `discover_files_task` (ROOT, scheduled)
  - `process_files_task` (CHILD)
  - `move_successful_files_task` (CHILD)
  - `move_failed_files_task` (CHILD)
  - `archive_old_files_task` (ROOT, scheduled)
- Tasks created in SUSPENDED state

**Step 5: Streamlit App Deployment**
- Uploads Streamlit app files to stage
- Deploys Bronze Ingestion Pipeline app
- Grants access to admin role

#### Silver Layer Deployment

**Step 1: Silver Schema Setup** (1_Silver_Schema_Setup.sql)
- Creates SILVER schema
- Creates 3 stages (SILVER_STAGE, SILVER_CONFIG, SILVER_STREAMLIT)
- Creates 8 metadata tables
- Grants permissions

**Step 2: Target Schemas** (2_Silver_Target_Schemas.sql)
- Creates target schema management procedures
- Loads sample target schemas from CSV
- Creates example CLAIMS table

**Step 3: Mapping Procedures** (3_Silver_Mapping_Procedures.sql)
- Creates field mapping procedures:
  - Manual mapping
  - ML-based mapping (exact, fuzzy, TF-IDF)
  - LLM-based mapping (Cortex AI)
- Loads sample mappings from CSV

**Step 4: Rules Engine** (4_Silver_Rules_Engine.sql)
- Creates transformation rules engine
- Creates quality validation procedures
- Loads sample rules from CSV

**Step 5: Transformation Logic** (5_Silver_Transformation_Logic.sql)
- Creates main transformation procedure
- Creates batch processing logic
- Creates watermark management

**Step 6: Silver Tasks** (6_Silver_Tasks.sql)
- Creates 6 tasks:
  - `bronze_completion_sensor` (ROOT, scheduled)
  - `silver_discovery_task` (CHILD)
  - `silver_transformation_task` (CHILD)
  - `silver_quality_check_task` (CHILD)
  - `silver_publish_task` (CHILD)
  - `silver_quarantine_task` (CHILD)

**Step 7: Streamlit App Deployment**
- Uploads Silver Streamlit app
- Deploys Silver Transformation Manager
- Grants access to admin role

---

## Post-Deployment Verification

### Automated Verification

Run the quick deployment check:

```bash
snow sql -f silver/quick_deployment_check.sql
```

**Expected Output**:
```
✓ PASS: 14 metadata tables exist
✓ PASS: 1 target tables defined
✓ PASS: CLAIMS defined with 27 columns
✓ PASS: 29 field mappings configured
✓ PASS: 34 procedures deployed
✓ PASS: 11 tasks created
✓ PASS: 2 Streamlit apps deployed

Overall Status: PASS
```

### Manual Verification

#### 1. Verify Database and Roles

```sql
-- Check database
SHOW DATABASES LIKE 'DB_INGEST_PIPELINE';

-- Check roles
SHOW ROLES LIKE 'DB_INGEST_PIPELINE%';

-- Check role hierarchy
SHOW GRANTS TO ROLE DB_INGEST_PIPELINE_ADMIN;
```

#### 2. Verify Bronze Layer

```sql
USE DATABASE DB_INGEST_PIPELINE;
USE SCHEMA BRONZE;

-- Check tables
SHOW TABLES;
-- Expected: RAW_DATA_TABLE, FILE_PROCESSING_QUEUE

-- Check stages
SHOW STAGES;
-- Expected: SRC, COMPLETED, ERROR, ARCHIVE, STREAMLIT_STAGE, CONFIG_STAGE

-- Check procedures
SHOW PROCEDURES;
-- Expected: discover_files, process_queued_files, move_files_to_stage, archive_old_files

-- Check tasks
SHOW TASKS;
-- Expected: 5 tasks (all in SUSPENDED state)

-- Check task dependencies
SELECT 
    name,
    state,
    schedule,
    predecessors
FROM TABLE(INFORMATION_SCHEMA.TASK_DEPENDENTS(
    TASK_NAME => 'DB_INGEST_PIPELINE.BRONZE.DISCOVER_FILES_TASK',
    RECURSIVE => TRUE
));
```

#### 3. Verify Silver Layer

```sql
USE SCHEMA SILVER;

-- Check metadata tables
SHOW TABLES;
-- Expected: 8+ metadata tables

-- Check target tables
SELECT table_name, COUNT(*) as column_count
FROM target_schemas
GROUP BY table_name;
-- Expected: At least CLAIMS table

-- Check field mappings
SELECT COUNT(*) as mapping_count FROM field_mappings;
-- Expected: > 0

-- Check transformation rules
SELECT COUNT(*) as rule_count FROM transformation_rules WHERE active = TRUE;
-- Expected: > 0

-- Check procedures
SHOW PROCEDURES;
-- Expected: 34+ procedures

-- Check tasks
SHOW TASKS;
-- Expected: 6 tasks
```

#### 4. Verify Streamlit Apps

```sql
-- Check Streamlit apps
SHOW STREAMLITS IN DATABASE DB_INGEST_PIPELINE;
-- Expected: BRONZE_INGESTION_PIPELINE, SILVER_TRANSFORMATION_MANAGER
```

**Access Streamlit Apps**:
1. Log into Snowsight
2. Navigate to: Projects → Streamlit
3. Verify both apps are listed
4. Click to open and verify they load

### Performance Verification

#### Test File Processing

```sql
-- Upload a test file to @SRC stage
PUT file:///path/to/test.csv @DB_INGEST_PIPELINE.BRONZE.SRC;

-- Manually trigger discovery
CALL DB_INGEST_PIPELINE.BRONZE.discover_files();

-- Check queue
SELECT * FROM DB_INGEST_PIPELINE.BRONZE.FILE_PROCESSING_QUEUE;

-- Manually trigger processing
CALL DB_INGEST_PIPELINE.BRONZE.process_queued_files(1);

-- Verify data loaded
SELECT COUNT(*) FROM DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE;
```

#### Test Task Execution

```sql
-- Resume root task
ALTER TASK DB_INGEST_PIPELINE.BRONZE.DISCOVER_FILES_TASK RESUME;

-- Wait 1-2 minutes, then check task history
SELECT 
    name,
    state,
    scheduled_time,
    completed_time,
    DATEDIFF('second', scheduled_time, completed_time) as duration_seconds
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'DB_INGEST_PIPELINE.BRONZE.DISCOVER_FILES_TASK',
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY scheduled_time DESC
LIMIT 10;

-- Suspend task after testing
ALTER TASK DB_INGEST_PIPELINE.BRONZE.DISCOVER_FILES_TASK SUSPEND;
```

---

## Configuration Management

### Configuration Files

**default.config**: Default values for all environments
```bash
DATABASE_NAME="db_ingest_pipeline"
WAREHOUSE_NAME="COMPUTE_WH"
DISCOVER_TASK_SCHEDULE_MINUTES="60"
```

**Environment-Specific Configs**:

**dev.config**: Development environment
```bash
DATABASE_NAME="dev_ingest_pipeline"
WAREHOUSE_NAME="DEV_WH"
DISCOVER_TASK_SCHEDULE_MINUTES="120"  # Less frequent
```

**prod.config**: Production environment
```bash
DATABASE_NAME="prod_ingest_pipeline"
WAREHOUSE_NAME="PROD_WH"
DISCOVER_TASK_SCHEDULE_MINUTES="30"  # More frequent
```

### Configuration Parameters

| Parameter | Description | Default | Recommended Values |
|-----------|-------------|---------|-------------------|
| DATABASE_NAME | Database name | db_ingest_pipeline | env_ingest_pipeline |
| SCHEMA_NAME | Bronze schema | BRONZE | BRONZE |
| WAREHOUSE_NAME | Compute warehouse | COMPUTE_WH | Size based on load |
| SRC_STAGE_NAME | Source stage | SRC | SRC |
| DISCOVER_TASK_SCHEDULE_MINUTES | Discovery frequency | 60 | 30-120 |
| SILVER_SCHEMA_NAME | Silver schema | SILVER | SILVER |
| DEFAULT_BATCH_SIZE | Records per batch | 10000 | 5000-50000 |
| DEFAULT_LLM_MODEL | Cortex model | snowflake-arctic | See docs |

---

## Rollback Procedures

### Complete Rollback

Remove all deployed objects:

```bash
./undeploy.sh
```

**Warning**: This will permanently delete:
- Database and all data
- All stages and files
- Custom roles
- Streamlit applications

**Confirmation Required**:
1. Type 'yes' to confirm
2. Type database name to double-confirm

### Partial Rollback

#### Rollback Silver Layer Only

```sql
USE ROLE SYSADMIN;
USE DATABASE DB_INGEST_PIPELINE;

-- Suspend Silver tasks
ALTER TASK SILVER.BRONZE_COMPLETION_SENSOR SUSPEND;

-- Drop Silver schema
DROP SCHEMA SILVER CASCADE;

-- Redeploy if needed
```

#### Rollback Specific Component

```sql
-- Rollback a specific procedure
DROP PROCEDURE IF EXISTS BRONZE.process_queued_files(INTEGER);

-- Redeploy from SQL file
-- Run specific SQL script
```

### Emergency Rollback

If deployment fails mid-process:

```bash
# 1. Check what was created
snow sql -q "SHOW DATABASES LIKE 'DB_INGEST_PIPELINE';"

# 2. If database exists, run undeploy
./undeploy.sh

# 3. If undeploy fails, manual cleanup
snow sql -q "DROP DATABASE IF EXISTS DB_INGEST_PIPELINE;"
snow sql -q "DROP ROLE IF EXISTS DB_INGEST_PIPELINE_ADMIN;"
snow sql -q "DROP ROLE IF EXISTS DB_INGEST_PIPELINE_READWRITE;"
snow sql -q "DROP ROLE IF EXISTS DB_INGEST_PIPELINE_READONLY;"
```

---

## Troubleshooting

### Common Issues

#### Issue 1: "Snowflake CLI not found"

**Symptoms**:
```
ERROR: Snowflake CLI (snow) is not installed or not in PATH
```

**Solution**:
```bash
# Install Snowflake CLI
pip install snowflake-cli-labs

# Verify installation
snow --version

# If still not found, check PATH
echo $PATH
which snow
```

#### Issue 2: "Missing required roles"

**Symptoms**:
```
✗ SYSADMIN role: NOT Available
✗ SECURITYADMIN role: NOT Available
```

**Solution**:
```sql
-- Have your Snowflake administrator run:
GRANT ROLE SYSADMIN TO USER <your_username>;
GRANT ROLE SECURITYADMIN TO USER <your_username>;
```

#### Issue 3: "Database already exists"

**Symptoms**:
```
SQL compilation error: Database 'DB_INGEST_PIPELINE' already exists
```

**Solution**:
```bash
# Option 1: Undeploy first
./undeploy.sh

# Option 2: Use different database name
cp default.config custom.config
# Edit DATABASE_NAME in custom.config
./deploy.sh custom.config
```

#### Issue 4: "Warehouse does not exist"

**Symptoms**:
```
Object does not exist, or operation cannot be performed: COMPUTE_WH
```

**Solution**:
```sql
-- Create warehouse
CREATE WAREHOUSE COMPUTE_WH WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;

-- Or use existing warehouse in config
```

#### Issue 5: Windows Path Issues

**Symptoms**:
```
File doesn't exist: ['/c/users/...']
```

**Solution**:
- Ensure you're using Git Bash (not Command Prompt)
- Scripts automatically convert paths
- If issue persists, check `convert_path_for_snowflake()` function

#### Issue 6: Character Encoding Errors (Windows)

**Symptoms**:
```
'charmap' codec can't decode byte 0x90
```

**Solution**:
- Scripts automatically handle UTF-8 encoding
- Ensure Git line endings: `git config --global core.autocrlf input`
- Restart Git Bash after configuration changes

### Debug Mode

Enable verbose output:

```bash
# Run with bash debug mode
bash -x ./deploy.sh

# Check specific SQL file
snow sql -f bronze/1_Setup_Database_Roles.sql --debug
```

### Log Files

Check deployment logs:

```bash
# Terminal output (if redirected)
cat deployment.log

# Snowflake query history
# In Snowsight: Activity → Query History
```

---

## Platform-Specific Instructions

### macOS

**Prerequisites**:
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python
brew install python3

# Install Snowflake CLI
pip3 install snowflake-cli-labs
```

**Deployment**:
```bash
cd /path/to/file_processing_pipeline
chmod +x *.sh
./deploy.sh
```

### Linux

**Prerequisites**:
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install python3 python3-pip git

# CentOS/RHEL
sudo yum install python3 python3-pip git

# Install Snowflake CLI
pip3 install snowflake-cli-labs
```

**Deployment**:
```bash
cd /path/to/file_processing_pipeline
chmod +x *.sh
./deploy.sh
```

### Windows (Git Bash)

**Prerequisites**:
1. Install Git for Windows: https://git-scm.com/download/win
2. Install Python: https://www.python.org/downloads/
3. Open Git Bash (not Command Prompt!)

```bash
# Install Snowflake CLI
pip install snowflake-cli-labs

# Configure Git line endings
git config --global core.autocrlf input
```

**Deployment**:
```bash
cd /c/Users/YourName/file_processing_pipeline
chmod +x *.sh
./deploy.sh
```

**Important Notes**:
- Always use Git Bash, never Command Prompt or PowerShell
- Scripts automatically handle Windows path conversion
- Scripts automatically handle UTF-8 encoding issues

---

## Best Practices

### Pre-Production Checklist

- [ ] Test deployment in development environment
- [ ] Review all configuration parameters
- [ ] Verify role permissions
- [ ] Test with sample data
- [ ] Review task schedules for production load
- [ ] Plan maintenance windows
- [ ] Document environment-specific settings
- [ ] Create rollback plan
- [ ] Notify stakeholders

### Post-Deployment Tasks

- [ ] Resume tasks (they deploy in SUSPENDED state)
- [ ] Upload initial data files
- [ ] Configure Streamlit app access
- [ ] Set up monitoring alerts
- [ ] Document custom configurations
- [ ] Train end users
- [ ] Schedule regular reviews

### Maintenance

**Weekly**:
- Review task execution history
- Check processing queue for backlogs
- Monitor warehouse usage

**Monthly**:
- Review data quality metrics
- Optimize warehouse sizing
- Archive old logs

**Quarterly**:
- Review and update field mappings
- Review and update transformation rules
- Test disaster recovery procedures
- Update documentation

---

**Document Status**: APPROVED  
**Version**: 1.0  
**Last Updated**: 2026-01-14  
**Next Review**: 2026-04-14
