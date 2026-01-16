# TPA-Based File Upload Guide

## Overview

The Bronze layer now supports **TPA (Third Party Administrator) based file organization**. This feature allows you to organize uploaded files by provider, enabling TPA-specific processing rules and better data organization.

## What is TPA?

**TPA (Third Party Administrator)** refers to the healthcare provider or administrator that generated the claims data. Examples include insurance companies, pharmacy benefit managers, or healthcare networks.

In this system, the TPA:
- Determines the **subfolder** where files are uploaded in the `@SRC` stage
- Is automatically **extracted and stored** in the `TPA` column of the `RAW_DATA_TABLE`
- Enables **TPA-specific mappings and rules** in the Silver layer

## How It Works

### 1. TPA Master Table

TPAs are managed in the `TPA_MASTER` table in the Bronze schema:

```sql
CREATE TABLE TPA_MASTER (
    TPA_CODE VARCHAR(500) PRIMARY KEY,      -- TPA identifier (e.g., 'provider_a')
    TPA_NAME VARCHAR(500) NOT NULL,         -- Full TPA name
    TPA_DESCRIPTION VARCHAR(5000),          -- Description
    ACTIVE BOOLEAN DEFAULT TRUE,            -- Whether TPA is active for uploads
    CREATED_TIMESTAMP TIMESTAMP_NTZ,
    UPDATED_TIMESTAMP TIMESTAMP_NTZ,
    CREATED_BY VARCHAR(500)
);
```

**Default TPAs:**
- `provider_a` - Provider A Healthcare
- `provider_b` - Provider B Insurance
- `provider_c` - Provider C Medical
- `provider_d` - Provider D Dental
- `provider_e` - Provider E Pharmacy

### 2. File Upload with TPA Selection

When uploading files through the Streamlit UI:

1. **Select TPA** from the dropdown (loaded from `TPA_MASTER` table)
   - Only active TPAs are shown
   - Display format: `{TPA_CODE} - {TPA_NAME}`
   - TPA selection is **required** (cannot be null)

2. **Upload files** as usual (drag-and-drop or browse)

3. Files are automatically uploaded to: `@SRC/{tpa_code}/`

### 2. Folder Structure

Files are organized in the `@SRC` stage by TPA:

```
@DB_INGEST_PIPELINE.BRONZE.SRC/
├── provider_a/
│   ├── dental-claims-20240301.csv
│   ├── medical-claims-20240315.csv
│   └── pharmacy-claims-20240320.csv
├── provider_b/
│   ├── claims-20240115.csv
│   └── claims-20240215.csv
├── provider_c/
│   └── medical-claims-20240215.xlsx
├── provider_d/
│   └── dental-claims-20240301.xlsx
└── provider_e/
    └── pharmacy-claims-20240201.csv
```

### 3. Automatic TPA Extraction

During file processing, the Bronze layer:

1. **Extracts the TPA** from the file path (folder name)
2. **Stores it** in the `TPA` column of the `RAW_DATA_TABLE`
3. **Preserves it** through the entire data pipeline

Example:
```
File Path: @SRC/provider_a/dental-claims-20240301.csv
Extracted TPA: provider_a
```

### 4. TPA Column in RAW_DATA_TABLE

Every row in the `RAW_DATA_TABLE` includes the TPA:

```sql
SELECT 
    FILE_NAME,
    TPA,
    ROW_NUMBER,
    DATA_JSON
FROM DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE
LIMIT 5;
```

Result:
```
FILE_NAME                        | TPA        | ROW_NUMBER | DATA_JSON
---------------------------------|------------|------------|------------------
dental-claims-20240301.csv       | provider_a | 1          | {...}
dental-claims-20240301.csv       | provider_a | 2          | {...}
claims-20240115.csv              | provider_b | 1          | {...}
medical-claims-20240215.xlsx     | provider_c | 1          | {...}
pharmacy-claims-20240201.csv     | provider_e | 1          | {...}
```

## Usage Examples

### Streamlit UI Upload

