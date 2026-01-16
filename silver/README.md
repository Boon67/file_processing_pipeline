# Silver Layer Data Transformation Pipeline

An intelligent data transformation layer built on Snowflake Native Features with dynamic schema definition, multi-method field mapping (Manual/ML/LLM), and a comprehensive rules engine.

## 🎯 Overview

The Silver layer transforms Bronze raw data into clean, standardized, business-ready datasets using:
- **Dynamic Schema Definition**: Define target tables via metadata
- **Intelligent Field Mapping**: Manual CSV, ML pattern matching, or LLM-assisted semantic mapping
- **Comprehensive Rules Engine**: Data quality, business logic, standardization, and deduplication
- **Automated Task Pipeline**: Scheduled transformations with quality checks
- **Streamlit Management UI**: Full-featured web interface for configuration and monitoring

## ✨ Key Features

### Field Mapping Engine
- **Manual CSV Mappings**: Load predefined mappings from CSV files
- **ML Pattern Matching**: Auto-suggest mappings using similarity algorithms (exact match, substring, sequence similarity, TF-IDF)
- **LLM Cortex AI**: Semantic understanding of field relationships using Snowflake Cortex AI models (one-to-one mapping per source field)
- **Confidence Scoring**: All mappings include confidence scores for review
- **Approval Workflow**: Review and approve suggested mappings before use
- **TPA-Aware**: All mappings include TPA dimension for multi-tenancy
- **Duplicate Prevention**: Prevents duplicate mappings for same TPA

### Rules Engine
- **Data Quality Rules**: Null checks, format validation, range checks, referential integrity
- **Business Logic**: Calculations, lookups, conditional transformations, aggregations
- **Standardization**: Date normalization, name casing, code mapping, unit conversion
- **Deduplication**: Exact/fuzzy matching with configurable conflict resolution strategies
- **Priority-Based Execution**: Rules execute in priority order with error handling

### Transformation Pipeline
- **Batch Processing**: Configurable batch sizes for performance optimization
- **Incremental Loading**: Watermark-based to avoid reprocessing
- **MERGE Operations**: Upsert logic for efficient data updates
- **Quality Metrics**: Track pass/fail rates, violations, and quarantined records
- **Audit Trail**: Complete logging of all transformation batches

### Streamlit Management UI
- **Global TPA Selector**: Select TPA once in header, applies to all pages
- **Schema Designer**: Define and manage TPA-specific target table schemas
- **Field Mapper**: Create and review TPA-specific field mappings with all three methods
- **Rules Engine**: Configure transformation rules with visual interface
- **Transformation Monitor**: Real-time batch processing status
- **Data Quality Metrics**: Quality dashboards and quarantine management
- **Task Management**: Control Silver layer tasks (pause/resume/execute)
- **TPA Filtering**: All data, tables, and mappings filtered by selected TPA

## 🏗️ Architecture

```
Bronze Layer (RAW_DATA_TABLE)
    ↓
Schema Discovery
    ↓
Field Mapping Engine
    ├─→ Manual CSV Mappings
    ├─→ ML Pattern Matching
    └─→ LLM Cortex AI
    ↓
Rules Engine
    ├─→ Data Quality Rules
    ├─→ Business Logic
    ├─→ Standardization
    └─→ Deduplication
    ↓
Silver Layer Tables
    ↓
Automated Tasks
    ↓
Streamlit UI Monitoring
```

## 📁 Project Structure

```
silver/
├── 1_Silver_Schema_Setup.sql          # Schema, stages, metadata tables
├── 2_Silver_Target_Schemas.sql        # Dynamic table creation procedures
├── 3_Silver_Mapping_Procedures.sql    # Field mapping engine (Manual/ML/LLM)
├── 4_Silver_Rules_Engine.sql          # Transformation rules procedures
├── 5_Silver_Transformation_Logic.sql  # Core orchestration procedures
├── 6_Silver_Tasks.sql                 # Automated task pipeline
├── mappings/
│   ├── target_tables.csv              # Sample target table definitions
│   ├── field_mappings.csv             # Sample field mappings
│   └── transformation_rules.csv       # Sample transformation rules
└── silver_streamlit/
    ├── streamlit_app.py               # Streamlit management UI
    ├── environment.yml                # Python dependencies
    ├── snowflake.yml                  # Deployment configuration
    ├── README.md                      # Streamlit app documentation
    └── DEPLOYMENT.md                  # Deployment guide
```

## 🚀 Quick Start

Get started with the Silver layer in 5 minutes!

### Prerequisites

