# Deployment Checklist

Use this checklist to ensure successful deployment and configuration of the Snowflake File Processing Pipeline.

## Pre-Deployment

- [ ] **Snowflake CLI installed** and configured
  ```bash
  snow --version
  snow connection test
  ```

- [ ] **ACCOUNTADMIN privileges** or equivalent permissions
  - Can create databases
  - Can create roles
  - Can create warehouses
  - Can deploy Streamlit apps

- [ ] **Configuration file created**
  ```bash
  cp custom.config.example custom.config
  # Edit custom.config
  ```

- [ ] **Required settings configured**:
  - [ ] `DATABASE_NAME`
  - [ ] `WAREHOUSE_NAME`
  - [ ] `BRONZE_SCHEMA_NAME` (default: BRONZE)
  - [ ] `SILVER_SCHEMA_NAME` (default: SILVER)

## Deployment Steps

### 1. Initial Deployment

- [ ] Run deployment script
  ```bash
  ./deploy.sh
  ```

- [ ] Check for errors in output
  - [ ] No SQL compilation errors
  - [ ] All scripts executed successfully
  - [ ] Streamlit apps deployed

- [ ] Verify deployment
  ```bash
  snow sql -f silver/quick_deployment_check.sql
  ```

### 2. Bronze Layer Verification

- [ ] **Database & Roles Created**
  ```sql
  SHOW DATABASES LIKE 'DB_INGEST_PIPELINE';
  SHOW ROLES LIKE 'DB_INGEST_PIPELINE%';
  ```

- [ ] **Tables Created** (2 tables)
  - [ ] `RAW_DATA_TABLE`
  - [ ] `FILE_PROCESSING_QUEUE`

- [ ] **Stages Created** (6 stages)
  - [ ] `SRC` - Source files
  - [ ] `COMPLETED` - Processed files
  - [ ] `ERROR` - Failed files
  - [ ] `ARCHIVE` - Archived files
  - [ ] `STREAMLIT_STAGE` - Streamlit app
  - [ ] `CONFIG_STAGE` - Configuration

- [ ] **Procedures Created** (4+ procedures)
  - [ ] `discover_files()`
  - [ ] `process_queued_files()`
  - [ ] `move_files_to_stage()`
  - [ ] `archive_old_files()`

- [ ] **Tasks Created** (5 tasks)
  - [ ] `discover_files_task`
  - [ ] `process_files_task`
  - [ ] `move_successful_files_task`
  - [ ] `move_failed_files_task`
  - [ ] `archive_old_files_task`

- [ ] **Streamlit App Deployed**
  - [ ] `BRONZE_INGESTION_PIPELINE` accessible in Snowsight

### 3. Silver Layer Verification

- [ ] **Schema Created**
  ```sql
  SHOW SCHEMAS LIKE 'SILVER' IN DATABASE DB_INGEST_PIPELINE;
  ```

- [ ] **Metadata Tables Created** (8+ tables)
  - [ ] `target_schemas`
  - [ ] `field_mappings`
  - [ ] `transformation_rules`
  - [ ] `processing_watermarks`
  - [ ] `data_quality_metrics`
  - [ ] `quarantine_records`
  - [ ] `silver_processing_log`
  - [ ] `known_field_mappings`

- [ ] **Target Tables Created**
  - [ ] `CLAIMS` table exists
  - [ ] 27 columns defined
  - [ ] Physical table created

- [ ] **Field Mappings Configured**
  - [ ] At least 25 mappings for CLAIMS
  - [ ] Source fields match Bronze data

- [ ] **Transformation Rules Loaded**
  - [ ] Rules target CLAIMS (not CLAIMS)
  - [ ] Data quality rules active
  - [ ] Standardization rules active

- [ ] **Stored Procedures Created** (30+ procedures)
  - [ ] `transform_bronze_to_silver()`
  - [ ] `create_silver_table()`
  - [ ] `load_target_schemas_from_csv()`
  - [ ] `load_field_mappings_from_csv()`
  - [ ] `load_transformation_rules_from_csv()`

- [ ] **Stages Created** (2+ stages)
  - [ ] `SILVER_STAGE`
  - [ ] `SILVER_CONFIG`

- [ ] **Streamlit App Deployed**
  - [ ] `SILVER_TRANSFORMATION_MANAGER` accessible in Snowsight

## Post-Deployment Configuration

### 4. Load Sample Data (Optional)

- [ ] **Upload sample files**
  ```bash
  snow sql -q "PUT file://sample_data/claims_data/*.csv @DB_INGEST_PIPELINE.BRONZE.SRC;"
  ```

- [ ] **Verify files uploaded**
  ```sql
  LIST @DB_INGEST_PIPELINE.BRONZE.SRC;
  ```

### 5. Test Bronze Processing

- [ ] **Discover files**
  ```sql
  CALL DB_INGEST_PIPELINE.BRONZE.discover_files();
  ```

- [ ] **Check queue**
  ```sql
  SELECT * FROM DB_INGEST_PIPELINE.BRONZE.FILE_PROCESSING_QUEUE;
  ```

