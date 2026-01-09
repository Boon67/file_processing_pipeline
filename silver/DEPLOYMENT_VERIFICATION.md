# Silver Layer Deployment Verification

This directory contains scripts to verify that the Silver layer has been deployed correctly.

## Quick Verification

Run this script for a quick summary of the deployment status:

```bash
snow sql -f silver/quick_deployment_check.sql
```

### Expected Output

```
═══════════════════════════════════════════════════
   SILVER LAYER DEPLOYMENT VERIFICATION REPORT
═══════════════════════════════════════════════════

1. METADATA TABLES
   ───────────────
   ✓ PASS: 14 metadata tables exist

2. TARGET TABLE DEFINITIONS
   ────────────────────────
   ✓ PASS: 1 target tables defined
   Tables: CLAIMS

3. CLAIMS TABLE
   ────────────
   ✓ PASS: CLAIMS defined with 27 columns
   ✓ PASS: CLAIMS physical table exists with 100 records

4. FIELD MAPPINGS
   ───────────────
   ✓ PASS: 29 field mappings configured
   ✓ PASS: CLAIMS has 25 field mappings

5. TRANSFORMATION RULES
   ────────────────────
   ✓ INFO: 24 transformation rules configured

6. STORED PROCEDURES
   ──────────────────
   ✓ PASS: 34 procedures deployed
   ✓ transform_bronze_to_silver exists
   ✓ create_silver_table exists

7. STAGES
   ───────
   ✓ PASS: 2 stages configured

8. TASKS
   ──────
   ✓ INFO: Tasks configured

9. BRONZE DATA AVAILABILITY
   ────────────────────────
   ✓ INFO: 5095 records in Bronze RAW_DATA_TABLE
   ✓ INFO: 5 unique source files

10. PROCESSING WATERMARKS
    ──────────────────────
    ✓ INFO: 1 watermarks configured

═══════════════════════════════════════════════════
   DEPLOYMENT SUMMARY
═══════════════════════════════════════════════════

               Metadata Tables |       14 | ✓
      Target Table Definitions |        1 | ✓
          CLAIMS Table Columns |       27 | ✓
                CLAIMS Records |      100 | ✓
                Field Mappings |       29 | ✓
          Transformation Rules |       24 | ○
             Stored Procedures |       34 | ✓
                        Stages |        2 | ✓
      Bronze Records Available |     5095 | ✓

   ✓ = Pass    ✗ = Fail    ⚠ = Warning    ○ = Info
═══════════════════════════════════════════════════
```

## Comprehensive Verification

For a more detailed verification with all tables, procedures, and configurations:

```bash
snow sql -f silver/verify_silver_deployment.sql
```

This script provides:
- Complete list of all metadata tables
- Detailed target schema definitions
- Physical table verification
- Field mapping details
- Transformation rules breakdown
- Stored procedure inventory
- Stage configuration
- Task status
- View definitions
- Data validation
- Watermark status

## What to Check

### ✓ Required Components (Must Pass)

1. **Metadata Tables**: At least 8 tables should exist
   - `target_schemas`
   - `field_mappings`
   - `transformation_rules`
   - `processing_watermarks`
   - `data_quality_metrics`
   - `quarantine_records`
   - `silver_processing_log`
   - Plus any target tables (e.g., CLAIMS)

2. **Target Table Definitions**: At least one target table defined in `target_schemas`

3. **Physical Tables**: Physical tables created for all defined target schemas

4. **Stored Procedures**: Critical procedures must exist:
   - `transform_bronze_to_silver`
   - `create_silver_table`
   - `load_target_schemas_from_csv`
   - `load_field_mappings_from_csv`
   - `load_transformation_rules_from_csv`

5. **Stages**: At least 2 stages configured:
   - `SILVER_STAGE` (for intermediate files)
   - `SILVER_CONFIG` (for configuration CSVs)

### ⚠ Optional Components (Warnings OK)

1. **Field Mappings**: Not required immediately after deployment, but needed for transformations

2. **Transformation Rules**: Optional - only needed if applying data quality/business rules

3. **Tasks**: Optional - can be configured later for automation

### ○ Informational

1. **Data in Silver Tables**: Empty tables are normal for new deployments

2. **Watermarks**: No watermarks expected until first transformation runs

## Troubleshooting

### Issue: CLAIMS table not defined

**Solution:**
```sql
-- Load from CSV
PUT file://silver/mappings/target_tables.csv @SILVER_CONFIG;
CALL load_target_schemas_from_csv('@SILVER_CONFIG/target_tables.csv');

-- Or create manually
-- See: silver/quick_deployment_check.sql for example
```

### Issue: No field mappings

**Solution:**
```sql
-- Load from CSV
PUT file://silver/mappings/field_mappings.csv @SILVER_CONFIG;
CALL load_field_mappings_from_csv('@SILVER_CONFIG/field_mappings.csv');

-- Or use Streamlit app Field Mapper tab
```

### Issue: Physical table missing

**Solution:**
```sql
-- Create table from definition
CALL create_silver_table('CLAIMS');

-- Or create manually if procedure has issues
-- See: create_claims_physical_table.sql for example
```

### Issue: Transformation fails with "NULL in non-nullable column"

**Solution:**
Check that field mappings match the actual Bronze data field names:
```sql
-- Check Bronze data structure
SELECT RAW_DATA FROM db_ingest_pipeline.BRONZE.RAW_DATA_TABLE LIMIT 1;

-- Check field mappings
SELECT source_field, target_column 
FROM field_mappings 
WHERE target_table = 'CLAIMS';

-- Update incorrect mapping
UPDATE field_mappings 
SET source_field = 'CORRECT_FIELD_NAME'
WHERE target_table = 'CLAIMS' 
  AND target_column = 'COLUMN_NAME';
```

## Manual Test

After verification passes, test a manual transformation:

```sql
USE DATABASE db_ingest_pipeline;
USE SCHEMA SILVER;

-- Test with small batch
CALL transform_bronze_to_silver(
    'RAW_DATA_TABLE',  -- source
    'CLAIMS',          -- target
    'BRONZE',          -- bronze schema
    100,               -- batch size
    FALSE,             -- apply rules
    TRUE               -- incremental
);

-- Check results
SELECT COUNT(*) FROM CLAIMS;
SELECT * FROM CLAIMS LIMIT 5;
```

## Next Steps After Verification

1. **Configure Additional Tables** (if needed)
   - Use Streamlit Target Table Designer
   - Or load from CSV files

2. **Set Up Field Mappings**
   - Use Streamlit Field Mapper (Manual/ML/LLM)
   - Or load from CSV

3. **Configure Transformation Rules** (optional)
   - Use Streamlit Rules Engine
   - Or load from CSV

4. **Run Transformations**
   - Use Streamlit Manual Transformation
   - Or call procedures directly

5. **Enable Automation** (optional)
   - Resume Silver tasks for scheduled processing
   - Monitor in Streamlit Transformation Monitor

## Files

- `quick_deployment_check.sql` - Quick summary verification (recommended)
- `verify_silver_deployment.sql` - Comprehensive detailed verification
- `DEPLOYMENT_VERIFICATION.md` - This file

## Support

For issues or questions:
1. Check the verification output for specific failures
2. Review the troubleshooting section above
3. Check the main Silver README: `silver/README.md`
4. Review deployment logs from `deploy_silver.sh`