- Bronze layer deployed and operational
- Snowflake CLI installed and configured
- Appropriate Snowflake permissions (SYSADMIN, SECURITYADMIN)

### Step 1: Deploy (2 minutes)

```bash
# Deploy Silver layer with default configuration
./deploy_silver.sh

# Deploy with custom configuration
./deploy_silver.sh custom.config
```

This will create the Silver schema, deploy all stored procedures, load sample configurations, and deploy the Streamlit app.

### Step 2: Access Streamlit (1 minute)

1. Open Snowsight
2. Navigate to: **Streamlit** → **SILVER_DATA_MANAGER**
3. You'll see 6 tabs ready to use!

### Step 3: Define Your Schema (5 minutes)

**Option A: Use the UI**
1. Go to **"📐 Schema Designer"** tab
2. Click **"➕ Add Schema"**
3. Fill in table and column details
4. Click **"🏗️ Create Tables"**

**Option B: Use SQL**

```sql
USE SCHEMA SILVER;

-- Define your table structure
INSERT INTO target_schemas (table_name, column_name, data_type, nullable, primary_key, description)
VALUES 
    ('CUSTOMER', 'CUSTOMER_ID', 'NUMBER(38,0) AUTOINCREMENT', FALSE, TRUE, 'Unique ID'),
    ('CUSTOMER', 'FIRST_NAME', 'VARCHAR(100)', FALSE, FALSE, 'First name'),
    ('CUSTOMER', 'LAST_NAME', 'VARCHAR(100)', FALSE, FALSE, 'Last name'),
    ('CUSTOMER', 'EMAIL', 'VARCHAR(200)', TRUE, FALSE, 'Email address');

-- Create the table
CALL create_silver_table('CUSTOMER');
```

### Step 4: Map Your Fields (5 minutes)

**Option A: Manual Mapping (Fastest)**

```sql
INSERT INTO field_mappings (source_field, target_table, target_column, mapping_method, approved)
VALUES 
    ('CUST_ID', 'CUSTOMER', 'CUSTOMER_ID', 'MANUAL', TRUE),
    ('FNAME', 'CUSTOMER', 'FIRST_NAME', 'MANUAL', TRUE),
    ('LNAME', 'CUSTOMER', 'LAST_NAME', 'MANUAL', TRUE),
    ('EMAIL_ADDR', 'CUSTOMER', 'EMAIL', 'MANUAL', TRUE);
```

**Option B: ML Auto-Mapping (Smart)**

```sql
-- Generate suggestions
CALL auto_map_fields_ml('RAW_DATA_TABLE', 3, 0.6);

-- Review in Streamlit "🗺️ Field Mapper" tab
-- Approve high-confidence mappings
CALL approve_mappings_for_table('CUSTOMER', 0.8);
```

**Option C: LLM Mapping (Most Intelligent)**

```sql
-- Use AI for semantic understanding
CALL auto_map_fields_llm('RAW_DATA_TABLE', 'llama3.1-70b', 'DEFAULT_FIELD_MAPPING');

-- Review and approve in Streamlit
```

### Step 5: Add Quality Rules (3 minutes)

```sql
-- Ensure email is not null
INSERT INTO transformation_rules (rule_id, rule_name, rule_type, target_column, rule_logic, priority, error_action)
VALUES ('DQ001', 'Email Required', 'DATA_QUALITY', 'EMAIL', 'IS NOT NULL', 1, 'REJECT');

-- Standardize names to uppercase
INSERT INTO transformation_rules (rule_id, rule_name, rule_type, target_column, rule_logic, priority)
VALUES ('STD001', 'Uppercase Names', 'STANDARDIZATION', 'LAST_NAME', 'UPPER', 10);

-- Remove duplicates
INSERT INTO transformation_rules (rule_id, rule_name, rule_type, rule_logic, rule_parameters, priority)
VALUES ('DD001', 'Dedupe Customers', 'DEDUPLICATION', 'EMAIL', '{"strategy": "KEEP_LAST"}', 20);
```

### Step 6: Run Your First Transformation (2 minutes)

**Option A: Manual Run**

```sql
-- Transform one batch
CALL transform_bronze_to_silver('RAW_DATA_TABLE', 'CUSTOMER', 10000, TRUE, TRUE);

-- Check results
SELECT * FROM CUSTOMER LIMIT 10;
SELECT * FROM v_transformation_status_summary;
```

**Option B: Automated (Recommended)**

