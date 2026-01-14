# Sample Data for File Processing Pipeline

This folder contains sample healthcare claims data and Silver layer configuration files for testing and demonstration purposes.

---

## 🚀 Quick Start (5-10 Minutes)

### Step 1: Upload Claims Data to Bronze

```bash
cd /path/to/file_processing_pipeline/sample_data

# Upload claims files
snow sql -q "PUT file://claims_data/*.csv @db_ingest_pipeline.BRONZE.SRC;"
snow sql -q "PUT file://claims_data/*.xlsx @db_ingest_pipeline.BRONZE.SRC;"

# Trigger processing
snow sql -q "EXECUTE TASK db_ingest_pipeline.BRONZE.discover_files_task;"
```

**Result**: 5 files uploaded, ~4,035 claims records ingested into Bronze layer

### Step 2: Load Silver Configuration

```bash
# Upload config files
snow sql -q "PUT file://config/silver_*.csv @db_ingest_pipeline.SILVER.SILVER_CONFIG;"

# Load all configurations
snow sql -q "CALL db_ingest_pipeline.SILVER.load_target_schemas_from_csv('@SILVER_CONFIG/config/silver_target_schemas.csv');"
snow sql -q "CALL db_ingest_pipeline.SILVER.load_field_mappings_from_csv('@SILVER_CONFIG/config/silver_field_mappings.csv');"
snow sql -q "CALL db_ingest_pipeline.SILVER.load_transformation_rules_from_csv('@SILVER_CONFIG/config/silver_transformation_rules.csv');"
```

**Result**: 4 target tables defined, 73 field mappings loaded, 47 transformation rules configured

### Step 3: Create Tables and Transform Data

```sql
USE SCHEMA db_ingest_pipeline.SILVER;

-- Create target tables
CALL create_all_silver_tables();

-- Transform Bronze to Silver
CALL transform_bronze_to_silver('RAW_DATA_TABLE', 'CLAIMS', 'BRONZE', 10000, TRUE, TRUE);

-- View results
SELECT * FROM CLAIMS LIMIT 10;
SELECT * FROM v_transformation_status_summary;
```

**Result**: Silver tables created and populated with transformed, validated data

---

## 📁 Folder Structure

```
sample_data/
├── claims_data/          # 5 healthcare claims files (~1 MB total)
│   ├── provider_a_dental-claims-20240301.csv (192 KB, 875 records)
│   ├── provider_b_medical-claims-20240115.csv (280 KB, 1,129 records)
│   ├── provider_c_medical-claims-20240215.xlsx (223 KB, ~780 records)
│   ├── provider_d_medical-claims-20240315.xlsx (170 KB, ~438 records)
│   ├── provider_e_pharmacy-claims-20240201.csv (176 KB, 813 records)
│   └── README.md
├── config/               # 5 Silver configuration files (~33 KB total)
│   ├── silver_target_schemas.csv (4.2 KB, 56 columns)
│   ├── silver_field_mappings.csv (8.1 KB, 73 mappings)
│   ├── silver_transformation_rules.csv (8.3 KB, 47 rules)
│   ├── silver_data_quality_metrics.csv (5.3 KB, 20 metrics)
│   ├── silver_llm_prompts.csv (7.4 KB, 10 prompts)
│   └── README.md
└── README.md             # This file
```

---

## 📊 What You Get

### Bronze Layer (Raw Data)
- ✅ 5 healthcare claims files from different providers
- ✅ Mixed formats (CSV, Excel)
- ✅ Mixed date formats (MM-DD-YYYY, YYYY-MM-DD, MM/DD/YYYY)
- ✅ ~4,035 total records

### Silver Layer (Standardized Data)
- ✅ 4 target tables defined (CLAIMS, PATIENT_DEMOGRAPHICS, etc.)
- ✅ 73 pre-configured field mappings
- ✅ 47 transformation and data quality rules
- ✅ 20 data quality metrics
- ✅ 10 LLM prompt templates

---

## 📁 Contents Detail

### Bronze Layer Sample Data (Healthcare Claims)

#### 1. **Provider A - Dental Claims** (`claims_data/provider_a_dental-claims-20240301.csv`)
- **Type**: Dental claims
- **Records**: 875 claims
- **Format**: CSV with custom date format (MM-DD-YYYY)
- **Key Fields**: Patient demographics, CDT procedure codes, dentist info, financial details

