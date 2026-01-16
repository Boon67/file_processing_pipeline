# Troubleshooting: LLM Suggests Columns Not in Target Schema

**Issue:** LLM generates mappings but they're all skipped with message: "Skipped X invalid mappings (columns not in target schema)"

## What's Happening

The LLM is analyzing your source data and suggesting field mappings to columns that don't exist in your `target_schemas` table definition. This is actually **good** - it means:

1. ✅ The LLM is working correctly
2. ✅ The LLM found fields in your source data
3. ✅ The validation is working (protecting you from invalid mappings)
4. ❌ Your target schema definition is incomplete

## Example from Your Case

**LLM Suggested:**
- `PROCEDURE_DATE` (suggested by LLM but not in schema)
- `TOOTH_NUMBER` (suggested by LLM but not in schema)
- `PRODUCT_TYPE` (suggested by LLM but not in schema)

**Your Current Schema Has:**
- CLAIM_NUM, FIRST_NAME, LAST_NAME, DOB, SUBSCRIBER_FIRST, SUBSCRIBER_LAST, GROUP_NAME, POLICY_EFFECTIVE_DATE, PAID_DATE, REVENUE_CD, PROVIDER_NPI, PLAN_TYPE, BILLED_CHARGES, ALLOWED_AMT, DEDUCTIBLE, COPAY, COINSURANCE, PLAN_PAID, CLAIM_TYPE, PROVIDER_NAME, PROVIDER_ADDRESS, PROVIDER_TIN, SOURCE_FILE_NAME, INGESTION_TIMESTAMP, CREATED_AT, UPDATED_AT

## Diagnosis Steps

### 1. Check What Fields Exist in Your Source Data

Run this query in Snowsight:

```sql
USE DATABASE db_ingest_pipeline;
USE SCHEMA BRONZE;

-- Get all unique field names from your source data
SELECT 
    key AS source_field_name,
    COUNT(*) as occurrence_count
FROM RAW_DATA_TABLE,
LATERAL FLATTEN(input => RAW_DATA)
WHERE RAW_DATA IS NOT NULL
GROUP BY key
ORDER BY key;
```

Or run the diagnostic script:

```bash
snow sql -f silver/mappings/diagnose_source_fields.sql
```

### 2. Compare Source Fields with Target Schema

**Source fields** = What's in your Bronze RAW_DATA  
**Target schema** = What columns you've defined in `target_schemas`

The LLM can only map to columns that exist in your target schema.

## Solutions

### Solution 1: Add Missing Columns to Target Schema (Recommended)

If the LLM-suggested columns are valid and you want to capture that data:

**Option A: Edit the CSV and Reload**

1. Edit `silver/mappings/target_tables.csv`
2. Add the missing columns:

```csv
claims,PROCEDURE_DATE,provider_a,DATE,TRUE,,Date when medical/dental procedure was performed
claims,TOOTH_NUMBER,provider_a,VARCHAR(10),TRUE,,Tooth number for dental procedures
claims,PRODUCT_TYPE,provider_a,VARCHAR(100),TRUE,,Type of product or service provided
```

3. Reload the target schemas:

```bash
cd /Users/tboon/code/file_processing_pipeline
./deploy_silver.sh
```

**Option B: Add Columns Directly in SQL**

Run the provided script:

```bash
snow sql -f silver/mappings/add_missing_columns.sql
```

Or add them manually in the Streamlit app:
1. Go to **📐 Target Table Designer**
2. Select your table
3. Add the missing columns

### Solution 2: Refine Your Target Schema

If the LLM is suggesting columns you don't need:

1. Review your source data to understand what fields are actually present
2. Define only the columns you want to keep in your target schema
3. The LLM will still suggest mappings for all source fields, but only valid ones will be saved

### Solution 3: Create a Custom Prompt Template

Guide the LLM to only suggest mappings for existing columns:

1. Go to **📋 Prompt Templates** tab
2. Create a new template that explicitly lists your target columns
3. Example:

```
You are a data mapping expert. Map the following source fields to ONLY these target columns:
- CLAIM_NUM, FIRST_NAME, LAST_NAME, DOB, SUBSCRIBER_FIRST, SUBSCRIBER_LAST, 
  GROUP_NAME, POLICY_EFFECTIVE_DATE, PAID_DATE, REVENUE_CD, PROVIDER_NPI, 
  PLAN_TYPE, BILLED_CHARGES, ALLOWED_AMT, DEDUCTIBLE, COPAY, COINSURANCE, 
  PLAN_PAID, CLAIM_TYPE, PROVIDER_NAME, PROVIDER_ADDRESS, PROVIDER_TIN

Source fields: {source_fields}

Only suggest mappings to the columns listed above. Do not suggest new columns.
Return JSON array with: source_field, target_field (format: TABLE.COLUMN), confidence (0-1), reasoning.
```

## Understanding the Validation

The stored procedure `auto_map_fields_llm` validates each mapping:

```sql
-- Get valid target columns
SELECT DISTINCT column_name
FROM target_schemas
WHERE table_name = 'CLAIMS'
  AND active = TRUE

-- Check if LLM-suggested column exists
IF target_column NOT IN valid_columns THEN
    -- Skip this mapping
    rows_skipped += 1
END IF
```

This validation **protects you** from:
- Typos in column names
- Columns that don't exist
- Mappings to deprecated/inactive columns

## Best Practice Workflow

1. **Define your target schema first** - Know what columns you want
2. **Review your source data** - Understand what fields are available
3. **Generate LLM mappings** - Let the LLM suggest mappings
4. **Review skipped mappings** - Check if you need to add columns
5. **Update schema if needed** - Add missing columns that are valuable
6. **Regenerate mappings** - Run LLM mapping again
7. **Approve mappings** - Review and approve the valid mappings

## Quick Fix for Your Case

Run these commands:

```bash
cd /Users/tboon/code/file_processing_pipeline

# 1. Check what's in your source data
snow sql -f silver/mappings/diagnose_source_fields.sql

# 2. If PROCEDURE_DATE, TOOTH_NUMBER, PRODUCT_TYPE exist and you want them:
snow sql -f silver/mappings/add_missing_columns.sql

# 3. Go back to Streamlit and generate LLM mappings again
# The previously skipped columns should now be included
```

## Related Documentation

- [Target Table Designer Guide](../guides/target_table_designer.md)
- [LLM Mapping Troubleshooting](./llm_mapping_no_results.md)
- [Field Mapping Overview](../guides/field_mapping.md)