```sql
-- Start the automated pipeline
CALL resume_all_silver_tasks();

-- Tasks will run automatically:
-- 1. Monitor Bronze completion (every 5 min)
-- 2. Discover new data
-- 3. Transform with rules
-- 4. Check quality
-- 5. Publish or quarantine
```

### Step 7: Monitor (Ongoing)

**In Streamlit:**
- **"📊 Transformation Monitor"**: View batch history
- **"📈 Data Quality Metrics"**: Check quality scores
- **"🔧 Task Management"**: Control tasks

**In SQL:**

```sql
-- Recent transformations
SELECT * FROM v_recent_transformation_batches;

-- Quality dashboard
SELECT * FROM v_data_quality_dashboard;

-- Quarantined records
SELECT * FROM quarantine_records WHERE resolved = FALSE;

-- Task status
SELECT * FROM v_silver_task_status;
```

### 🎉 You're Done!

Your Silver layer is now:
- ✅ Transforming Bronze data automatically
- ✅ Applying quality rules
- ✅ Tracking metrics
- ✅ Quarantining bad data
- ✅ Ready for analytics!

### 💡 Pro Tips

1. **Start Simple**: Begin with manual mappings, add ML/LLM later
2. **Test Rules**: Use small batches to test rules before full runs
3. **Monitor Quality**: Check quarantine regularly
4. **Incremental**: Use watermarks for large datasets
5. **Document**: Add descriptions to schemas and rules

## 📊 Components

### Metadata Tables

| Table | Purpose |
|-------|---------|
| `target_schemas` | Dynamic target table definitions |
| `field_mappings` | Bronze → Silver field mappings |
| `transformation_rules` | Transformation rules configuration |
| `silver_processing_log` | Batch processing audit trail |
| `data_quality_metrics` | Quality tracking and metrics |
| `quarantine_records` | Failed validation records |
| `processing_watermarks` | Incremental processing state |
| `llm_prompt_templates` | Customizable LLM prompts |

### Stored Procedures

**Schema Management:**
- `load_target_schemas_from_csv()` - Load schemas from CSV
- `create_silver_table()` - Create table from metadata
- `create_all_silver_tables()` - Create all defined tables

**Field Mapping:**
- `load_field_mappings_from_csv()` - Load manual mappings
- `auto_map_fields_ml()` - ML-based auto-mapping
- `auto_map_fields_llm()` - LLM-assisted mapping
- `approve_field_mapping()` - Approve mapping for use

**Rules Engine:**
- `load_transformation_rules_from_csv()` - Load rules from CSV
- `apply_quality_rules()` - Apply data quality rules
- `apply_business_rules()` - Apply business logic
- `apply_standardization_rules()` - Apply standardization
- `apply_deduplication_rules()` - Apply deduplication

**Transformation:**
- `discover_bronze_schema()` - Analyze Bronze data structure
- `transform_bronze_to_silver()` - Main transformation procedure
- `process_all_pending_bronze()` - Process all pending data
- `reset_watermark()` - Reset incremental processing

**Task Management:**
- `suspend_all_silver_tasks()` - Suspend all tasks
- `resume_all_silver_tasks()` - Resume all tasks
- `execute_silver_task_manually()` - Execute task on-demand

### Automated Tasks

| Task | Schedule | Purpose |
|------|----------|---------|
| `bronze_completion_sensor` | Every 5 minutes | Monitor Bronze tasks |
| `silver_discovery_task` | After Bronze completion | Discover new data |
| `silver_transformation_task` | After discovery | Transform data |
| `silver_quality_check_task` | After transformation | Validate quality |
| `silver_publish_task` | After quality check | Publish successful batches |
| `silver_quarantine_task` | After quality check | Handle failures |

## 🔧 Configuration

### default.config

```bash
# Silver Layer Configuration
SILVER_SCHEMA_NAME="SILVER"
SILVER_STAGE_NAME="SILVER_STAGE"
SILVER_CONFIG_STAGE_NAME="SILVER_CONFIG"
SILVER_STREAMLIT_STAGE_NAME="SILVER_STREAMLIT"
SILVER_TRANSFORM_SCHEDULE_MINUTES="15"
SILVER_STREAMLIT_APP_NAME="SILVER_DATA_MANAGER"
DEFAULT_LLM_MODEL="llama3.1-70b"
DEFAULT_BATCH_SIZE="10000"
```

## 📝 Usage Examples

### Define a Target Schema