#### 2. **Provider B - Medical Claims** (`claims_data/provider_b_medical-claims-20240115.csv`)
- **Type**: Medical claims
- **Records**: 1,129 claims
- **Format**: CSV with ISO date format (YYYY-MM-DD)
- **Key Fields**: Member demographics, ICD-10 codes, CPT codes, provider info, plan types

#### 3. **Provider E - Pharmacy Claims** (`claims_data/provider_e_pharmacy-claims-20240201.csv`)
- **Type**: Pharmacy/prescription claims
- **Records**: 813 claims
- **Format**: CSV with slash date format (MM/DD/YYYY)
- **Key Fields**: Patient demographics, drug names, pharmacy info, financial details

#### 4. **Provider C - Medical Claims** (`claims_data/provider_c_medical-claims-20240215.xlsx`)
- **Type**: Medical claims
- **Format**: Excel (.xlsx)
- **Records**: ~780 claims

#### 5. **Provider D - Medical Claims** (`claims_data/provider_d_medical-claims-20240315.xlsx`)
- **Type**: Medical claims
- **Format**: Excel (.xlsx)
- **Records**: ~438 claims

**See [claims_data/README.md](claims_data/README.md) for detailed field specifications.**

---

### Silver Layer Configuration Files

#### 1. **Target Schema Definitions** (`config/silver_target_schemas.csv`)

Defines 4 standardized target tables:
- **CLAIMS** (29 columns) - Unified claims table
- **PATIENT_DEMOGRAPHICS** (9 columns) - Deduplicated patient data
- **PROVIDER_DIRECTORY** (9 columns) - Master provider reference
- **CLAIM_SUMMARY** (9 columns) - Aggregated metrics

#### 2. **Field Mappings** (`config/silver_field_mappings.csv`)

73 field mappings covering:
- Provider A (Dental): 23 mappings
- Provider B (Medical): 29 mappings
- Provider E (Pharmacy): 21 mappings

Features:
- Date format conversions
- Data type casting
- Text standardization
- 100% confidence scores (manual)

#### 3. **Transformation Rules** (`config/silver_transformation_rules.csv`)

47 comprehensive rules:
- **Data Quality (18)**: Required fields, format validation, range checks
- **Standardization (10)**: Name normalization, date formatting, code mapping
- **Business Logic (10)**: Age calculation, processing time, cost flags
- **Deduplication (4)**: Exact/fuzzy matching strategies
- **Referential Integrity (5)**: Valid plan types, date sequences

#### 4. **Data Quality Metrics** (`config/silver_data_quality_metrics.csv`)

20 metrics monitoring:
- Completeness (99-100% thresholds)
- Validity (95-99% thresholds)
- Consistency (98-99% thresholds)
- Uniqueness (100% for keys)
- Timeliness (95% within 30 days)

#### 5. **LLM Prompt Templates** (`config/silver_llm_prompts.csv`)

10 AI-assisted prompts:
- Field Mapping Assistant
- Schema Discovery
- Data Quality Rule Generator
- Transformation Logic
- Anomaly Detection
- Business Rule Validation
- Deduplication Strategy
- Data Profiling Summary
- Semantic Field Matching
- Data Standardization

**See [config/README.md](config/README.md) for detailed configuration specifications.**

---

## 🔍 Verify Everything Worked

### Check Bronze Layer

```sql
-- View ingested files
SELECT * FROM db_ingest_pipeline.BRONZE.file_metadata 
WHERE status = 'PROCESSED' 
ORDER BY discovered_at DESC;

-- View raw data
SELECT * FROM db_ingest_pipeline.BRONZE.RAW_DATA_TABLE LIMIT 10;
```

### Check Silver Configuration

```sql
-- View target tables
SELECT table_name, COUNT(*) as column_count
FROM db_ingest_pipeline.SILVER.target_schemas
GROUP BY table_name;

-- View field mappings
SELECT target_table, COUNT(*) as mapping_count
FROM db_ingest_pipeline.SILVER.field_mappings
WHERE approved = TRUE
GROUP BY target_table;

-- View transformation rules
SELECT rule_type, COUNT(*) as rule_count
FROM db_ingest_pipeline.SILVER.transformation_rules
WHERE active = TRUE
GROUP BY rule_type;
```

### Check Silver Tables