1. Open the Bronze Ingestion Pipeline Streamlit app
2. Navigate to "📤 Upload Files" tab
3. **Select TPA**: Choose `provider_a` from dropdown
4. **Upload files**: Drag and drop your CSV/Excel files
5. Click "🚀 Upload to Snowflake"
6. Files are uploaded to `@SRC/provider_a/`

### SQL Upload

```sql
-- Upload files to provider_a folder
PUT file:///path/to/dental-claims.csv @DB_INGEST_PIPELINE.BRONZE.SRC/provider_a/;
PUT file:///path/to/medical-claims.csv @DB_INGEST_PIPELINE.BRONZE.SRC/provider_a/;

-- Upload files to provider_b folder
PUT file:///path/to/claims.csv @DB_INGEST_PIPELINE.BRONZE.SRC/provider_b/;

-- Verify uploads
SELECT * FROM DIRECTORY(@DB_INGEST_PIPELINE.BRONZE.SRC);
```

### Adding New TPAs

To add a new TPA to the system, an administrator must insert it into the `TPA_MASTER` table:

```sql
-- Add a new TPA
INSERT INTO DB_INGEST_PIPELINE.BRONZE.TPA_MASTER 
(TPA_CODE, TPA_NAME, TPA_DESCRIPTION, ACTIVE)
VALUES (
    'blue_cross',                          -- TPA code
    'Blue Cross Blue Shield',              -- Full name
    'Blue Cross Blue Shield Insurance',    -- Description
    TRUE                                   -- Active
);
```

**Naming Convention for TPA Codes:**
- Use lowercase letters
- Use underscores for spaces (e.g., `blue_cross` not `Blue Cross`)
- Avoid special characters
- Keep it short and descriptive

**After adding a new TPA:**
1. The TPA will appear in the Streamlit dropdown within 5 minutes (cache refresh)
2. Or refresh the Streamlit app manually to see it immediately
3. Users can then select it for file uploads

See `bronze/TPA_Management.sql` for more TPA management utilities.

## Querying by TPA

Once files are processed, you can query data by TPA:

```sql
-- Get all data for a specific TPA
SELECT * 
FROM DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE
WHERE TPA = 'provider_a';

-- Count rows by TPA
SELECT 
    TPA,
    COUNT(*) as row_count,
    COUNT(DISTINCT FILE_NAME) as file_count
FROM DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE
GROUP BY TPA
ORDER BY row_count DESC;

-- Get files processed by TPA
SELECT 
    TPA,
    FILE_NAME,
    COUNT(*) as rows,
    MIN(LOAD_TIMESTAMP) as first_loaded,
    MAX(LOAD_TIMESTAMP) as last_loaded
FROM DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE
GROUP BY TPA, FILE_NAME
ORDER BY TPA, FILE_NAME;
```

## Integration with Silver Layer

The TPA column flows through to the Silver layer, enabling:

### 1. TPA-Specific Field Mappings

Define different field mappings for each TPA:

```sql
-- Provider A uses 'PAT_FNAME' for patient first name
INSERT INTO DB_INGEST_PIPELINE.SILVER.field_mappings
(source_field, target_table, target_column, tpa, transformation_logic)
VALUES ('PAT_FNAME', 'CLAIMS', 'PATIENT_FIRST_NAME', 'provider_a', 'UPPER(TRIM(source_value))');

-- Provider B uses 'MEMBER_FIRST_NAME' for patient first name
INSERT INTO DB_INGEST_PIPELINE.SILVER.field_mappings
(source_field, target_table, target_column, tpa, transformation_logic)
VALUES ('MEMBER_FIRST_NAME', 'CLAIMS', 'PATIENT_FIRST_NAME', 'provider_b', 'UPPER(TRIM(source_value))');
```

### 2. TPA-Specific Transformation Rules

Apply different business rules for each TPA:

```sql
-- Provider A specific rule: claims over $10,000 require review
INSERT INTO DB_INGEST_PIPELINE.SILVER.transformation_rules
(rule_name, target_table, rule_type, tpa, rule_logic)
VALUES (
    'high_value_claims_review',
    'CLAIMS',
    'VALIDATION',
    'provider_a',
    'claim_amount > 10000'
);

-- Provider B specific rule: claims over $5,000 require review
INSERT INTO DB_INGEST_PIPELINE.SILVER.transformation_rules
(rule_name, target_table, rule_type, tpa, rule_logic)
VALUES (
    'high_value_claims_review',
    'CLAIMS',
    'VALIDATION',
    'provider_b',
    'claim_amount > 5000'
);
```

