# Silver Layer Configuration Files

This folder contains pre-configured CSV files that define the Silver layer metadata, including target schemas, field mappings, transformation rules, data quality metrics, and LLM prompts.

## 📁 Files

### 1. Target Schema Definitions
**File**: `silver_target_schemas.csv`  
**Purpose**: Define standardized target tables for the Silver layer  
**Records**: 56 column definitions across 4 tables  

**Tables Defined**:
- `CLAIMS` (29 columns) - Unified claims table
- `PATIENT_DEMOGRAPHICS` (9 columns) - Patient master data
- `PROVIDER_DIRECTORY` (9 columns) - Provider reference data
- `CLAIM_SUMMARY` (9 columns) - Aggregated metrics

**Columns**:
- `table_name` - Target table name
- `column_name` - Column name
- `data_type` - Snowflake data type (e.g., VARCHAR(100), NUMBER(15,2), DATE)
- `description` - Column description

---

### 2. Field Mappings
**File**: `silver_field_mappings.csv`  
**Purpose**: Map source fields from Bronze to target fields in Silver  
**Records**: 73 field mappings  

**Coverage**:
- Aetna Dental: 23 mappings
- Anthem BlueCross: 29 mappings
- UnitedHealth: 21 mappings

**Columns**:
- `source_table` - Source table in Bronze (e.g., RAW_DATA_TABLE)
- `source_field` - Source field name
- `target_table` - Target table in Silver
- `target_column` - Target column name
- `transformation_logic` - SQL transformation expression
- `mapping_method` - Method used (MANUAL, ML, LLM_CORTEX)
- `confidence_score` - Confidence level (0.0 to 1.0)
- `approved` - Whether mapping is approved (TRUE/FALSE)
- `active` - Whether mapping is active (TRUE/FALSE)
- `notes` - Additional notes

---

### 3. Transformation Rules
**File**: `silver_transformation_rules.csv`  
**Purpose**: Define data quality and transformation rules  
**Records**: 47 rules across 5 categories  

**Rule Categories**:
- **DATA_QUALITY** (18 rules) - Validation rules
- **STANDARDIZATION** (10 rules) - Data standardization
- **BUSINESS_LOGIC** (10 rules) - Business calculations
- **DEDUPLICATION** (4 rules) - Duplicate detection
- **REFERENTIAL_INTEGRITY** (5 rules) - Relationship validation

**Columns**:
- `rule_id` - Unique rule identifier
- `rule_name` - Descriptive rule name
- `rule_type` - Category (DQ, STD, BL, DD, REF)
- `target_table` - Table to apply rule to
- `target_column` - Column to validate (or NULL for row-level)
- `rule_logic` - SQL expression for validation
- `priority` - Execution order (1-1000)
- `error_action` - Action on failure (REJECT, QUARANTINE, FLAG, CORRECT)
- `enabled` - Whether rule is active (TRUE/FALSE)
- `description` - Rule description

---

### 4. Data Quality Metrics
**File**: `silver_data_quality_metrics.csv`  
**Purpose**: Define automated data quality measurements  
**Records**: 20 metrics across 8 dimensions  

**Metric Dimensions**:
- **Completeness** - Field population rates
- **Validity** - Format and range checks
- **Consistency** - Cross-field logic
- **Uniqueness** - Duplicate detection
- **Timeliness** - Processing time checks
- **Accuracy** - Value domain validation
- **Reasonableness** - Outlier detection
- **Coverage** - Data recency

**Columns**:
- `metric_name` - Metric name
- `metric_type` - Dimension category
- `target_table` - Table to measure
- `target_column` - Column to measure (or NULL for table-level)
- `metric_query` - SQL query to calculate metric
- `threshold_value` - Acceptable threshold
- `threshold_operator` - Comparison operator (>=, <=, =, etc.)
- `alert_on_failure` - Whether to alert (TRUE/FALSE)
- `enabled` - Whether metric is active (TRUE/FALSE)
- `description` - Metric description

---

### 5. LLM Prompt Templates
**File**: `silver_llm_prompts.csv`  
**Purpose**: Pre-configured prompts for AI-assisted data processing  
**Records**: 10 prompt templates  

**Prompt Types**:
1. **Field Mapping Assistant** - Suggest field mappings
2. **Schema Discovery** - Analyze and suggest schemas
3. **Data Quality Rule Generator** - Generate DQ rules
4. **Transformation Logic** - Create SQL transformations
5. **Anomaly Detection** - Identify data issues
6. **Business Rule Validation** - Validate rule appropriateness
7. **Deduplication Strategy** - Recommend matching algorithms
8. **Data Profiling Summary** - Comprehensive field analysis
9. **Semantic Field Matching** - Match fields by meaning
10. **Data Standardization** - Recommend standardization

