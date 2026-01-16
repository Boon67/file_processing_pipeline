# TPA-Aware Mapping and Rules Guide

## Overview

The Silver layer now supports **TPA-specific field mappings and transformation rules**, allowing you to configure different data transformations for each Third Party Administrator (provider). This enables handling of provider-specific data formats, field names, and business rules within a single unified pipeline.

## What is TPA?

**TPA** (Third Party Administrator) is a column in the Bronze layer that identifies which provider/organization the data came from. The TPA value is automatically extracted from the folder structure when files are uploaded:

```
Bronze Stage Structure:
@SRC/
├── provider_a/
│   └── dental-claims-20240301.csv    → TPA = 'provider_a'
├── provider_b/
│   └── medical-claims-20240115.csv   → TPA = 'provider_b'
└── provider_e/
    └── pharmacy-claims-20240201.csv  → TPA = 'provider_e'
```

## TPA-Aware Architecture

### Hierarchy of Mappings and Rules

The system uses a **hierarchical approach** where TPA-specific configurations override global configurations:

1. **TPA-Specific** (highest priority): Mappings/rules with `TPA = 'provider_a'`
2. **Global** (fallback): Mappings/rules with `TPA = NULL`

When processing data from a specific TPA, the system:
1. First looks for TPA-specific mappings/rules
2. Falls back to global mappings/rules if no TPA-specific ones exist
3. Allows mixing of both types (some fields use TPA-specific, others use global)

## Field Mappings with TPA

### Table Schema

```sql
CREATE TABLE field_mappings (
    mapping_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_field VARCHAR(500) NOT NULL,
    source_table VARCHAR(500) DEFAULT 'RAW_DATA_TABLE',
    target_table VARCHAR(500) NOT NULL,
    target_column VARCHAR(500) NOT NULL,
    tpa VARCHAR(500),  -- NULL = applies to all TPAs, specific value = TPA-specific
    mapping_method VARCHAR(50) NOT NULL,
    confidence_score FLOAT,
    transformation_logic VARCHAR(5000),
    approved BOOLEAN DEFAULT FALSE,
    ...
);
```

### Examples

#### Global Mapping (applies to all providers)
```sql
INSERT INTO field_mappings (
    source_field, target_table, target_column, tpa,
    transformation_logic, mapping_method, confidence_score, approved
) VALUES (
    'CLAIM_ID', 'CLAIMS', 'CLAIM_NUMBER', NULL,  -- NULL = global
    'TRIM(source_value)', 'MANUAL', 1.0, TRUE
);
```

#### TPA-Specific Mapping (Provider A uses different field name)
```sql
INSERT INTO field_mappings (
    source_field, target_table, target_column, tpa,
    transformation_logic, mapping_method, confidence_score, approved
) VALUES (
    'PAT_FNAME', 'CLAIMS', 'PATIENT_FIRST_NAME', 'provider_a',  -- Provider A specific
    'UPPER(TRIM(source_value))', 'MANUAL', 1.0, TRUE
);

INSERT INTO field_mappings (
    source_field, target_table, target_column, tpa,
    transformation_logic, mapping_method, confidence_score, approved
) VALUES (
    'MEMBER_FIRST_NAME', 'CLAIMS', 'PATIENT_FIRST_NAME', 'provider_b',  -- Provider B specific
    'UPPER(TRIM(source_value))', 'MANUAL', 1.0, TRUE
);
```

### CSV Format for Field Mappings

```csv
source_field,target_table,target_column,transformation_logic,mapping_method,confidence_score,approved,notes,tpa
PAT_FNAME,CLAIMS,PATIENT_FIRST_NAME,UPPER(TRIM(source_value)),MANUAL,1.0,TRUE,Provider A - Patient first name,provider_a
MEMBER_FIRST_NAME,CLAIMS,PATIENT_FIRST_NAME,UPPER(TRIM(source_value)),MANUAL,1.0,TRUE,Provider B - Member first name,provider_b
CLAIM_ID,CLAIMS,CLAIM_NUMBER,TRIM(source_value),MANUAL,1.0,TRUE,Global mapping for all providers,
```