### 3. Global vs TPA-Specific Rules

- **Global Rules**: `tpa = NULL` - applies to all TPAs
- **TPA-Specific Rules**: `tpa = 'provider_a'` - applies only to that TPA

The Silver layer prioritizes TPA-specific rules over global rules.

## Best Practices

### 1. TPA Management

- **Add TPAs before uploading**: Ensure TPA exists in `TPA_MASTER` before users upload files
- **Use descriptive names**: TPA_NAME should be clear and recognizable
- **Document TPAs**: Keep TPA_DESCRIPTION up to date
- **Deactivate, don't delete**: Use `ACTIVE = FALSE` instead of deleting TPAs
- **Regular review**: Periodically review and clean up inactive TPAs

### 2. Consistent Naming

- Use the same TPA code across all files from the same provider
- Stick to lowercase with underscores for TPA codes
- Document your TPA naming conventions
- Validate TPA codes against external systems if possible

### 3. File Organization

- Keep all files from the same provider in the same TPA folder
- Don't mix providers in a single folder
- Use descriptive file names that include dates

### 4. Testing

Before uploading production data:

1. Add a test TPA to `TPA_MASTER` (e.g., `test_provider`)
2. Upload sample files using the test TPA
3. Verify TPA extraction and processing
4. Test Silver layer mappings and rules
5. Deactivate test TPA when done

### 5. Monitoring

Monitor TPA-specific metrics:

```sql
-- Processing success rate by TPA
SELECT 
    tm.TPA_CODE,
    tm.TPA_NAME,
    COUNT(*) as total_files,
    SUM(CASE WHEN fpq.status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_files,
    ROUND(100.0 * SUM(CASE WHEN fpq.status = 'SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2) as success_rate
FROM DB_INGEST_PIPELINE.BRONZE.TPA_MASTER tm
LEFT JOIN DB_INGEST_PIPELINE.BRONZE.RAW_DATA_TABLE rdt ON tm.TPA_CODE = rdt.TPA
LEFT JOIN DB_INGEST_PIPELINE.BRONZE.file_processing_queue fpq ON rdt.FILE_NAME = fpq.file_name
WHERE fpq.file_name IS NOT NULL
GROUP BY tm.TPA_CODE, tm.TPA_NAME
ORDER BY total_files DESC;
```

### 6. Access Control

- Limit `TPA_MASTER` write access to administrators only
- Grant read access to users who need to view TPA list
- Audit TPA changes regularly
- Use role-based access control (RBAC)

## Troubleshooting

### TPA Not Extracted

**Problem**: TPA column is NULL or contains unexpected values

**Solution**:
1. Verify files are uploaded to a subfolder (not root of `@SRC`)
2. Check folder naming (use lowercase, underscores only)
3. Re-upload files to the correct TPA subfolder

### Wrong TPA Value

**Problem**: Files have incorrect TPA value

**Solution**:
1. Move files to the correct TPA subfolder in the stage
2. Reprocess the files using the Streamlit UI "Reprocess" feature
3. The TPA will be re-extracted from the new folder path

### Mixed TPAs in One Folder

**Problem**: Files from multiple providers in one TPA folder

**Solution**:
1. Create separate TPA folders for each provider
2. Move files to the appropriate folders
3. Reprocess files to update TPA values

## Migration Guide

### Migrating Existing Files

If you have existing files in the root `@SRC` stage without TPA folders:

1. **Create TPA folders**:
   ```sql
   -- No SQL needed, folders are created automatically on upload
   ```

2. **Move existing files**:
   ```sql
   -- Copy files to TPA-specific folders
   COPY FILES INTO @DB_INGEST_PIPELINE.BRONZE.SRC/provider_a/
   FROM @DB_INGEST_PIPELINE.BRONZE.SRC
   FILES = ('dental-claims-20240301.csv');
   
   -- Remove from root
   REMOVE @DB_INGEST_PIPELINE.BRONZE.SRC/dental-claims-20240301.csv;
   ```