**Columns**:
- `prompt_name` - Prompt identifier
- `prompt_template` - Full prompt text with placeholders
- `model_name` - LLM model (e.g., llama3.1-70b)
- `temperature` - Randomness (0.0-1.0)
- `max_tokens` - Response length limit
- `enabled` - Whether prompt is active (TRUE/FALSE)
- `description` - Prompt purpose

---

## 🚀 Usage

### Load All Configuration Files

```bash
# Navigate to sample_data directory
cd /path/to/file_processing_pipeline/sample_data

# Upload configuration files to Snowflake stage
snow sql -q "PUT file://config/silver_*.csv @db_ingest_pipeline.SILVER.SILVER_CONFIG;"

# Verify upload
snow sql -q "LIST @db_ingest_pipeline.SILVER.SILVER_CONFIG;"

# Load target schemas
snow sql -q "CALL db_ingest_pipeline.SILVER.load_target_schemas_from_csv('@SILVER_CONFIG/config/silver_target_schemas.csv');"

# Load field mappings
snow sql -q "CALL db_ingest_pipeline.SILVER.load_field_mappings_from_csv('@SILVER_CONFIG/config/silver_field_mappings.csv');"

# Load transformation rules
snow sql -q "CALL db_ingest_pipeline.SILVER.load_transformation_rules_from_csv('@SILVER_CONFIG/config/silver_transformation_rules.csv');"

# Load data quality metrics
snow sql -q "CALL db_ingest_pipeline.SILVER.load_data_quality_metrics_from_csv('@SILVER_CONFIG/config/silver_data_quality_metrics.csv');"

# Load LLM prompts
snow sql -q "CALL db_ingest_pipeline.SILVER.load_llm_prompts_from_csv('@SILVER_CONFIG/config/silver_llm_prompts.csv');"
```

### Load Individual Files

```sql
-- Load only target schemas
CALL db_ingest_pipeline.SILVER.load_target_schemas_from_csv(
    '@SILVER_CONFIG/config/silver_target_schemas.csv'
);

-- Load only field mappings
CALL db_ingest_pipeline.SILVER.load_field_mappings_from_csv(
    '@SILVER_CONFIG/config/silver_field_mappings.csv'
);
```

### Verify Loaded Data

```sql
-- Check target schemas
SELECT table_name, COUNT(*) as column_count
FROM db_ingest_pipeline.SILVER.target_schemas
GROUP BY table_name
ORDER BY table_name;

-- Check field mappings
SELECT target_table, COUNT(*) as mapping_count
FROM db_ingest_pipeline.SILVER.field_mappings
WHERE approved = TRUE
GROUP BY target_table
ORDER BY target_table;

-- Check transformation rules
SELECT rule_type, COUNT(*) as rule_count
FROM db_ingest_pipeline.SILVER.transformation_rules
WHERE enabled = TRUE
GROUP BY rule_type
ORDER BY rule_type;

-- Check data quality metrics
SELECT metric_type, COUNT(*) as metric_count
FROM db_ingest_pipeline.SILVER.data_quality_metrics
WHERE enabled = TRUE
GROUP BY metric_type
ORDER BY metric_type;

-- Check LLM prompts
SELECT prompt_name, model_name
FROM db_ingest_pipeline.SILVER.llm_prompt_templates
WHERE enabled = TRUE
ORDER BY prompt_name;
```

---

## 🎯 Use Cases

### Initial Setup
Load all configuration files when setting up the Silver layer for the first time.

### Testing
Use these pre-configured files to test the complete data pipeline without manual setup.

### Templates
Use as templates for creating your own custom configurations.

### Training
Learn the structure and format of each configuration type.

### Quick Start
Get a working Silver layer pipeline in minutes instead of hours.

---

## 📝 Customization

### Adding New Tables

1. Edit `silver_target_schemas.csv`
2. Add rows for each column in your new table
3. Reload the file using `load_target_schemas_from_csv()`

### Adding New Mappings

1. Edit `silver_field_mappings.csv`
2. Add rows for each source-to-target mapping
3. Reload the file using `load_field_mappings_from_csv()`

### Adding New Rules

1. Edit `silver_transformation_rules.csv`
2. Add rows for each new rule
3. Reload the file using `load_transformation_rules_from_csv()`

### Modifying Metrics

1. Edit `silver_data_quality_metrics.csv`
2. Update thresholds or add new metrics
3. Reload the file using `load_data_quality_metrics_from_csv()`

### Customizing Prompts