**Note**: Empty TPA column = NULL = global mapping

## Transformation Rules with TPA

### Table Schema

```sql
CREATE TABLE transformation_rules (
    rule_id VARCHAR(50) PRIMARY KEY,
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    target_table VARCHAR(500),
    target_column VARCHAR(500),
    tpa VARCHAR(500),  -- NULL = applies to all TPAs
    rule_logic VARCHAR(5000) NOT NULL,
    rule_parameters VARIANT,
    priority INTEGER DEFAULT 100,
    error_action VARCHAR(50) DEFAULT 'LOG',
    active BOOLEAN DEFAULT TRUE,
    ...
);
```

### Examples

#### Global Rule (applies to all providers)
```sql
INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, target_table, target_column, tpa,
    rule_logic, priority, error_action, active
) VALUES (
    'DQ001', 'Validate First Name Not Null', 'DATA_QUALITY', 
    'CLAIMS', 'FIRST_NAME', NULL,  -- NULL = global
    'IS NOT NULL', 10, 'REJECT', TRUE
);
```

#### TPA-Specific Rule (Provider A has different validation)
```sql
INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, target_table, target_column, tpa,
    rule_logic, priority, error_action, active
) VALUES (
    'DQ_PA_001', 'Validate Provider A Claim Format', 'DATA_QUALITY',
    'CLAIMS', 'CLAIM_NUM', 'provider_a',  -- Provider A specific
    'RLIKE ''^AET[0-9]{9}$''', 30, 'QUARANTINE', TRUE
);

INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, target_table, target_column, tpa,
    rule_logic, priority, error_action, active
) VALUES (
    'DQ_PB_001', 'Validate Provider B Claim Format', 'DATA_QUALITY',
    'CLAIMS', 'CLAIM_NUM', 'provider_b',  -- Provider B specific
    'RLIKE ''^ANT[0-9]{9}$''', 30, 'QUARANTINE', TRUE
);
```

### CSV Format for Transformation Rules

```csv
rule_id,rule_name,rule_type,target_table,target_column,rule_logic,rule_parameters,priority,error_action,description,active,tpa
DQ001,Validate First Name Not Null,DATA_QUALITY,CLAIMS,FIRST_NAME,IS NOT NULL,,10,REJECT,Global validation,TRUE,
DQ_PA_001,Validate Provider A Claim Format,DATA_QUALITY,CLAIMS,CLAIM_NUM,RLIKE '^AET[0-9]{9}$',,30,QUARANTINE,Provider A specific,TRUE,provider_a
DQ_PB_001,Validate Provider B Claim Format,DATA_QUALITY,CLAIMS,CLAIM_NUM,RLIKE '^ANT[0-9]{9}$',,30,QUARANTINE,Provider B specific,TRUE,provider_b
```

## Querying TPA-Aware Data

### View All Mappings by TPA
```sql
SELECT * FROM v_field_mappings_by_tpa
ORDER BY tpa, target_table;
```

### View All Rules by TPA
```sql
SELECT * FROM v_transformation_rules_by_tpa
ORDER BY tpa, priority;
```

### Check Mapping Coverage for Specific TPA
```sql
SELECT 
    table_name,
    column_name,
    mapping_type,
    mapping_count
FROM v_mapping_coverage_by_tpa
WHERE TPA = 'provider_a'
AND mapping_type = 'Unmapped';
```