3. **Reprocess files**:
   ```sql
   -- Reprocess to extract TPA
   CALL DB_INGEST_PIPELINE.BRONZE.reprocess_all_error_files();
   ```

### Updating Silver Mappings

Add TPA column to existing mappings:

```sql
-- Update existing mappings to be TPA-specific
UPDATE DB_INGEST_PIPELINE.SILVER.field_mappings
SET tpa = 'provider_a'
WHERE source_field IN ('PAT_FNAME', 'PAT_LNAME', 'PAT_DOB');

-- Or leave as global (NULL)
UPDATE DB_INGEST_PIPELINE.SILVER.field_mappings
SET tpa = NULL
WHERE source_field IN ('CLAIM_ID', 'CLAIM_DATE');
```

## FAQ

### Q: Can I upload files without specifying a TPA?

**A:** No, TPA selection is mandatory. The Streamlit UI requires TPA selection, and the `RAW_DATA_TABLE.TPA` column is NOT NULL. For SQL uploads, you must specify a TPA subfolder.

### Q: How do I add a new TPA?

**A:** An administrator must insert it into the `TPA_MASTER` table:
```sql
INSERT INTO TPA_MASTER (TPA_CODE, TPA_NAME, TPA_DESCRIPTION, ACTIVE)
VALUES ('new_tpa', 'New TPA Name', 'Description', TRUE);
```
See `bronze/TPA_Management.sql` for more examples.

### Q: Why isn't my new TPA showing in the dropdown?

**A:** The Streamlit app caches the TPA list for 5 minutes. Either wait 5 minutes or refresh the app manually. Also verify the TPA is `ACTIVE = TRUE`.

### Q: Can I change the TPA for existing data?

**A:** Yes, move the file to a new TPA folder in the stage and reprocess it. The TPA will be re-extracted from the new folder path.

### Q: What happens if I use the same file name in different TPA folders?

**A:** Each file is tracked separately by its full path, so `provider_a/claims.csv` and `provider_b/claims.csv` are treated as different files.

### Q: Can I have nested folders within TPA folders?

**A:** The TPA is extracted from the first subfolder level. Additional nesting is ignored for TPA extraction but preserved in the file path.

### Q: How do I deactivate a TPA?

**A:** Update the TPA_MASTER table:
```sql
UPDATE TPA_MASTER SET ACTIVE = FALSE WHERE TPA_CODE = 'old_tpa';
```
This removes it from the dropdown but preserves historical data.

### Q: Can I delete a TPA?

**A:** It's better to deactivate (`ACTIVE = FALSE`) instead of deleting. If you must delete, ensure no data exists for that TPA first:
```sql
-- Check for data
SELECT COUNT(*) FROM RAW_DATA_TABLE WHERE TPA = 'tpa_to_delete';
-- If count is 0, safe to delete
DELETE FROM TPA_MASTER WHERE TPA_CODE = 'tpa_to_delete';
```

### Q: What happens if I have orphaned TPA data?

**A:** If `RAW_DATA_TABLE` has TPA values not in `TPA_MASTER`, add them:
```sql
INSERT INTO TPA_MASTER (TPA_CODE, TPA_NAME, TPA_DESCRIPTION, ACTIVE)
VALUES ('orphaned_tpa', 'Orphaned TPA Name', 'Legacy data', FALSE);
```

## Related Documentation

- [TPA Complete Guide](../docs/guides/TPA_COMPLETE_GUIDE.md) - Complete TPA documentation
- [Bronze Layer README](README.md) - Bronze layer overview
- [Silver TPA Mapping Guide](../silver/TPA_MAPPING_GUIDE.md) - TPA-specific mappings and rules
- [Deployment & Operations](../docs/DEPLOYMENT_AND_OPERATIONS.md) - Deployment guide
- [User Guide](../docs/USER_GUIDE.md) - End-user documentation
- [Streamlit README](bronze_streamlit/README.md) - Streamlit app documentation

---

**Last Updated**: January 14, 2026  
**Version**: 1.0  
**Status**: Production Ready ✅
