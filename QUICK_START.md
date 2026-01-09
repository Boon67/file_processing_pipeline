# Quick Start Guide

Get the Snowflake File Processing Pipeline up and running in under 10 minutes.

## Prerequisites

- Snowflake account with ACCOUNTADMIN privileges
- Snowflake CLI installed (`snow`)
- Python 3.8+ (for diagram generation, optional)

## 1. Configure Connection

Set up your Snowflake CLI connection:

```bash
snow connection add

# Or test existing connection
snow connection test
```

## 2. Configure Deployment

Copy and edit the configuration file:

```bash
cp custom.config.example custom.config
# Edit custom.config with your settings
```

**Minimum required settings:**
```bash
DATABASE_NAME="your_database_name"
WAREHOUSE_NAME="your_warehouse"
```

## 3. Deploy

Deploy both Bronze and Silver layers:

```bash
./deploy.sh
```

Or deploy individually:

```bash
# Bronze layer only
./deploy_bronze.sh

# Silver layer only
./deploy_silver.sh
```

**Deployment creates:**
- Database and roles
- Bronze schema (4 tables, 5 tasks, Streamlit app)
- Silver schema (8+ tables, 34 procedures, Streamlit app)
- Sample configurations

## 4. Verify Deployment

```bash
# Quick verification
snow sql -f silver/quick_deployment_check.sql

# Detailed verification
snow sql -f silver/verify_silver_deployment.sql
```

**Expected output:**
```
✓ PASS: 14 metadata tables exist
✓ PASS: 1 target tables defined
✓ PASS: CLAIMS defined with 27 columns
✓ PASS: 29 field mappings configured
✓ PASS: 34 procedures deployed
```

## 5. Access Streamlit Apps

1. Log into Snowsight
2. Navigate to **Streamlit** in the left sidebar
3. Open the apps:
   - **BRONZE_INGESTION_PIPELINE** - File upload and monitoring
   - **SILVER_TRANSFORMATION_MANAGER** - Data transformation

## 6. Upload Sample Data

**Option A: Via Streamlit**
1. Open Bronze Ingestion Pipeline app
2. Go to "📤 Upload Files" tab
3. Drag and drop files from `sample_data/claims_data/`

**Option B: Via CLI**
```bash
snow sql -q "PUT file://sample_data/claims_data/*.csv @DB_INGEST_PIPELINE.BRONZE.SRC;"
```

## 7. Process Files

**Automatic (Recommended):**
```sql
-- Resume tasks for automated processing
CALL DB_INGEST_PIPELINE.BRONZE.resume_all_tasks();
```

**Manual:**
1. In Bronze app, go to "⚙️ Task Management"
2. Click "Execute Now" on `discover_files_task`
3. Monitor progress in "📊 Processing Status"

## 8. Transform to Silver

**Via Streamlit:**
1. Open Silver Transformation Manager
2. Go to "📊 Transformation Monitor"
3. Select **CLAIMS** table
4. Set batch size: 10000
5. Check "Apply Rules" ✓
6. Click "Run Transformation"

**Via SQL:**
```sql
USE DATABASE DB_INGEST_PIPELINE;
USE SCHEMA SILVER;

CALL transform_bronze_to_silver(
    'RAW_DATA_TABLE',  -- source
    'CLAIMS',          -- target
    'BRONZE',          -- bronze schema
    10000,             -- batch size
    TRUE,              -- apply rules
    TRUE               -- incremental
);
```

## 9. View Results

```sql
-- Check Bronze data
SELECT COUNT(*) FROM DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE;

-- Check Silver data
SELECT COUNT(*) FROM DB_INGEST_PIPELINE.SILVER.CLAIMS;

-- View sample records
SELECT * FROM DB_INGEST_PIPELINE.SILVER.CLAIMS LIMIT 10;
```

## Common Issues

### Issue: Tasks not running

**Solution:**
```sql
-- Check task status
SHOW TASKS IN SCHEMA DB_INGEST_PIPELINE.BRONZE;

-- Resume tasks
CALL DB_INGEST_PIPELINE.BRONZE.resume_all_tasks();
```

### Issue: Transformation fails

**Solution:**
```sql
-- Check field mappings
SELECT * FROM DB_INGEST_PIPELINE.SILVER.field_mappings 
WHERE target_table = 'CLAIMS';

-- Verify Bronze data structure
SELECT RAW_DATA FROM DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE LIMIT 1;
```

### Issue: Streamlit app not found

**Solution:**
```bash
# Redeploy Streamlit apps
./redeploy_silver_streamlit.sh

# Or check deployment logs
cat deploy_silver.log
```

## Next Steps

- **Configure Additional Tables**: Use Target Table Designer in Streamlit
- **Set Up Field Mappings**: Use Field Mapper (Manual/ML/LLM methods)
- **Define Quality Rules**: Use Rules Engine for data validation
- **Monitor Processing**: Check Transformation Monitor for metrics
- **Enable Automation**: Resume tasks for scheduled processing

## Documentation

- **Main README**: [README.md](README.md) - Complete documentation
- **User Guide**: [docs/USER_GUIDE.md](docs/USER_GUIDE.md) - Detailed usage guide
- **Architecture**: [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md)
- **Bronze Layer**: [bronze/README.md](bronze/README.md)
- **Silver Layer**: [silver/README.md](silver/README.md)
- **Deployment Verification**: [silver/DEPLOYMENT_VERIFICATION.md](silver/DEPLOYMENT_VERIFICATION.md)

## Support

For detailed troubleshooting and advanced configuration, see the full documentation in [README.md](README.md).