```sql
-- Add columns to target_schemas table
INSERT INTO target_schemas (table_name, column_name, data_type, nullable, primary_key, description)
VALUES 
    ('CUSTOMER', 'CUSTOMER_ID', 'NUMBER(38,0) AUTOINCREMENT', FALSE, TRUE, 'Unique customer identifier'),
    ('CUSTOMER', 'FIRST_NAME', 'VARCHAR(100)', FALSE, FALSE, 'Customer first name'),
    ('CUSTOMER', 'LAST_NAME', 'VARCHAR(100)', FALSE, FALSE, 'Customer last name'),
    ('CUSTOMER', 'EMAIL', 'VARCHAR(200)', TRUE, FALSE, 'Customer email address');

-- Create the table
CALL create_silver_table('CUSTOMER');
```

### Create Manual Field Mappings

```sql
INSERT INTO field_mappings (source_field, target_table, target_column, mapping_method, approved)
VALUES 
    ('CUST_ID', 'CUSTOMER', 'CUSTOMER_ID', 'MANUAL', TRUE),
    ('FNAME', 'CUSTOMER', 'FIRST_NAME', 'MANUAL', TRUE),
    ('LNAME', 'CUSTOMER', 'LAST_NAME', 'MANUAL', TRUE);
```

### Use ML Auto-Mapping

```sql
-- Generate ML-based mappings
CALL auto_map_fields_ml('RAW_DATA_TABLE', 3, 0.6);

-- Review and approve
SELECT * FROM field_mappings WHERE mapping_method = 'ML_AUTO' AND approved = FALSE;

-- Approve high-confidence mappings
CALL approve_mappings_for_table('CUSTOMER', 0.8);
```

### Use LLM Mapping

```sql
-- Generate LLM-based mappings
CALL auto_map_fields_llm('RAW_DATA_TABLE', 'llama3.1-70b', 'DEFAULT_FIELD_MAPPING');

-- Review results
SELECT * FROM field_mappings WHERE mapping_method = 'LLM_CORTEX';
```

### Configure Transformation Rules

```sql
-- Data quality rule
INSERT INTO transformation_rules (rule_id, rule_name, rule_type, target_table, target_column, rule_logic, priority, error_action)
VALUES ('DQ001', 'Email Format Check', 'DATA_QUALITY', 'CUSTOMER', 'EMAIL', 
        'RLIKE ''^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$''', 1, 'QUARANTINE');

-- Standardization rule
INSERT INTO transformation_rules (rule_id, rule_name, rule_type, target_table, target_column, rule_logic, priority)
VALUES ('STD001', 'Uppercase Names', 'STANDARDIZATION', 'CUSTOMER', 'LAST_NAME', 'UPPER', 10);
```

### Run Transformation

```sql
-- Transform one batch
CALL transform_bronze_to_silver('RAW_DATA_TABLE', 'CUSTOMER', 10000, TRUE, TRUE);

-- Process all pending data
CALL process_all_pending_bronze('CUSTOMER', 10000);

-- Check status
SELECT * FROM v_transformation_status_summary;
```

### Monitor Quality

```sql
-- View quality dashboard
SELECT * FROM v_data_quality_dashboard;

-- Check quarantined records
SELECT * FROM quarantine_records WHERE resolved = FALSE;

-- View rule execution history
SELECT * FROM v_rule_execution_history;
```

## 🔍 Monitoring & Troubleshooting

### Check Transformation Status

```sql
-- Recent batches
SELECT * FROM v_recent_transformation_batches;

-- Watermark status
SELECT * FROM v_watermark_status;

-- Failed batches
SELECT * FROM silver_processing_log WHERE status = 'FAILED' ORDER BY start_timestamp DESC;
```

### Check Field Mappings

```sql
-- Mapping summary
SELECT * FROM v_field_mapping_summary;

-- Duplicate targets
SELECT * FROM v_duplicate_target_mappings;

-- Unmapped fields
SELECT * FROM v_unmapped_target_fields;
```

### Check Rules

```sql
-- Rules summary
SELECT * FROM v_rules_summary;

-- Rule execution history
SELECT * FROM v_rule_execution_history;
```

### Task Status

```sql
-- Silver task status
SELECT * FROM v_silver_task_status;

-- Task history
SELECT * FROM v_silver_task_history;
```

## 🎓 Best Practices

1. **Schema Design**
   - Use descriptive column names
   - Document columns with descriptions
   - Define appropriate data types and constraints

2. **Field Mapping**
   - Start with ML auto-mapping to get suggestions
   - Use LLM for complex semantic relationships
   - Always review and approve auto-generated mappings
   - Handle duplicate target warnings

3. **Rules Configuration**
   - Set appropriate priorities (lower = higher priority)
   - Use REJECT for critical validations
   - Use QUARANTINE for review-worthy issues
   - Use LOG for informational rules

