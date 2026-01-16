# Deployment and Operations Guide

**Last Updated**: January 15, 2026  
**Version**: 1.0

## 📖 Table of Contents

1. [Deployment](#deployment)
2. [Configuration](#configuration)
3. [Logging](#logging)
4. [Task Privileges](#task-privileges)
5. [Operations](#operations)
6. [Troubleshooting](#troubleshooting)

---

## Deployment

### Prerequisites

- Snowflake account with appropriate permissions
- `SYSADMIN` and `SECURITYADMIN` roles
- Access to a warehouse (default: `COMPUTE_WH`)
- **Snowflake CLI** installed and configured
- **Python** (python or python3)
- **Bash-compatible shell** (see Platform Support below)

#### Platform Support

| Platform | Shell Environment | Status |
|----------|------------------|--------|
| **macOS** | Terminal (bash/zsh) | ✅ Fully Supported |
| **Linux** | bash | ✅ Fully Supported |
| **Windows** | Git Bash | ✅ **Recommended** |
| **Windows** | WSL (Windows Subsystem for Linux) | ✅ Supported |
| **Windows** | Cygwin | ✅ Supported |
| **Windows** | Command Prompt | ❌ Not Supported |
| **Windows** | PowerShell | ❌ Not Supported |

> **Windows Users**: Install [Git for Windows](https://git-scm.com/download/win) which includes **Git Bash**.

### Deployment Scripts

| Script | Purpose | Duration | Use Case |
|--------|---------|----------|----------|
| `deploy.sh` | Complete solution | 5-12 min | **Recommended for first-time deployment** |
| `deploy.sh --bronze-only` | Bronze layer | 2-5 min | Bronze-only deployment |
| `deploy.sh --silver-only` | Silver layer | 3-7 min | Silver-only (Bronze exists) |
| `deploy_bronze.sh` | Bronze layer | 2-5 min | Direct Bronze deployment/redeployment |
| `deploy_silver.sh` | Silver layer | 3-7 min | Direct Silver deployment/redeployment |
| `undeploy.sh` | Remove all | 1-2 min | Complete cleanup |

### Deploy Complete Solution

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

### Deploy Individual Layers

**Bronze Layer Only:**
```bash
./deploy_bronze.sh

# Use custom configuration
./deploy_bronze.sh production.config
```

**Silver Layer Only:**
```bash
./deploy_silver.sh

# With custom configuration
./deploy_silver.sh custom.config
```

### Deployment Process

The deployment script will:

1. ✅ Load configuration from config file
2. ✅ Verify SYSADMIN and SECURITYADMIN permissions
3. ✅ Deploy database, roles, schemas, stages, and tables
4. ✅ Create Python and SQL stored procedures
5. ✅ Set up the task pipeline
6. ✅ Deploy Streamlit app to PUBLIC schema
7. ✅ Grant permissions to all roles

### Complete Removal (Undeploy)

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

---

## Configuration

### Configuration Files

**default.config** - Default settings used if no custom config specified

**custom.config** - Your custom settings (copy from `custom.config.example`)

### Configuration Options

Edit `default.config` or create a custom config file:

```bash
# Database Configuration
DATABASE_NAME="db_ingest_pipeline"
SCHEMA_NAME="BRONZE"
WAREHOUSE_NAME="COMPUTE_WH"

# Stage Configuration
SRC_STAGE_NAME="SRC"
COMPLETED_STAGE_NAME="COMPLETED"
ERROR_STAGE_NAME="ERROR"
ARCHIVE_STAGE_NAME="ARCHIVE"

# Task Configuration
DISCOVER_TASK_NAME="discover_files_task"
PROCESS_TASK_NAME="process_files_task"
MOVE_SUCCESS_TASK_NAME="move_successful_files_task"
MOVE_FAILED_TASK_NAME="move_failed_files_task"
ARCHIVE_TASK_NAME="archive_old_files_task"

# Task Schedules
DISCOVER_TASK_SCHEDULE_MINUTES="60"  # File discovery every 60 minutes
ARCHIVE_TASK_SCHEDULE="USING CRON 0 2 * * * UTC"  # Daily at 2 AM UTC

# Streamlit App Configuration
STREAMLIT_APP_NAME="BRONZE_INGESTION_PIPELINE"
SILVER_STREAMLIT_APP_NAME="SILVER_TRANSFORMATION_MANAGER"

# Deployment Settings
ACCEPT_DEFAULTS="true"                  # Skip prompts
USE_DEFAULT_CLI_CONNECTION="true"       # Use default connection
```

### Using Custom Configuration

```bash
# Create custom config
cp custom.config.example my.config

# Edit configuration
vim my.config

# Deploy with custom config
./deploy.sh my.config
```

### Environment-Specific Configurations

Create separate configs for different environments:

```bash
# Development
./deploy.sh dev.config

# Staging
./deploy.sh staging.config

# Production
./deploy.sh production.config
```

---

## Logging

### Automatic Log Files

All deployment activities are automatically logged:

- **Location**: `logs/` directory
- **Format**: `{layer}_deployment_{YYYYMMDD}_{HHMMSS}.log`
- **Example**: `logs/bronze_deployment_20260115_143022.log`

### Log Levels

| Level | Purpose | Example |
|-------|---------|---------|
| `INFO` | General progress | Configuration loading, role checks |
| `SUCCESS` | Successful operations | SQL execution completed |
| `WARNING` | Non-critical issues | Missing optional roles |
| `ERROR` | Critical failures | Missing required roles, SQL failures |

### What's Logged

1. **Deployment Start**
   - Timestamp
   - OS and Python version
   - Configuration file used

2. **Environment Checks**
   - Snowflake CLI availability
   - Connection count
   - Role availability (SYSADMIN, SECURITYADMIN, ACCOUNTADMIN)
   - EXECUTE TASK privilege status

3. **SQL Execution**
   - Each script execution start
   - File being executed
   - Execution duration
   - Success/failure status

4. **Deployment Completion**
   - Success/failure status
   - Total duration
   - Log file location

### Performance Tracking

- Execution time logged for each SQL script
- Total deployment duration tracked
- Helps identify slow steps

### Viewing Logs

```bash
# View latest Bronze deployment log
ls -lt logs/bronze_deployment_*.log | head -1 | xargs cat

# View latest Silver deployment log
ls -lt logs/silver_deployment_*.log | head -1 | xargs cat

# Search for errors
grep ERROR logs/*.log

# View deployment summary
tail -20 logs/bronze_deployment_*.log
```

### Log Retention

- Logs are kept indefinitely by default
- `.gitignore` excludes `*.log` files from version control
- Clean up old logs manually if needed:

```bash
# Remove logs older than 30 days
find logs/ -name "*.log" -mtime +30 -delete
```

---

## Task Privileges

### The EXECUTE TASK Privilege Issue

When deploying the Bronze layer, you may encounter this error:

```
091089 (23001): Cannot execute task, EXECUTE TASK privilege must be granted to owner role
```

### Why This Happens

The `EXECUTE TASK` privilege is a global account-level privilege that can only be granted by ACCOUNTADMIN. Tasks cannot be created or executed without this privilege.

### Quick Fix

Run this as ACCOUNTADMIN (one-time setup):

```bash
snow sql -f bronze/Fix_Task_Privileges.sql
```

Then resume your tasks:

```sql
USE ROLE db_ingest_pipeline_ADMIN;
USE DATABASE db_ingest_pipeline;
USE SCHEMA BRONZE;

ALTER TASK move_failed_files_task RESUME;
ALTER TASK move_successful_files_task RESUME;
ALTER TASK process_files_task RESUME;
ALTER TASK discover_files_task RESUME;
ALTER TASK archive_old_files_task RESUME;
```

### Solution Strategy

We use a **delegation model** to minimize ACCOUNTADMIN requirements:

```
ACCOUNTADMIN (one-time)
    ↓ WITH GRANT OPTION
SYSADMIN (can delegate to other roles)
    ↓
db_ingest_pipeline_ADMIN (project role)
```

**Benefits**:
- ✅ ACCOUNTADMIN only needed once for initial setup
- ✅ SYSADMIN can handle all future deployments
- ✅ Project roles can create and manage tasks independently
- ✅ Follows Snowflake security best practices

### Verification

Check if the privilege is granted:

```sql
-- Check SYSADMIN has EXECUTE TASK
SHOW GRANTS TO ROLE SYSADMIN;

-- Check project role has EXECUTE TASK
SHOW GRANTS TO ROLE db_ingest_pipeline_ADMIN;

-- Check if you can execute tasks
SHOW TASKS IN SCHEMA db_ingest_pipeline.BRONZE;
```

### Alternative: Grant Directly

If you don't want to use the delegation model:

```sql
-- As ACCOUNTADMIN, grant directly to project role
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE db_ingest_pipeline_ADMIN;
```

---

## Operations

### Start Pipeline

```sql
-- Resume all tasks (in reverse dependency order)
ALTER TASK move_failed_files_task RESUME;
ALTER TASK move_successful_files_task RESUME;
ALTER TASK process_files_task RESUME;
ALTER TASK discover_files_task RESUME;
ALTER TASK archive_old_files_task RESUME;  -- Independent task
```

Or use the helper procedure:

```sql
CALL DB_INGEST_PIPELINE.BRONZE.resume_all_tasks();
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

Or use the helper procedure:

```sql
CALL DB_INGEST_PIPELINE.BRONZE.suspend_all_tasks();
```

### Execute Task Manually

```sql
-- Process files immediately without waiting for schedule
EXECUTE TASK discover_files_task;

-- Manually trigger archival
EXECUTE TASK archive_old_files_task;
```

### Monitor Task Execution

```sql
-- View task execution history (last 7 days)
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

### Check Processing Queue

```sql
-- View processing status summary
SELECT 
    status,
    file_type,
    COUNT(*) AS file_count,
    SUM(CASE WHEN error_message IS NOT NULL THEN 1 ELSE 0 END) AS errors
FROM file_processing_queue
GROUP BY status, file_type
ORDER BY status;
```

### View Stage Files

```sql
-- Count files in each stage
SELECT 'SRC' AS stage, COUNT(*) AS file_count FROM DIRECTORY(@SRC)
UNION ALL
SELECT 'COMPLETED', COUNT(*) FROM DIRECTORY(@COMPLETED)
UNION ALL
SELECT 'ERROR', COUNT(*) FROM DIRECTORY(@ERROR)
UNION ALL
SELECT 'ARCHIVE', COUNT(*) FROM DIRECTORY(@ARCHIVE);
```

### Upload Files

**Via CLI:**
```bash
snow sql -q "PUT file:///path/to/file.csv @DB_INGEST_PIPELINE.BRONZE.SRC/provider_a/;"
```

**Via Streamlit:**
1. Open Snowsight → Streamlit → BRONZE_INGESTION_PIPELINE
2. Go to "📤 Upload Files" tab
3. Select TPA
4. Drag and drop files

### Process Files Manually

```bash
# Discover files
snow sql -q "CALL DB_INGEST_PIPELINE.BRONZE.discover_files();"

# Process queue
snow sql -q "CALL DB_INGEST_PIPELINE.BRONZE.process_queued_files();"
```

### Change Task Schedule

```sql
-- Change discovery frequency to every 30 minutes
ALTER TASK discover_files_task SET SCHEDULE = '30 MINUTE';

-- Change to specific time (daily at 3 AM)
ALTER TASK discover_files_task SET SCHEDULE = 'USING CRON 0 3 * * * UTC';

-- Resume task after schedule change
ALTER TASK discover_files_task RESUME;
```

---

## Troubleshooting

### Platform-Specific Issues

#### Windows: Script Won't Run

**Symptom:** Deployment script fails with syntax errors or "command not found"

**Cause:** Using Command Prompt or PowerShell instead of Git Bash

**Solution:**
1. Install [Git for Windows](https://git-scm.com/download/win) if not already installed
2. Open **Git Bash** (not Command Prompt or PowerShell)
3. Navigate to the project directory: `cd /c/path/to/file_processing_pipeline`
4. Run the deployment script: `./deploy.sh`

#### Windows: Character Encoding Error

**Symptom:** `'charmap' codec can't decode byte 0x90` or similar encoding errors during deployment

**Cause:** SQL files contain Unicode box-drawing characters that Windows Python can't decode with the default charmap encoding

**Solution:**
The deployment scripts now **automatically** handle this on Windows by creating temporary ASCII-safe versions of the SQL files. Simply run the deployment normally:

```bash
./deploy.sh
```

The scripts detect Windows and automatically convert Unicode characters to ASCII equivalents before execution.

#### Windows: Line Ending Issues

**Symptom:** Scripts fail with `^M: bad interpreter` or similar errors

**Cause:** Files have Windows line endings (CRLF) instead of Unix line endings (LF)

**Solution:**
```bash
# In Git Bash, convert line endings
dos2unix deploy.sh deploy_bronze.sh deploy_silver.sh

# Or configure git to handle line endings automatically
git config --global core.autocrlf input
```

#### Permission Denied

**Symptom:** "Permission denied" when running scripts

**Solution:**
```bash
# Make scripts executable
chmod +x deploy.sh deploy_bronze.sh deploy_silver.sh undeploy.sh
```

### Deployment Issues

#### Problem: Bronze deployment fails

**Solution:**
```bash
# Run diagnostics
snow sql -f bronze/diagnose_discover_files.sql

# Check permissions
snow sql -q "SHOW GRANTS TO USER CURRENT_USER();"
```

#### Problem: Silver deployment fails

**Solution:**
```bash
# Validate deployment
snow sql -f silver/test_silver_deployment.sql

# Check Bronze layer exists
snow sql -q "SHOW SCHEMAS IN DATABASE db_ingest_pipeline;"
```

#### Problem: Streamlit app not deploying

**Solution:**
```bash
# Check Streamlit files exist
ls -la bronze/bronze_streamlit/
ls -la silver/silver_streamlit/

# Check deployment logs
cat logs/bronze_deployment_*.log | grep -i streamlit
```

### Runtime Issues

#### Problem: Files not being discovered

**Solution:**
```bash
# Check stage has files
snow sql -q "LIST @db_ingest_pipeline.BRONZE.SRC;"

# Refresh stage metadata
snow sql -q "ALTER STAGE db_ingest_pipeline.BRONZE.SRC REFRESH;"

# Execute discovery manually
snow sql -q "CALL db_ingest_pipeline.BRONZE.discover_files();"
```

#### Problem: Tasks not running

**Solution:**
```bash
# Check task status
snow sql -q "SHOW TASKS IN SCHEMA db_ingest_pipeline.BRONZE;"

# Resume tasks
snow sql -q "CALL db_ingest_pipeline.BRONZE.resume_all_tasks();"
```

#### Problem: Processing failures

**Solution:**
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

---

## Related Documentation

- **[Main README](../README.md)** - Project overview
- **[Quick Start](../QUICK_START.md)** - 10-minute quick start guide
- **[User Guide](USER_GUIDE.md)** - Complete user guide
- **[Architecture](design/ARCHITECTURE.md)** - System architecture
- **[Bronze Layer](../bronze/README.md)** - Bronze layer documentation
- **[Silver Layer](../silver/README.md)** - Silver layer documentation

---

**Version**: 1.0  
**Last Updated**: January 15, 2026  
**Status**: ✅ Complete

**Consolidated from:**
- `LOGGING_IMPLEMENTATION.md`
- `bronze/TASK_PRIVILEGE_FIX.md`
- Deployment sections from `README.md`
- Deployment sections from `QUICK_START.md`