- [ ] **Process files**
  ```sql
  CALL DB_INGEST_PIPELINE.BRONZE.process_queued_files();
  ```

- [ ] **Verify data loaded**
  ```sql
  SELECT COUNT(*) FROM DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE;
  ```

### 6. Test Silver Transformation

- [ ] **Run test transformation**
  ```sql
  CALL DB_INGEST_PIPELINE.SILVER.transform_bronze_to_silver(
      'RAW_DATA_TABLE', 'CLAIMS', 'BRONZE', 100, FALSE, TRUE
  );
  ```

- [ ] **Verify transformation succeeded**
  - [ ] No errors in output
  - [ ] Records processed > 0

- [ ] **Check Silver data**
  ```sql
  SELECT COUNT(*) FROM DB_INGEST_PIPELINE.SILVER.CLAIMS;
  SELECT * FROM DB_INGEST_PIPELINE.SILVER.CLAIMS LIMIT 5;
  ```

### 7. Enable Automation (Optional)

- [ ] **Resume Bronze tasks**
  ```sql
  CALL DB_INGEST_PIPELINE.BRONZE.resume_all_tasks();
  ```

- [ ] **Resume Silver tasks**
  ```sql
  CALL DB_INGEST_PIPELINE.SILVER.resume_all_silver_tasks();
  ```

- [ ] **Verify tasks running**
  ```sql
  SHOW TASKS IN DATABASE DB_INGEST_PIPELINE;
  ```

## Validation

### 8. End-to-End Test

- [ ] **Upload a test file** via Streamlit or CLI
- [ ] **Wait for processing** (or trigger manually)
- [ ] **Verify in Bronze**:
  - [ ] File in queue with SUCCESS status
  - [ ] Data in RAW_DATA_TABLE
  - [ ] File moved to COMPLETED stage

- [ ] **Run Silver transformation**
- [ ] **Verify in Silver**:
  - [ ] Data in CLAIMS table
  - [ ] Field mappings applied correctly
  - [ ] No quarantined records (or expected quarantines)

### 9. Streamlit Apps

- [ ] **Bronze App Accessible**
  - [ ] Can upload files
  - [ ] Can view processing status
  - [ ] Can manage tasks
  - [ ] Can browse stages

- [ ] **Silver App Accessible**
  - [ ] Can view target tables
  - [ ] Can configure field mappings
  - [ ] Can run transformations
  - [ ] Can view data

## Troubleshooting

### Common Issues

**Issue: Deployment fails with permission error**
- [ ] Verify ACCOUNTADMIN role or equivalent
- [ ] Check warehouse permissions
- [ ] Verify database creation rights

**Issue: Streamlit app not found**
- [ ] Check deployment logs
- [ ] Verify Snowflake CLI version (>= 2.0)
- [ ] Redeploy: `./redeploy_silver_streamlit.sh`

**Issue: Tasks not executing**
- [ ] Check task state: `SHOW TASKS`
- [ ] Resume tasks: `CALL resume_all_tasks()`
- [ ] Verify warehouse is running

**Issue: Transformation fails**
- [ ] Check field mappings match Bronze data
- [ ] Verify target table exists
- [ ] Check for NULL in required fields
- [ ] Review error in transformation log

## Cleanup (If Needed)

- [ ] **Undeploy everything**
  ```bash
  ./undeploy.sh
  ```

- [ ] **Verify cleanup**
  ```sql
  SHOW DATABASES LIKE 'DB_INGEST_PIPELINE';
  SHOW ROLES LIKE 'DB_INGEST_PIPELINE%';
  ```

## Sign-Off

- [ ] **Deployment completed successfully**
- [ ] **All verification checks passed**
- [ ] **Sample data processed**
- [ ] **Streamlit apps accessible**
- [ ] **Documentation reviewed**

**Deployed by:** _______________  
**Date:** _______________  
**Environment:** _______________  
**Notes:** _______________

---

## Quick Reference

**Verification Commands:**
```bash
# Quick check
snow sql -f silver/quick_deployment_check.sql

# Detailed check
snow sql -f silver/verify_silver_deployment.sql
```

**Common Operations:**
```sql
-- Resume all tasks
CALL DB_INGEST_PIPELINE.BRONZE.resume_all_tasks();
CALL DB_INGEST_PIPELINE.SILVER.resume_all_silver_tasks();

-- Suspend all tasks
CALL DB_INGEST_PIPELINE.BRONZE.suspend_all_tasks();
CALL DB_INGEST_PIPELINE.SILVER.suspend_all_silver_tasks();

-- Check processing status
SELECT * FROM DB_INGEST_PIPELINE.BRONZE.FILE_PROCESSING_QUEUE;
SELECT * FROM DB_INGEST_PIPELINE.SILVER.processing_watermarks;
```

**Documentation:**
- Quick Start: [QUICK_START.md](QUICK_START.md)
- Main README: [README.md](README.md)
- User Guide: [docs/USER_GUIDE.md](docs/USER_GUIDE.md)
- Deployment Verification: [silver/DEPLOYMENT_VERIFICATION.md](silver/DEPLOYMENT_VERIFICATION.md)

