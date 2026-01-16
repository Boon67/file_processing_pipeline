# TPA (Third Party Administrator) - Complete Guide

**Last Updated**: January 15, 2026  
**Version**: 1.0

## 📖 Table of Contents

1. [Overview](#overview)
2. [TPA Architecture](#tpa-architecture)
3. [Table Naming Strategy](#table-naming-strategy)
4. [Quick Start](#quick-start)
5. [Configuration](#configuration)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The Snowflake File Processing Pipeline is designed with **TPA (Third Party Administrator)** as a first-class organizing principle. This means that all mappings, rules, and transformations are TPA-specific, allowing different providers to have completely different data structures, business rules, and quality standards.

### Why TPA-Aware Architecture?

Different TPAs (healthcare providers, insurance administrators, etc.) have:
- **Different field naming conventions** (e.g., "PAT_FNAME" vs "PATIENT_FIRST_NAME")
- **Different data formats** (date formats, numeric precision, etc.)
- **Different business rules** (validation logic, calculation methods)
- **Different quality standards** (required fields, acceptable ranges)
- **Different target schema requirements** (some may need additional fields)

### Key Benefits

By making TPA a core dimension, we enable:

1. **🔐 Isolated Configuration**: Each TPA's mappings and rules are independent
2. **⚡ Parallel Processing**: Different TPAs can be processed simultaneously
3. **🔄 Flexible Evolution**: TPAs can evolve their schemas independently
4. **📊 Clear Governance**: Easy to audit and manage TPA-specific transformations
5. **🎯 Navigation-Level Selection**: Select TPA once, applies to all operations

---

## TPA Architecture

### TPA-Aware Tables

All Silver layer metadata tables include a `tpa` column as part of their unique constraints:

#### 1. `target_schemas` Table

Defines the target Silver table structures **per TPA**.

```sql
CREATE TABLE target_schemas (
    schema_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(500) NOT NULL,
    column_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- TPA identifier
    data_type VARCHAR(200) NOT NULL,
    nullable BOOLEAN DEFAULT TRUE,
    default_value VARCHAR(1000),
    description VARCHAR(5000),
    ...
    CONSTRAINT uk_target_schemas UNIQUE (table_name, column_name, tpa)
)
```

**Key Points:**
- Same logical table (e.g., `CLAIMS`) can have different schemas for different TPAs
- TPA is part of the unique constraint
- Allows TPA-specific columns or data types

**Example:**
```
table_name | column_name | tpa        | data_type
-----------+-------------+------------+-----------
CLAIMS     | CLAIM_NUM   | provider_a | VARCHAR(100)
CLAIMS     | CLAIM_NUM   | provider_b | VARCHAR(50)
CLAIMS     | DIAGNOSIS   | provider_a | VARCHAR(500)
```

#### 2. `field_mappings` Table

Maps Bronze source fields to Silver target columns **per TPA**.

```sql
CREATE TABLE field_mappings (
    mapping_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_field VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    target_column VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- TPA identifier
    mapping_method VARCHAR(50),
    transformation_logic VARCHAR(5000),
    confidence_score FLOAT,
    approved BOOLEAN DEFAULT FALSE,
    ...
    CONSTRAINT uk_field_mappings UNIQUE (source_field, target_table, target_column, tpa)
)
```

**Key Points:**
- Same source field can map to different target columns for different TPAs
- Each TPA has independent mapping approvals
- Confidence scores help prioritize review

**Example:**
```
source_field | target_table | target_column | tpa        | mapping_method
-------------+--------------+---------------+------------+---------------
PAT_FNAME    | CLAIMS       | FIRST_NAME    | provider_a | MANUAL
PATIENT_NAME | CLAIMS       | FIRST_NAME    | provider_b | ML_AUTO
```

#### 3. `transformation_rules` Table

Defines data quality and business rules **per TPA**.

```sql
CREATE TABLE transformation_rules (
    rule_id VARCHAR(100) PRIMARY KEY,
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    target_table VARCHAR(500),
    target_column VARCHAR(500),
    tpa VARCHAR(500) NOT NULL,  -- TPA identifier
    rule_logic VARCHAR(5000) NOT NULL,
    error_action VARCHAR(50) DEFAULT 'REJECT',
    priority NUMBER(38,0) DEFAULT 100,
    active BOOLEAN DEFAULT TRUE,
    ...
    CONSTRAINT uk_transformation_rules UNIQUE (rule_id, tpa)
)
```

**Key Points:**
- Different validation rules per TPA
- Different error handling strategies
- TPA-specific business logic

**Example:**
```
rule_id | rule_name       | tpa        | rule_logic
--------+-----------------+------------+---------------------------
DQ001   | Email Required  | provider_a | EMAIL IS NOT NULL
DQ001   | Email Optional  | provider_b | TRUE  -- No validation
```

### TPA Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Bronze Layer (TPA-Aware)                  │
│  Files organized by TPA folder:                              │
│  @SRC/provider_a/claims.csv                                  │
│  @SRC/provider_b/claims.csv                                  │
│  ↓                                                            │
│  RAW_DATA_TABLE (TPA column extracted from file path)        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Silver Layer (TPA-Aware)                  │
│  ┌────────────────────────────────────────────────────┐     │
│  │ 1. TPA Selection (Navigation Level)                │     │
│  │    User selects TPA → Applies to all operations    │     │
│  └────────────────────────────────────────────────────┘     │
│                            ↓                                 │
│  ┌────────────────────────────────────────────────────┐     │
│  │ 2. Field Mapping (TPA-Specific)                    │     │
│  │    Load mappings WHERE tpa = 'provider_a'          │     │
│  └────────────────────────────────────────────────────┘     │
│                            ↓                                 │
│  ┌────────────────────────────────────────────────────┐     │
│  │ 3. Rules Engine (TPA-Specific)                     │     │
│  │    Apply rules WHERE tpa = 'provider_a'            │     │
│  └────────────────────────────────────────────────────┘     │
│                            ↓                                 │
│  ┌────────────────────────────────────────────────────┐     │
│  │ 4. Target Tables (TPA-Specific)                    │     │
│  │    CLAIMS_PROVIDER_A, CLAIMS_PROVIDER_B            │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## Table Naming Strategy

### Recommended Pattern

For complete TPA isolation, target tables in the Silver layer should be **TPA-specific**:

```
{TABLE_NAME}_{TPA_CODE}
```

### Examples

- `CLAIMS_PROVIDER_A` - Claims table for Provider A
- `CLAIMS_PROVIDER_B` - Claims table for Provider B
- `PATIENT_DEMOGRAPHICS_PROVIDER_A` - Patient demographics for Provider A
- `PROVIDER_DIRECTORY_PROVIDER_B` - Provider directory for Provider B

### Benefits

#### Complete Data Isolation
- ✅ **Physical Separation**: Each TPA's data is in a separate table
- ✅ **Security**: Easier to implement row-level security and access controls
- ✅ **Performance**: Queries only scan relevant TPA's data
- ✅ **Schema Evolution**: TPAs can have different schemas without conflicts

#### Operational Advantages
- ✅ **Independent Maintenance**: Rebuild/optimize one TPA without affecting others
- ✅ **Selective Processing**: Transform only specific TPA's data
- ✅ **Clear Ownership**: Table name immediately identifies the TPA
- ✅ **Easier Troubleshooting**: Issues isolated to specific tables

#### Business Benefits
- ✅ **Compliance**: Easier to demonstrate data segregation for audits
- ✅ **SLA Management**: Different SLAs per TPA
- ✅ **Cost Allocation**: Track storage/compute costs per TPA
- ✅ **Data Retention**: Different retention policies per TPA

### Implementation

When defining target schemas, include the TPA in the table name:

```csv
table_name,column_name,tpa,data_type,nullable,default_value,description
CLAIMS_PROVIDER_A,CLAIM_NUM,provider_a,VARCHAR(100),TRUE,,Unique claim number
CLAIMS_PROVIDER_A,FIRST_NAME,provider_a,VARCHAR(100),TRUE,,Patient first name
CLAIMS_PROVIDER_B,CLAIM_ID,provider_b,VARCHAR(50),TRUE,,Claim identifier
CLAIMS_PROVIDER_B,PATIENT_NAME,provider_b,VARCHAR(200),TRUE,,Full patient name
```

### Alternative: Shared Tables with TPA Column

If you prefer shared tables (not recommended for production):

```sql
CREATE TABLE CLAIMS (
    claim_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    tpa VARCHAR(500) NOT NULL,  -- TPA identifier
    claim_num VARCHAR(100),
    first_name VARCHAR(100),
    ...
    -- Add TPA to clustering/partitioning
    CLUSTER BY (tpa, claim_date)
)
```

**Trade-offs:**
- ✅ Simpler table management (fewer tables)
- ✅ Easier cross-TPA analytics
- ❌ Performance: All queries scan all TPAs unless filtered
- ❌ Security: Requires row-level security policies
- ❌ Schema conflicts: All TPAs must have same schema
- ❌ Maintenance: Changes affect all TPAs

---

## Quick Start

### 1. Add a New TPA

#### Step 1: Define Target Schema

```sql
USE DATABASE DB_INGEST_PIPELINE;
USE SCHEMA SILVER;

-- Define table structure for new TPA
INSERT INTO target_schemas (table_name, column_name, tpa, data_type, nullable, description)
VALUES 
    ('CLAIMS', 'CLAIM_NUM', 'provider_c', 'VARCHAR(100)', TRUE, 'Unique claim number'),
    ('CLAIMS', 'FIRST_NAME', 'provider_c', 'VARCHAR(100)', TRUE, 'Patient first name'),
    ('CLAIMS', 'LAST_NAME', 'provider_c', 'VARCHAR(100)', TRUE, 'Patient last name');

-- Create the target table
CALL create_silver_table('CLAIMS', 'provider_c');
```

#### Step 2: Upload Files

Upload files to Bronze stage with TPA folder structure:

```bash
# Via CLI
snow sql -q "PUT file:///path/to/claims.csv @DB_INGEST_PIPELINE.BRONZE.SRC/provider_c/;"

# Or via Streamlit
# 1. Open Bronze Ingestion Pipeline
# 2. Upload files to provider_c folder
```

#### Step 3: Create Field Mappings

**Option A: Manual Mapping**
```sql
INSERT INTO field_mappings (source_field, target_table, target_column, tpa, mapping_method, approved)
VALUES 
    ('CLAIM_NUMBER', 'CLAIMS', 'CLAIM_NUM', 'provider_c', 'MANUAL', TRUE),
    ('PAT_FNAME', 'CLAIMS', 'FIRST_NAME', 'provider_c', 'MANUAL', TRUE);
```

**Option B: ML Auto-Mapping**
```sql
-- Generate ML-based mappings
CALL auto_map_fields_ml('RAW_DATA_TABLE', 'provider_c', 3, 0.6);

-- Review and approve
SELECT * FROM field_mappings WHERE tpa = 'provider_c' AND mapping_method = 'ML_AUTO';
CALL approve_mappings_for_table('CLAIMS', 'provider_c', 0.8);
```

**Option C: LLM Mapping (via Streamlit)**
1. Open Silver Transformation Manager
2. Select TPA: `provider_c`
3. Go to "Field Mapper" tab
4. Click "Generate LLM Mappings"
5. Review and approve mappings

#### Step 4: Define Transformation Rules

```sql
-- Data quality rule
INSERT INTO transformation_rules (rule_id, rule_name, rule_type, target_column, tpa, rule_logic, priority)
VALUES 
    ('DQ001', 'Claim Number Required', 'DATA_QUALITY', 'CLAIM_NUM', 'provider_c', 'CLAIM_NUM IS NOT NULL', 1),
    ('DQ002', 'Name Required', 'DATA_QUALITY', 'FIRST_NAME', 'provider_c', 'FIRST_NAME IS NOT NULL', 1);
```

#### Step 5: Run Transformation

```sql
-- Transform Bronze to Silver for this TPA
CALL transform_bronze_to_silver(
    'RAW_DATA_TABLE',  -- source table
    'CLAIMS',          -- target table
    'provider_c',      -- TPA
    'BRONZE',          -- source schema
    10000,             -- batch size
    TRUE,              -- apply rules
    TRUE               -- incremental
);

-- Check results
SELECT * FROM CLAIMS_PROVIDER_C LIMIT 10;
```

### 2. View TPA-Specific Data

```sql
-- List all TPAs
SELECT DISTINCT tpa FROM target_schemas ORDER BY tpa;

-- View mappings for a TPA
SELECT * FROM field_mappings WHERE tpa = 'provider_a';

-- View rules for a TPA
SELECT * FROM transformation_rules WHERE tpa = 'provider_a' AND active = TRUE;

-- View data for a TPA
SELECT * FROM CLAIMS_PROVIDER_A LIMIT 100;
```

### 3. Manage TPA Configuration

```sql
-- Update mapping for a TPA
UPDATE field_mappings 
SET transformation_logic = 'UPPER(source_field)'
WHERE tpa = 'provider_a' AND target_column = 'FIRST_NAME';

-- Disable rule for a TPA
UPDATE transformation_rules
SET active = FALSE
WHERE tpa = 'provider_b' AND rule_id = 'DQ001';

-- Delete TPA configuration (careful!)
DELETE FROM field_mappings WHERE tpa = 'old_provider';
DELETE FROM transformation_rules WHERE tpa = 'old_provider';
DELETE FROM target_schemas WHERE tpa = 'old_provider';
```

---

## Configuration

### TPA Identification

TPAs are identified in two ways:

#### 1. File Path (Bronze Layer)

Files uploaded to Bronze stage should be organized in TPA-specific folders:

```
@SRC/
├── provider_a/
│   ├── claims-20240301.csv
│   └── claims-20240401.csv
├── provider_b/
│   ├── medical-claims-20240115.csv
│   └── dental-claims-20240215.csv
└── provider_c/
    └── claims-20240301.xlsx
```

The TPA is automatically extracted from the file path and stored in `RAW_DATA_TABLE.TPA` column.

#### 2. Metadata Tables (Silver Layer)

All Silver metadata tables include a `tpa` column:
- `target_schemas.tpa`
- `field_mappings.tpa`
- `transformation_rules.tpa`
- `data_quality_metrics.tpa`

### Configuration Files

TPA-specific configurations can be loaded from CSV files:

#### Target Schemas CSV

```csv
table_name,column_name,tpa,data_type,nullable,default_value,description
CLAIMS,CLAIM_NUM,provider_a,VARCHAR(100),TRUE,,Unique claim number
CLAIMS,FIRST_NAME,provider_a,VARCHAR(100),TRUE,,Patient first name
```

Load with:
```sql
COPY INTO target_schemas (table_name, column_name, tpa, data_type, nullable, default_value, description)
FROM @SILVER_CONFIG/target_schemas_provider_a.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);
```

#### Field Mappings CSV

```csv
source_field,target_table,target_column,tpa,mapping_method,transformation_logic,approved
CLAIM_NUMBER,CLAIMS,CLAIM_NUM,provider_a,MANUAL,,TRUE
PAT_FNAME,CLAIMS,FIRST_NAME,provider_a,MANUAL,UPPER,TRUE
```

Load with:
```sql
COPY INTO field_mappings (source_field, target_table, target_column, tpa, mapping_method, transformation_logic, approved)
FROM @SILVER_CONFIG/field_mappings_provider_a.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);
```

#### Transformation Rules CSV

```csv
rule_id,rule_name,rule_type,target_column,tpa,rule_logic,error_action,priority
DQ001,Claim Required,DATA_QUALITY,CLAIM_NUM,provider_a,CLAIM_NUM IS NOT NULL,REJECT,1
STD001,Uppercase Name,STANDARDIZATION,FIRST_NAME,provider_a,UPPER,CORRECT,10
```

Load with:
```sql
COPY INTO transformation_rules (rule_id, rule_name, rule_type, target_column, tpa, rule_logic, error_action, priority)
FROM @SILVER_CONFIG/transformation_rules_provider_a.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);
```

---

## Best Practices

### 1. TPA Naming Conventions

✅ **DO:**
- Use lowercase with underscores: `provider_a`, `blue_cross`, `united_health`
- Keep names short but descriptive
- Use consistent naming across all systems
- Document TPA codes in a central registry

❌ **DON'T:**
- Use spaces: `Provider A` (breaks SQL queries)
- Use special characters: `provider-a`, `provider.a`
- Use uppercase: `PROVIDER_A` (inconsistent)
- Use generic names: `tpa1`, `tpa2`

### 2. Schema Design

✅ **DO:**
- Use TPA-specific tables: `CLAIMS_PROVIDER_A`
- Include TPA in all metadata unique constraints
- Document TPA-specific schema differences
- Version control TPA configurations

❌ **DON'T:**
- Share tables without TPA column (performance issues)
- Hardcode TPA values in procedures (use parameters)
- Mix TPA data without proper isolation
- Skip TPA validation in transformations

### 3. Field Mapping

✅ **DO:**
- Start with manual mappings for critical fields
- Use ML for bulk auto-suggestions
- Use LLM for complex semantic mappings
- Always review and approve mappings
- Document mapping rationale

❌ **DON'T:**
- Auto-approve all mappings without review
- Skip confidence score validation
- Map incompatible data types
- Ignore transformation logic requirements

### 4. Transformation Rules

✅ **DO:**
- Define TPA-specific validation rules
- Use appropriate error actions (REJECT/QUARANTINE/FLAG/CORRECT)
- Set meaningful priorities
- Test rules before production
- Document business logic

❌ **DON'T:**
- Apply same rules to all TPAs (they differ!)
- Use REJECT for all failures (too strict)
- Skip rule testing
- Create overly complex rules
- Ignore rule performance impact

### 5. Data Quality

✅ **DO:**
- Monitor quality metrics per TPA
- Set TPA-specific quality thresholds
- Review quarantined records regularly
- Track quality trends over time
- Alert on quality degradation

❌ **DON'T:**
- Use same quality standards for all TPAs
- Ignore quarantined records
- Skip quality metric reviews
- Auto-correct without validation
- Overlook data quality trends

### 6. Operations

✅ **DO:**
- Process TPAs independently
- Use incremental processing
- Monitor performance per TPA
- Schedule transformations appropriately
- Maintain audit trails

❌ **DON'T:**
- Process all TPAs in single batch (too slow)
- Skip incremental processing (reprocesses everything)
- Ignore performance metrics
- Run transformations during peak hours
- Skip audit logging

---

## Troubleshooting

### Issue 1: TPA Not Showing in Dropdown

**Symptom:** TPA doesn't appear in Streamlit dropdown

**Diagnosis:**
```sql
-- Check if TPA exists in target_schemas
SELECT DISTINCT tpa FROM target_schemas ORDER BY tpa;

-- Check if TPA has any tables defined
SELECT table_name, COUNT(*) as column_count
FROM target_schemas
WHERE tpa = 'your_tpa'
GROUP BY table_name;
```

**Solution:**
- Ensure TPA is defined in `target_schemas` table
- Verify table definitions are complete
- Refresh Streamlit app

### Issue 2: Mappings Not Working for TPA

**Symptom:** Transformation fails or produces no results

**Diagnosis:**
```sql
-- Check if mappings exist for TPA
SELECT COUNT(*) as mapping_count
FROM field_mappings
WHERE tpa = 'your_tpa' AND approved = TRUE;

-- Check mapping details
SELECT source_field, target_table, target_column, mapping_method, confidence_score
FROM field_mappings
WHERE tpa = 'your_tpa'
ORDER BY confidence_score DESC;
```

**Solution:**
- Create mappings for the TPA
- Approve mappings (set `approved = TRUE`)
- Verify source fields match Bronze data

### Issue 3: Rules Not Applied

**Symptom:** Data quality issues not caught

**Diagnosis:**
```sql
-- Check if rules exist and are active
SELECT rule_id, rule_name, rule_type, active
FROM transformation_rules
WHERE tpa = 'your_tpa';

-- Check rule logic
SELECT rule_id, rule_name, rule_logic, error_action
FROM transformation_rules
WHERE tpa = 'your_tpa' AND active = TRUE;
```

**Solution:**
- Create rules for the TPA
- Activate rules (set `active = TRUE`)
- Verify rule logic is correct
- Check error action is appropriate

### Issue 4: Target Table Not Created

**Symptom:** Table doesn't exist for TPA

**Diagnosis:**
```sql
-- Check if schema is defined
SELECT COUNT(*) as column_count
FROM target_schemas
WHERE table_name = 'CLAIMS' AND tpa = 'your_tpa';

-- Check if table exists
SHOW TABLES LIKE 'CLAIMS_YOUR_TPA' IN SCHEMA SILVER;
```

**Solution:**
```sql
-- Define schema if missing
INSERT INTO target_schemas (table_name, column_name, tpa, data_type, nullable, description)
VALUES ('CLAIMS', 'CLAIM_NUM', 'your_tpa', 'VARCHAR(100)', TRUE, 'Claim number');

-- Create table
CALL create_silver_table('CLAIMS', 'your_tpa');
```

### Issue 5: Performance Issues

**Symptom:** Transformations are slow

**Diagnosis:**
```sql
-- Check batch sizes
SELECT batch_id, record_count, 
       DATEDIFF('second', start_time, end_time) as duration_seconds
FROM silver_processing_log
WHERE tpa = 'your_tpa'
ORDER BY start_time DESC
LIMIT 10;

-- Check rule complexity
SELECT rule_id, rule_name, LENGTH(rule_logic) as logic_length
FROM transformation_rules
WHERE tpa = 'your_tpa' AND active = TRUE
ORDER BY logic_length DESC;
```

**Solutions:**
- Reduce batch size if too large
- Optimize complex rules
- Use appropriate warehouse size
- Enable incremental processing
- Add indexes on TPA column

### Issue 6: Data Not Isolated

**Symptom:** Seeing data from other TPAs

**Diagnosis:**
```sql
-- Check if TPA filter is applied
SELECT tpa, COUNT(*) as record_count
FROM CLAIMS_YOUR_TPA
GROUP BY tpa;

-- Should only show one TPA if using TPA-specific tables
```

**Solution:**
- Use TPA-specific tables (recommended)
- If using shared tables, always filter by TPA
- Verify transformation procedures include TPA filter
- Check row-level security policies

---

## Related Documentation

- **[Main README](../../README.md)** - Project overview
- **[User Guide](../USER_GUIDE.md)** - Complete user guide
- **[Bronze Layer](../../bronze/README.md)** - Bronze layer documentation
- **[Silver Layer](../../silver/README.md)** - Silver layer documentation
- **[Architecture](../design/ARCHITECTURE.md)** - System architecture

---

**Version**: 1.0  
**Last Updated**: January 15, 2026  
**Status**: ✅ Complete

**Consolidated from:**
- `docs/TPA_ARCHITECTURE.md`
- `docs/TPA_TABLE_NAMING_STRATEGY.md`
- `docs/guides/TPA_DATABASE_QUICKSTART.md`