1. Edit `silver_llm_prompts.csv`
2. Modify prompt templates or add new ones
3. Reload the file using `load_llm_prompts_from_csv()`

---

## 🔄 File Format Requirements

All CSV files must follow these requirements:

- **Encoding**: UTF-8
- **Delimiter**: Comma (`,`)
- **Quote Character**: Double quote (`"`)
- **Header Row**: Required (column names)
- **Line Endings**: LF or CRLF
- **Special Characters**: Quote fields containing commas or quotes

---

## ⚠️ Important Notes

### Idempotency
- Loading procedures use `MERGE` statements to avoid duplicates
- Safe to reload files multiple times
- Existing records will be updated, not duplicated

### Dependencies
- Load `silver_target_schemas.csv` before `silver_field_mappings.csv`
- Field mappings reference tables defined in target schemas

### Validation
- Files are validated during load
- Invalid records will be reported in the procedure output
- Check procedure results for any errors

### Maintenance
- Keep files synchronized with your data model
- Version control these files alongside your code
- Document any custom modifications

---

## 📊 File Statistics

| File | Records | Purpose | Dependencies |
|------|---------|---------|--------------|
| `silver_target_schemas.csv` | 56 | Define tables | None |
| `silver_field_mappings.csv` | 73 | Map fields | Target schemas |
| `silver_transformation_rules.csv` | 47 | Transform data | Target schemas |
| `silver_data_quality_metrics.csv` | 20 | Measure quality | Target schemas |
| `silver_llm_prompts.csv` | 10 | AI assistance | None |

---

## 🎯 Configuration Strategy

### Layered Approach
```
1. Base Schema (target_schemas.csv)
   └─> Defines table structure
   
2. Field Mappings (field_mappings.csv)
   └─> Maps Bronze → Silver fields
   
3. Transformation Rules (transformation_rules.csv)
   └─> Applies business logic
   
4. Quality Metrics (data_quality_metrics.csv)
   └─> Measures data quality
   
5. LLM Prompts (llm_prompts.csv)
   └─> AI-assisted processing
```

### Configuration Lifecycle
```
1. Design → Define schemas and mappings
2. Load → Upload CSV files to Snowflake
3. Test → Validate with sample data
4. Deploy → Apply to production data
5. Monitor → Track quality metrics
6. Refine → Adjust based on results
```

## 📊 Configuration Statistics

### File Breakdown
```
File                              Records  Size    Purpose
─────────────────────────────────────────────────────────────
silver_target_schemas.csv           56    4.2 KB  Table definitions
silver_field_mappings.csv           73    8.1 KB  Field mappings
silver_transformation_rules.csv     47    8.3 KB  Business rules
silver_data_quality_metrics.csv     20    5.3 KB  Quality metrics
silver_llm_prompts.csv              10    7.4 KB  AI prompts
─────────────────────────────────────────────────────────────
Total                              206   33.3 KB  Complete config
```

### Coverage Analysis
```
Target Tables: 4
- CLAIMS (29 columns)
- PATIENT_DEMOGRAPHICS (9 columns)
- PROVIDER_DIRECTORY (9 columns)
- CLAIM_SUMMARY (9 columns)

Field Mappings: 73
- Aetna Dental: 23 mappings
- Anthem BlueCross: 29 mappings
- UnitedHealth: 21 mappings

Transformation Rules: 47
- Data Quality: 18 rules
- Standardization: 10 rules
- Business Logic: 10 rules
- Deduplication: 4 rules
- Referential Integrity: 5 rules

Quality Metrics: 20
- Completeness: 6 metrics
- Validity: 5 metrics
- Consistency: 4 metrics
- Uniqueness: 2 metrics
- Timeliness: 1 metric
- Accuracy: 2 metrics

LLM Prompts: 10
- Field Mapping: 3 prompts
- Schema Discovery: 2 prompts
- Rule Generation: 2 prompts
- Data Profiling: 3 prompts
```

## 🔧 Advanced Configuration

### Custom Table Definition
```csv
table_name,column_name,data_type,description
MY_TABLE,ID,NUMBER(38,0) AUTOINCREMENT,Unique identifier
MY_TABLE,NAME,VARCHAR(100),Entity name
MY_TABLE,CREATED_AT,TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),Creation time
```

### Complex Transformation Rule
```csv
rule_id,rule_name,rule_type,target_column,rule_logic,priority,error_action
COMPLEX_001,Multi-Step Transform,BUSINESS_LOGIC,DERIVED_FIELD,"CASE WHEN FIELD_A > 100 THEN FIELD_B * 1.1 ELSE FIELD_B * 0.9 END",15,QUARANTINE
```