```sql
-- View created tables
SHOW TABLES IN db_ingest_pipeline.SILVER;

-- View transformed data
SELECT COUNT(*) as total_claims FROM db_ingest_pipeline.SILVER.CLAIMS;

-- View data quality summary
SELECT * FROM db_ingest_pipeline.SILVER.v_data_quality_dashboard;
```

---

## 📱 Using the Streamlit Apps

### Bronze Data Manager
1. Open: `https://app.snowflake.com/.../BRONZE_DATA_MANAGER`
2. **File Discovery** tab - See uploaded files
3. **Processing Status** tab - Monitor ingestion
4. **Data Preview** tab - View raw data

### Silver Transformation Manager
1. Open: `https://app.snowflake.com/.../SILVER_DATA_MANAGER`
2. **Target Table Designer** tab - View/edit table definitions
3. **Field Mapper** tab - View/edit field mappings
4. **Rules Engine** tab - View/edit transformation rules
5. **Data Quality** tab - View quality metrics

---

## 🔄 Reset and Reload

### Clear Bronze Data

```sql
DELETE FROM db_ingest_pipeline.BRONZE.file_metadata;
DELETE FROM db_ingest_pipeline.BRONZE.RAW_DATA_TABLE;
REMOVE @db_ingest_pipeline.BRONZE.SRC;
```

### Clear Silver Configuration

```sql
DELETE FROM db_ingest_pipeline.SILVER.target_schemas;
DELETE FROM db_ingest_pipeline.SILVER.field_mappings;
DELETE FROM db_ingest_pipeline.SILVER.transformation_rules;

DROP TABLE IF EXISTS db_ingest_pipeline.SILVER.CLAIMS;
DROP TABLE IF EXISTS db_ingest_pipeline.SILVER.PATIENT_DEMOGRAPHICS;
DROP TABLE IF EXISTS db_ingest_pipeline.SILVER.PROVIDER_DIRECTORY;
DROP TABLE IF EXISTS db_ingest_pipeline.SILVER.CLAIM_SUMMARY;
```

Then re-run the 3-step quick start above.

---

## 🎯 Use Cases

### Testing
Validate that your pipeline is working correctly end-to-end.

### Development
Use as sample data while developing new features.

### Training
Learn how the pipeline works with realistic data.

### Demonstration
Show stakeholders the pipeline capabilities.

---

## 📊 Data Characteristics

### Volume
- **Total Records**: ~4,035 claims across 5 files
- **Date Range**: January 2024 - March 2024
- **Providers**: 5 generic healthcare providers (A-E)
- **Claim Types**: Medical, Dental, Pharmacy

### Data Quality
- **Completeness**: 95-100% for critical fields
- **Validity**: Realistic amounts, dates, and codes
- **Variety**: Multiple date formats, naming conventions
- **Complexity**: Demonstrates real-world data challenges

---

## 💡 Tips

### Performance
- Sample data is small (~4K records) for quick testing
- Production pipelines would handle millions of records
- Adjust batch sizes accordingly

### Customization
- Edit CSV files to add your own tables, mappings, or rules
- Use the Streamlit apps to modify configurations interactively
- Version control your customizations

### Troubleshooting
- Check procedure output messages for errors
- Use the Streamlit apps to monitor processing status
- Query `quarantine_records` table for rejected data

---

## ⚠️ Important Notes

### Data Privacy
- This is **synthetic test data** for demonstration purposes only
- No real patient or provider information is included
- Safe for development, testing, and training environments

### Data Formats
- CSV files use different date formats intentionally (to demonstrate transformation)
- Excel files test multi-format support
- Field names vary by provider (realistic scenario)

### Performance
- Sample data is sized for quick testing (~4,035 records)
- Production systems would handle millions of records
- Batch sizes and parallelization would be adjusted accordingly

---

## 📚 More Information

- **Bronze Layer**: See [../bronze/README.md](../bronze/README.md)
- **Silver Layer**: See [../silver/README.md](../silver/README.md)
- **Main Project**: See [../README.md](../README.md)
- **Claims Data Details**: See [claims_data/README.md](claims_data/README.md)
- **Config File Details**: See [config/README.md](config/README.md)

---

**Last Updated**: January 5, 2026  
**Estimated Time**: 5-10 minutes to complete all steps  
**Total Records**: ~4,035 claims across 5 files  
**Configuration Items**: 206 (schemas, mappings, rules, metrics, prompts)  
**Status**: ✅ Ready to use