### Get Effective Mappings for a TPA (with fallback to global)
```sql
-- This query shows what mappings will be used for provider_a
-- TPA-specific mappings take precedence over global ones
WITH tpa_specific AS (
    SELECT * FROM field_mappings
    WHERE tpa = 'provider_a' AND approved = TRUE
),
global_mappings AS (
    SELECT * FROM field_mappings
    WHERE tpa IS NULL AND approved = TRUE
)
SELECT 
    COALESCE(ts.source_field, gm.source_field) AS source_field,
    COALESCE(ts.target_table, gm.target_table) AS target_table,
    COALESCE(ts.target_column, gm.target_column) AS target_column,
    CASE 
        WHEN ts.mapping_id IS NOT NULL THEN 'TPA-Specific'
        ELSE 'Global'
    END AS mapping_source,
    COALESCE(ts.transformation_logic, gm.transformation_logic) AS transformation_logic
FROM tpa_specific ts
FULL OUTER JOIN global_mappings gm
    ON ts.target_table = gm.target_table
    AND ts.target_column = gm.target_column
WHERE ts.mapping_id IS NOT NULL OR gm.mapping_id IS NOT NULL;
```

## Use Cases

### Use Case 1: Different Field Names

**Scenario**: Provider A calls it `PAT_FNAME`, Provider B calls it `MEMBER_FIRST_NAME`

**Solution**:
```sql
-- Provider A mapping
INSERT INTO field_mappings VALUES (
    ..., 'PAT_FNAME', 'CLAIMS', 'PATIENT_FIRST_NAME', 'provider_a', ...
);

-- Provider B mapping
INSERT INTO field_mappings VALUES (
    ..., 'MEMBER_FIRST_NAME', 'CLAIMS', 'PATIENT_FIRST_NAME', 'provider_b', ...
);
```

### Use Case 2: Different Date Formats

**Scenario**: Provider A uses `MM-DD-YYYY`, Provider B uses `YYYY-MM-DD`

**Solution**:
```sql
-- Provider A mapping
INSERT INTO field_mappings VALUES (
    ..., 'SERVICE_DATE', 'CLAIMS', 'SERVICE_DATE', 'provider_a',
    'TO_DATE(source_value, ''MM-DD-YYYY'')', ...
);

-- Provider B mapping
INSERT INTO field_mappings VALUES (
    ..., 'SERVICE_DATE', 'CLAIMS', 'SERVICE_DATE', 'provider_b',
    'TO_DATE(source_value, ''YYYY-MM-DD'')', ...
);
```

### Use Case 3: Provider-Specific Validation

**Scenario**: Each provider has different claim number formats

**Solution**:
```sql
-- Provider A: AET prefix + 9 digits
INSERT INTO transformation_rules VALUES (
    'DQ_PA_CLM', ..., 'provider_a', 'RLIKE ''^AET[0-9]{9}$''', ...
);

-- Provider B: ANT prefix + 9 digits
INSERT INTO transformation_rules VALUES (
    'DQ_PB_CLM', ..., 'provider_b', 'RLIKE ''^ANT[0-9]{9}$''', ...
);
```

### Use Case 4: Mixed Global and TPA-Specific

**Scenario**: Most fields are the same, but a few differ by provider

**Solution**:
```sql
-- Global mappings for common fields (80% of fields)
INSERT INTO field_mappings VALUES (..., NULL, ...);  -- TPA = NULL

-- TPA-specific mappings only for unique fields (20% of fields)
INSERT INTO field_mappings VALUES (..., 'provider_a', ...);
INSERT INTO field_mappings VALUES (..., 'provider_b', ...);
```

## Best Practices

### 1. Start with Global Mappings
Create global mappings first for fields that are consistent across all providers. Only create TPA-specific mappings when necessary.

### 2. Use Consistent TPA Values
Ensure TPA values in Bronze match exactly with TPA values in mappings:
- Bronze: `TPA = 'provider_a'`
- Mapping: `tpa = 'provider_a'`
- Case-sensitive match required

### 3. Document TPA-Specific Logic
Use the `description` or `notes` field to explain why a TPA-specific mapping/rule is needed.

### 4. Test with Each TPA
When adding new mappings or rules, test with data from each TPA to ensure:
- TPA-specific mappings work correctly
- Global mappings don't conflict
- Fallback logic works as expected