### Conditional Quality Metric
```csv
metric_name,metric_type,target_table,metric_query,threshold_value,threshold_operator
Conditional Completeness,COMPLETENESS,CLAIMS,"SELECT COUNT(*) * 100.0 / (SELECT COUNT(*) FROM CLAIMS) FROM CLAIMS WHERE CASE WHEN CLAIM_TYPE = 'MEDICAL' THEN DIAGNOSIS_CODE IS NOT NULL ELSE TRUE END",99.0,>=
```

## 🧪 Testing Configurations

### Unit Testing
```sql
-- Test single mapping
SELECT 
    source_field,
    target_column,
    transformation_logic
FROM field_mappings
WHERE source_field = 'TEST_FIELD';

-- Apply transformation
SELECT 
    source_field,
    EVAL(transformation_logic) as result
FROM test_data;
```

### Integration Testing
```sql
-- Test complete transformation
CALL transform_bronze_to_silver(
    'RAW_DATA_TABLE',
    'TEST_TABLE',
    100,  -- Small batch for testing
    TRUE,
    FALSE  -- Non-incremental for testing
);

-- Verify results
SELECT * FROM TEST_TABLE LIMIT 10;
SELECT * FROM quarantine_records WHERE target_table = 'TEST_TABLE';
```

### Performance Testing
```sql
-- Measure transformation time
SET start_time = CURRENT_TIMESTAMP();

CALL transform_bronze_to_silver('RAW_DATA_TABLE', 'CLAIMS', 10000, TRUE, TRUE);

SET end_time = CURRENT_TIMESTAMP();
SELECT DATEDIFF('second', $start_time, $end_time) as duration_seconds;
```

## 📈 Configuration Best Practices

### Schema Design
1. **Data Types**: Use appropriate types for data
2. **Nullability**: Be explicit about nullable columns
3. **Constraints**: Use NOT NULL where data is required
4. **Defaults**: Use defaults for audit fields
5. **Descriptions**: Document all columns

### Field Mapping
1. **Confidence**: Review low-confidence mappings
2. **Approval**: Approve before production use
3. **Testing**: Test with sample data first
4. **Documentation**: Add notes for complex mappings
5. **Versioning**: Track mapping changes

### Rule Configuration
1. **Priority**: Order rules logically
2. **Error Actions**: Choose appropriate actions
3. **Testing**: Test rules individually
4. **Documentation**: Explain rule purpose
5. **Monitoring**: Track rule violations

### Quality Metrics
1. **Thresholds**: Set realistic thresholds
2. **Alerts**: Enable alerts for critical metrics
3. **Trending**: Track metrics over time
4. **Review**: Regularly review and adjust
5. **Documentation**: Document metric calculations

## 🔄 Configuration Management

### Version Control
```bash
# Track configuration changes
git add sample_data/config/*.csv
git commit -m "Update field mappings for new provider"
git tag -a v2.0-config -m "Configuration version 2.0"
```

### Backup Strategy
```sql
-- Backup current configuration
CREATE TABLE field_mappings_backup AS
SELECT * FROM field_mappings;

CREATE TABLE transformation_rules_backup AS
SELECT * FROM transformation_rules;
```

### Rollback Procedure
```sql
-- Rollback to previous configuration
DELETE FROM field_mappings;
INSERT INTO field_mappings SELECT * FROM field_mappings_backup;

DELETE FROM transformation_rules;
INSERT INTO transformation_rules SELECT * FROM transformation_rules_backup;
```

### Change Management
1. **Document Changes**: Update README with changes
2. **Test Changes**: Validate in dev environment
3. **Review Changes**: Peer review before production
4. **Deploy Changes**: Use controlled deployment
5. **Monitor Changes**: Track impact on quality

## 📚 Additional Resources

### Internal Documentation
- [Sample Data Main README](../README.md)
- [Quick Start Guide](../QUICK_START.md)
- [Claims Data README](../claims_data/README.md)
- [Silver Layer README](../../silver/README.md)

### Configuration Examples
- [Field Mapping Examples](../../silver/mappings/field_mappings.csv)
- [Rule Examples](../../silver/mappings/transformation_rules.csv)
- [Schema Examples](../../silver/mappings/target_schemas.csv)

### External Resources
- [CSV Format Specification](https://tools.ietf.org/html/rfc4180)
- [Data Quality Dimensions](https://en.wikipedia.org/wiki/Data_quality)
- [ETL Best Practices](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/)

---

**Last Updated**: January 2, 2026  
**Version**: 2.0  
**Status**: ✅ Ready for use  
**Total Configuration Items**: 206  
**Total Size**: 33.3 KB  
**Format**: CSV (UTF-8)