4. **Performance**
   - Use appropriate batch sizes (10,000 is a good default)
   - Enable incremental processing for large datasets
   - Monitor transformation duration
   - Adjust task schedules based on data volume

5. **Quality Management**
   - Review quarantined records regularly
   - Set quality thresholds appropriate for your data
   - Track quality trends over time
   - Resolve quarantined records or adjust rules

## 📚 Additional Resources

- [Snowflake Cortex AI Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex)
- [Snowflake Tasks Documentation](https://docs.snowflake.com/en/user-guide/tasks-intro)
- [Streamlit in Snowflake Documentation](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)

## 🤝 Integration with Bronze Layer

The Silver layer seamlessly integrates with the existing Bronze layer:
- Reads from `BRONZE.RAW_DATA_TABLE`
- Uses existing roles (`_ADMIN`, `_READWRITE`, `_READONLY`)
- Triggered automatically after Bronze task completion
- Shares the same database and warehouse

### Integration Architecture

```
Bronze Layer                    Silver Layer
─────────────                   ─────────────
RAW_DATA_TABLE ────────────────→ Field Mapping Engine
(VARIANT data)                   ├─ Manual CSV
                                 ├─ ML Pattern
                                 └─ LLM Cortex
                                       ↓
file_processing_queue ──────────→ Rules Engine
(Status tracking)                ├─ Data Quality
                                 ├─ Business Logic
                                 ├─ Standardization
                                 ├─ Deduplication
                                 └─ Referential
                                       ↓
Bronze Tasks ───────────────────→ Silver Tasks
(Completion signal)              (Automated processing)
                                       ↓
                                 Silver Tables
                                 (Structured data)
```

### Shared Resources

**Database:** Same database for both layers  
**Warehouse:** Can use same or separate warehouses  
**Roles:** Shared role hierarchy  
**Stages:** Separate stages per layer  
**Monitoring:** Integrated Streamlit apps

## 🛠️ Advanced Topics

### Custom Transformation Functions

Create UDFs for complex transformations:

```sql
-- Create UDF for phone number formatting
CREATE OR REPLACE FUNCTION format_phone(phone VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    REGEXP_REPLACE(
        REGEXP_REPLACE(phone, '[^0-9]', ''),
        '([0-9]{3})([0-9]{3})([0-9]{4})',
        '(\\1) \\2-\\3'
    )
$$;

-- Use in transformation rule
INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, target_column,
    rule_logic, priority
) VALUES (
    'STD002', 'Format Phone', 'STANDARDIZATION', 'PHONE',
    'format_phone(source_value)',
    20
);
```

### Incremental Processing with Watermarks

```sql
-- Check current watermark
SELECT * FROM processing_watermarks 
WHERE source_table = 'RAW_DATA_TABLE' 
  AND target_table = 'CUSTOMER';

-- Process only new records
CALL transform_bronze_to_silver(
    'RAW_DATA_TABLE',
    'CUSTOMER',
    10000,
    TRUE,  -- apply_rules
    TRUE   -- incremental (uses watermark)
);

-- Reset watermark if needed
CALL reset_watermark('RAW_DATA_TABLE', 'CUSTOMER');
```

### Dynamic Table Creation

```sql
-- Define schema in metadata
INSERT INTO target_schemas (table_name, column_name, data_type, nullable, primary_key)
VALUES 
    ('DYNAMIC_TABLE', 'ID', 'NUMBER(38,0) AUTOINCREMENT', FALSE, TRUE),
    ('DYNAMIC_TABLE', 'NAME', 'VARCHAR(100)', FALSE, FALSE),
    ('DYNAMIC_TABLE', 'CREATED_AT', 'TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()', TRUE, FALSE);

-- Create table from metadata
CALL create_silver_table('DYNAMIC_TABLE');

-- Verify creation
SHOW TABLES LIKE 'DYNAMIC_TABLE';
```

### Fuzzy Matching for Deduplication

```sql
-- Fuzzy match patients by name (85% similarity)
INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, rule_logic,
    rule_parameters, priority
) VALUES (
    'DD002', 'Fuzzy Match Patients', 'DEDUPLICATION',
    'FIRST_NAME || '' '' || LAST_NAME',
    '{"strategy": "FUZZY", "threshold": 0.85, "keep": "LAST"}',
    30
);
```

### Custom LLM Prompts

```sql
-- Create custom prompt for industry-specific mapping
INSERT INTO llm_prompt_templates (
    prompt_name, prompt_template, model_name, temperature
) VALUES (
    'Healthcare Field Mapping',
    'You are a healthcare data expert. Map the source field "{source_field}" 
     to the most appropriate target field from: {target_fields}. 
     Consider HIPAA compliance and healthcare standards.
     Return JSON: {"target_field": "...", "confidence": 0.0-1.0, "reason": "..."}',
    'llama3.1-70b',
    0.2
);

-- Use custom prompt
CALL auto_map_fields_llm('RAW_DATA_TABLE', 'llama3.1-70b', 'Healthcare Field Mapping');
```

## 📈 Monitoring & Observability

### Key Metrics to Track

**Transformation Metrics:**
- Batch processing time
- Records processed per minute
- Success/failure rate
- Quarantine rate

**Quality Metrics:**
- Data quality score (% passing rules)
- Rule violation rate by type
- Quarantine resolution time
- Reprocessing rate

**System Metrics:**
- Task execution frequency
- Warehouse utilization
- Credit consumption
- Storage growth

### Monitoring Queries

```sql
-- Daily transformation summary
SELECT 
    DATE(start_timestamp) as date,
    COUNT(*) as batches,
    SUM(records_processed) as total_records,
    AVG(DATEDIFF('second', start_timestamp, end_timestamp)) as avg_duration_sec,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_batches
FROM silver_processing_log
WHERE start_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY DATE(start_timestamp)
ORDER BY date DESC;

-- Quality trend analysis
SELECT 
    DATE(measurement_timestamp) as date,
    metric_type,
    AVG(metric_value) as avg_score,
    MIN(metric_value) as min_score,
    MAX(metric_value) as max_score
FROM data_quality_metrics
WHERE measurement_timestamp >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY DATE(measurement_timestamp), metric_type
ORDER BY date DESC, metric_type;

-- Top quarantine reasons
SELECT 
    rule_id,
    rule_name,
    COUNT(*) as violation_count,
    COUNT(DISTINCT record_id) as unique_records
FROM quarantine_records
WHERE resolved = FALSE
GROUP BY rule_id, rule_name
ORDER BY violation_count DESC
LIMIT 10;
```

### Alerting Setup

```sql
-- Create alert for high quarantine rate
CREATE OR REPLACE ALERT high_quarantine_rate
WAREHOUSE = COMPUTE_WH
SCHEDULE = '60 MINUTE'
IF (EXISTS (
    SELECT 1
    FROM (
        SELECT 
            COUNT(CASE WHEN quarantined = TRUE THEN 1 END) * 100.0 / COUNT(*) as quarantine_rate
        FROM silver_processing_log
        WHERE start_timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    )
    WHERE quarantine_rate > 10  -- Alert if > 10% quarantined
))
THEN
    CALL SYSTEM$SEND_EMAIL(
        'snowflake_notification',
        'data-team@company.com',
        'High Quarantine Rate Alert',
        'More than 10% of records were quarantined in the last hour.'
    );
```

## 🔒 Security

- Role-based access control (RBAC) with three-tier hierarchy
- Permissions granted on both existing and future objects
- Streamlit app permissions granted to all roles
- Sensitive data can be masked in quarantine records

## 🔬 Field Mapping Methods Comparison

### Method 1: Manual CSV Mapping

**Best For:** Known mappings, production-ready configurations

**Pros:**
- ✅ 100% accuracy (you define it)
- ✅ Fast to load (bulk CSV import)
- ✅ Version controlled (CSV in Git)
- ✅ Easy to review and audit
- ✅ No compute cost

**Cons:**
- ❌ Manual effort required
- ❌ Doesn't scale to many fields
- ❌ No discovery of new fields

**Example:**
```csv
source_field,target_table,target_column,transformation_logic,confidence_score
CUST_ID,CUSTOMER,CUSTOMER_ID,CAST(source_value AS NUMBER),1.0
FNAME,CUSTOMER,FIRST_NAME,UPPER(TRIM(source_value)),1.0
```

### Method 2: ML Pattern Matching

**Best For:** Auto-suggesting mappings for similar field names

**Pros:**
- ✅ Fast execution (< 1 second for 100 fields)
- ✅ No LLM costs
- ✅ Good for obvious matches
- ✅ Multiple algorithms (exact, substring, TF-IDF)
- ✅ Confidence scores for review

**Cons:**
- ❌ Limited to name similarity
- ❌ Doesn't understand semantics
- ❌ May miss complex relationships

**Algorithms:**
1. **Exact Match**: Field names match exactly (confidence: 1.0)
2. **Substring Match**: One name contains the other (confidence: 0.85-0.95)
3. **Sequence Similarity**: Levenshtein distance (confidence: 0.70-0.90)
4. **TF-IDF**: Term frequency similarity (confidence: 0.60-0.85)

**Example:**
```sql
-- Generate ML mappings
CALL auto_map_fields_ml('RAW_DATA_TABLE', 3, 0.6);

-- Results:
-- customer_id → CUSTOMER_ID (confidence: 1.0, exact match)
-- cust_name → CUSTOMER_NAME (confidence: 0.85, substring)
-- email_addr → EMAIL (confidence: 0.72, TF-IDF)
```

### Method 3: LLM Cortex AI

**Best For:** Complex semantic relationships, business context understanding

**Pros:**
- ✅ Understands semantics (e.g., "DOB" → "DATE_OF_BIRTH")
- ✅ Handles abbreviations and synonyms
- ✅ Considers business context
- ✅ Can suggest transformations
- ✅ Learns from descriptions

**Cons:**
- ❌ Slower (1-2 seconds per field)
- ❌ Costs Snowflake credits
- ❌ Requires Cortex AI availability
- ❌ May need prompt tuning

**Models Available:**
- `llama3.1-70b` (default) - Best balance
- `llama3.1-8b` - Faster, lower cost
- `mistral-large` - Alternative option

**Example:**
```sql
-- Generate LLM mappings
CALL auto_map_fields_llm('RAW_DATA_TABLE', 'llama3.1-70b', 'DEFAULT_FIELD_MAPPING');

-- Results (with semantic understanding):
-- DOB → DATE_OF_BIRTH (confidence: 0.95)
-- SSN → SOCIAL_SECURITY_NUMBER (confidence: 0.98)
-- Addr1 → ADDRESS_LINE_1 (confidence: 0.92)
```

### Recommended Strategy

**Phase 1: Manual (Critical Fields)**
- Map 10-20% of critical fields manually
- Ensures core business logic is correct
- Provides examples for ML/LLM

**Phase 2: ML (Bulk Suggestions)**
- Generate suggestions for remaining fields
- Review high-confidence matches (>0.8)
- Approve obvious mappings

**Phase 3: LLM (Complex Cases)**
- Use LLM for low-confidence ML matches
- Handle semantic relationships
- Review and approve all LLM suggestions

**Phase 4: Review & Refine**
- Test transformations with sample data
- Adjust confidence thresholds
- Document custom mappings

## 🎯 Rules Engine Deep Dive

### Rule Types Explained

#### 1. Data Quality Rules (DQ)
**Purpose:** Validate data meets quality standards

**Common Rules:**
- **NOT NULL**: Field must have a value
- **FORMAT**: Field matches pattern (email, phone, SSN)
- **RANGE**: Value within acceptable range
- **LENGTH**: String length constraints
- **REFERENTIAL**: Foreign key validation

**Example:**
```sql
-- Email format validation
INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, target_column,
    rule_logic, priority, error_action
) VALUES (
    'DQ001', 'Valid Email Format', 'DATA_QUALITY', 'EMAIL',
    'RLIKE ''^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$''',
    1, 'QUARANTINE'
);
```

#### 2. Business Logic Rules (BL)
**Purpose:** Apply business calculations and transformations

**Common Rules:**
- **CALCULATION**: Derived fields (age from DOB)
- **LOOKUP**: Reference data joins
- **CONDITIONAL**: If-then-else logic
- **AGGREGATION**: Sum, count, average

**Example:**
```sql
-- Calculate patient age
INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, target_column,
    rule_logic, priority
) VALUES (
    'BL001', 'Calculate Age', 'BUSINESS_LOGIC', 'PATIENT_AGE',
    'DATEDIFF(YEAR, DATE_OF_BIRTH, CURRENT_DATE())',
    10
);
```

#### 3. Standardization Rules (STD)
**Purpose:** Normalize data to consistent format

**Common Rules:**
- **CASE**: Upper/lower/title case
- **TRIM**: Remove whitespace
- **DATE**: Standardize date formats
- **CODE**: Map codes to standard values

**Example:**
```sql
-- Standardize state codes
INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, target_column,
    rule_logic, priority
) VALUES (
    'STD001', 'Standardize State', 'STANDARDIZATION', 'STATE',
    'CASE WHEN STATE IN (''CA'', ''CALIF'') THEN ''CALIFORNIA'' ELSE STATE END',
    20
);
```

#### 4. Deduplication Rules (DD)
**Purpose:** Remove or flag duplicate records

**Strategies:**
- **EXACT**: Exact match on key fields
- **FUZZY**: Similarity-based matching
- **KEEP_FIRST**: Keep oldest record
- **KEEP_LAST**: Keep newest record
- **MERGE**: Combine records

**Example:**
```sql
-- Remove duplicate patients by email
INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, rule_logic,
    rule_parameters, priority
) VALUES (
    'DD001', 'Dedupe by Email', 'DEDUPLICATION', 'EMAIL',
    '{"strategy": "KEEP_LAST", "threshold": 1.0}',
    30
);
```

#### 5. Referential Integrity Rules (REF)
**Purpose:** Ensure relationships between tables are valid

**Common Rules:**
- **FOREIGN_KEY**: Child record has valid parent
- **LOOKUP**: Value exists in reference table
- **SEQUENCE**: Dates/events in correct order

**Example:**
```sql
-- Validate plan type
INSERT INTO transformation_rules (
    rule_id, rule_name, rule_type, target_column,
    rule_logic, priority, error_action
) VALUES (
    'REF001', 'Valid Plan Type', 'REFERENTIAL_INTEGRITY', 'PLAN_TYPE',
    'PLAN_TYPE IN (''PPO'', ''HMO'', ''EPO'', ''POS'')',
    5, 'REJECT'
);
```

### Rule Execution Order

Rules execute in **priority order** (lower number = higher priority):

```
Priority 1-10:   Data Quality (critical validations)
Priority 11-20:  Business Logic (calculations)
Priority 21-30:  Standardization (formatting)
Priority 31-40:  Deduplication (duplicate removal)
Priority 41-50:  Referential Integrity (relationships)
```

### Error Actions

**REJECT:**
- Record is not loaded
- Entire batch fails if any record rejected
- Use for critical validations

**QUARANTINE:**
- Record moves to `quarantine_records` table
- Batch continues processing
- Review and remediate later

**FLAG:**
- Record is loaded with warning flag
- Batch continues processing
- Review flagged records periodically

**CORRECT:**
- Rule attempts automatic correction
- If correction fails, falls back to QUARANTINE
- Use for standardization rules

## 📊 Performance Tuning

### Batch Size Optimization

**Small Batches (1,000-5,000 records):**
- ✅ Faster feedback
- ✅ Lower memory usage
- ✅ Easier error recovery
- ❌ More overhead
- ❌ Slower overall throughput

**Medium Batches (10,000-50,000 records):**
- ✅ Good balance
- ✅ Efficient resource usage
- ✅ Reasonable error recovery
- **Recommended for most use cases**

**Large Batches (100,000+ records):**
- ✅ Maximum throughput
- ✅ Lowest overhead
- ❌ Higher memory usage
- ❌ Longer recovery time on errors

### Warehouse Sizing

| Warehouse Size | Records/Minute | Best For |
|----------------|----------------|----------|
| X-Small | ~5,000 | Development, testing |
| Small | ~10,000 | Small production loads |
| Medium | ~25,000 | **Recommended for production** |
| Large | ~50,000 | High-volume processing |
| X-Large | ~100,000 | Very large datasets |

### Optimization Checklist

- [ ] Use appropriate batch size for data volume
- [ ] Enable incremental processing for large datasets
- [ ] Optimize transformation rules (avoid complex SQL)
- [ ] Use MERGE for upserts (not DELETE + INSERT)
- [ ] Partition large tables by date
- [ ] Use clustering keys for large tables
- [ ] Monitor query profiles for bottlenecks
- [ ] Adjust warehouse size based on load

## 🔐 Security & Compliance

### Data Privacy
- **Quarantine Isolation**: Failed records separated from production
- **Audit Trail**: Complete lineage from Bronze to Silver
- **Access Control**: Role-based permissions
- **Encryption**: All data encrypted at rest and in transit

### Compliance Features
- **GDPR**: Right to erasure (delete from quarantine)
- **HIPAA**: Audit trails and access controls
- **SOC 2**: Monitoring and alerting
- **Data Lineage**: Track transformations

### Best Practices
1. **Mask PII**: Use Snowflake masking policies
2. **Audit Access**: Monitor who accesses sensitive data
3. **Quarantine Review**: Regular review of failed records
4. **Data Retention**: Define and enforce retention policies
5. **Encryption**: Enable SSE on all stages

## 📄 License

This project is provided as-is for data transformation workflows.

---

*Last Updated: January 2, 2026*  
*Version: 2.0*  
*Status: Production Ready ✅*