### 5. Monitor Coverage
Regularly check `v_mapping_coverage_by_tpa` to ensure all TPAs have complete mapping coverage.

### 6. Version Control
Keep your CSV configuration files in version control and document changes by TPA.

## Loading TPA-Aware Configurations

### From CSV Files

```sql
-- Load field mappings (includes TPA column)
CALL load_field_mappings_from_csv('@SILVER_CONFIG/silver_field_mappings.csv');

-- Load transformation rules (includes TPA column)
CALL load_transformation_rules_from_csv('@SILVER_CONFIG/silver_transformation_rules.csv');
```

### Verify Loaded Configurations

```sql
-- Check mappings by TPA
SELECT tpa, COUNT(*) AS mapping_count
FROM field_mappings
WHERE approved = TRUE
GROUP BY tpa
ORDER BY tpa NULLS FIRST;

-- Check rules by TPA
SELECT tpa, rule_type, COUNT(*) AS rule_count
FROM transformation_rules
WHERE active = TRUE
GROUP BY tpa, rule_type
ORDER BY tpa NULLS FIRST, rule_type;
```

## Troubleshooting

### Issue: Mappings not being applied for specific TPA

**Check**:
1. Verify TPA value in Bronze matches mapping TPA exactly (case-sensitive)
2. Ensure mapping is approved (`approved = TRUE`)
3. Check if global mapping exists and is being used instead

```sql
-- Debug query
SELECT 
    b.TPA AS bronze_tpa,
    fm.tpa AS mapping_tpa,
    fm.source_field,
    fm.target_column,
    fm.approved
FROM BRONZE.RAW_DATA_TABLE b
LEFT JOIN field_mappings fm
    ON (fm.tpa = b.TPA OR fm.tpa IS NULL)
WHERE b.TPA = 'provider_a'
LIMIT 10;
```

### Issue: Conflicting mappings for same field

**Check**:
```sql
-- Find duplicate mappings
SELECT 
    source_field,
    target_table,
    target_column,
    tpa,
    COUNT(*) AS mapping_count
FROM field_mappings
WHERE approved = TRUE
GROUP BY source_field, target_table, target_column, tpa
HAVING COUNT(*) > 1;
```

### Issue: Rules not being applied

**Check**:
1. Verify rule is active (`active = TRUE`)
2. Check priority order
3. Ensure TPA matches

```sql
-- View effective rules for a TPA
SELECT 
    rule_id,
    rule_name,
    COALESCE(tpa, 'GLOBAL') AS tpa,
    priority,
    active
FROM transformation_rules
WHERE (tpa = 'provider_a' OR tpa IS NULL)
AND active = TRUE
ORDER BY priority;
```

## Migration Guide

### Updating Existing Mappings to Support TPA

If you have existing field mappings without TPA support:

```sql
-- Add TPA column (already done in schema update)
ALTER TABLE field_mappings ADD COLUMN tpa VARCHAR(500);

-- Update unique constraint to include TPA
ALTER TABLE field_mappings DROP CONSTRAINT uk_field_mappings;
ALTER TABLE field_mappings ADD CONSTRAINT uk_field_mappings 
    UNIQUE (source_field, source_table, target_table, target_column, COALESCE(tpa, 'ALL'));

-- Existing mappings will have TPA = NULL (global)
-- Add TPA-specific mappings as needed
```

## Summary

The TPA-aware mapping system provides:

✅ **Flexibility**: Handle provider-specific data formats within one pipeline  
✅ **Maintainability**: Clear separation of global vs. provider-specific logic  
✅ **Scalability**: Easy to add new providers without affecting existing ones  
✅ **Fallback**: Automatic use of global mappings when TPA-specific don't exist  
✅ **Visibility**: Views and queries to monitor coverage by provider  

This architecture enables a single Silver layer to handle multiple data sources with different formats, field names, and business rules efficiently.
