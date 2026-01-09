-- ============================================
-- SILVER LAYER SCHEMA SETUP
-- ============================================
-- Purpose: Set up Silver layer infrastructure for data transformation
-- 
-- This script creates:
--   1. Silver schema with stages for transformation and configuration
--   2. Metadata tables for dynamic schema definition and field mappings
--   3. Rules engine tables for transformation logic
--   4. Processing log and data quality tracking tables
--   5. RBAC permissions for existing roles
--
-- Architecture:
--   - Bronze RAW_DATA_TABLE is the source
--   - Field mappings define Bronze → Silver transformations
--   - Rules engine applies data quality and business logic
--   - Target schemas are defined dynamically via metadata
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

-- Set environment variables
SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';
SET WAREHOUSE_NAME = '$WAREHOUSE_NAME';

-- Set role names
SET role_admin = (SELECT '$DATABASE_NAME' || '_ADMIN');
SET role_readwrite = (SELECT '$DATABASE_NAME' || '_READWRITE');
SET role_readonly = (SELECT '$DATABASE_NAME' || '_READONLY');

-- ============================================
-- SCHEMA SETUP
-- ============================================

-- Use admin role for full permissions
USE ROLE IDENTIFIER($role_admin);
USE DATABASE IDENTIFIER($DATABASE_NAME);

-- Create Silver schema if not exists
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($SILVER_SCHEMA_NAME)
COMMENT = 'Silver layer: Clean, standardized, business-ready data with applied transformations and data quality rules';

USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- STAGE CREATION
-- ============================================

-- Set stage name variables
SET SILVER_STAGE_NAME = '$SILVER_STAGE_NAME';
SET SILVER_CONFIG_STAGE_NAME = '$SILVER_CONFIG_STAGE_NAME';
SET SILVER_STREAMLIT_STAGE_NAME = '$SILVER_STREAMLIT_STAGE_NAME';

-- Create stage for intermediate transformation files
CREATE STAGE IF NOT EXISTS IDENTIFIER($SILVER_STAGE_NAME)
DIRECTORY = (ENABLE = TRUE)
ENCRYPTION = (TYPE='SNOWFLAKE_SSE')
COMMENT = 'Stage for intermediate transformation files and temporary data';

-- Create stage for mapping and rules configuration files
CREATE STAGE IF NOT EXISTS IDENTIFIER($SILVER_CONFIG_STAGE_NAME)
DIRECTORY = (ENABLE = TRUE)
ENCRYPTION = (TYPE='SNOWFLAKE_SSE')
COMMENT = 'Stage for field mappings, target schemas, and transformation rules CSV files';

-- Create stage for Streamlit application files (in PUBLIC schema)
USE SCHEMA PUBLIC;
CREATE STAGE IF NOT EXISTS IDENTIFIER($SILVER_STREAMLIT_STAGE_NAME)
DIRECTORY = (ENABLE = TRUE)
ENCRYPTION = (TYPE='SNOWFLAKE_SSE')
COMMENT = 'Stage for Silver layer Streamlit management application';
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME); -- Switch back to Silver schema

-- ============================================
-- METADATA TABLES
-- ============================================

-- Target Schemas: Dynamic target table definitions
CREATE TABLE IF NOT EXISTS target_schemas (
    schema_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(500) NOT NULL,
    column_name VARCHAR(500) NOT NULL,
    data_type VARCHAR(200) NOT NULL,
    nullable BOOLEAN DEFAULT TRUE,
    default_value VARCHAR(1000),
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    active BOOLEAN DEFAULT TRUE,
    CONSTRAINT uk_target_schemas UNIQUE (table_name, column_name)
)
COMMENT = 'Metadata table defining Silver layer target table schemas dynamically';

-- Field Mappings: Bronze → Silver field mappings
CREATE TABLE IF NOT EXISTS field_mappings (
    mapping_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_field VARCHAR(500) NOT NULL,
    source_table VARCHAR(500) DEFAULT 'RAW_DATA_TABLE',
    target_table VARCHAR(500) NOT NULL,
    target_column VARCHAR(500) NOT NULL,
    mapping_method VARCHAR(50) NOT NULL, -- MANUAL, ML_AUTO, LLM_CORTEX
    confidence_score FLOAT,
    transformation_logic VARCHAR(5000), -- Optional SQL expression for transformation
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    approved BOOLEAN DEFAULT FALSE,
    approved_by VARCHAR(500),
    approved_timestamp TIMESTAMP_NTZ,
    CONSTRAINT uk_field_mappings UNIQUE (source_field, source_table, target_table, target_column)
)
COMMENT = 'Field mappings from Bronze to Silver with confidence scores and transformation logic. Valid mapping_method values: MANUAL, ML_AUTO, LLM_CORTEX. Mappings must be approved before use in transformations.';

-- Known Field Mappings: Reference data for ML training
CREATE TABLE IF NOT EXISTS known_field_mappings (
    mapping_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_field VARCHAR(500) NOT NULL,
    target_field VARCHAR(500) NOT NULL,
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    active BOOLEAN DEFAULT TRUE,
    CONSTRAINT uk_known_field_mappings UNIQUE (source_field, target_field)
)
COMMENT = 'Known field mapping patterns for ML algorithm training. Contains generic source-to-target field name mappings.';

-- Insert sample known field mappings for ML training (using MERGE to avoid duplicates)
MERGE INTO known_field_mappings AS target
USING (
    SELECT * FROM VALUES
        -- File metadata mappings
        ('FILE_NAME', 'SOURCE_FILE_NAME', 'Maps raw file name to standardized source file name column', TRUE),
        ('FILENAME', 'SOURCE_FILE_NAME', 'Alternative file name field to source file name', TRUE),
        ('FILE_PATH', 'SOURCE_FILE_PATH', 'Maps file path to standardized source file path column', TRUE),
        ('FILE_SIZE', 'FILE_SIZE_BYTES', 'Maps file size to bytes column', TRUE),
        ('FILESIZE', 'FILE_SIZE_BYTES', 'Alternative file size field', TRUE),
        
        -- Timestamp mappings
        ('LOAD_TIMESTAMP', 'INGESTION_TIMESTAMP', 'Maps load timestamp to ingestion timestamp', TRUE),
        ('LOAD_TIME', 'INGESTION_TIMESTAMP', 'Alternative load time field', TRUE),
        ('CREATED_DATE', 'CREATED_TIMESTAMP', 'Maps created date to timestamp', TRUE),
        ('CREATE_DATE', 'CREATED_TIMESTAMP', 'Alternative created date field', TRUE),
        ('MODIFIED_DATE', 'UPDATED_TIMESTAMP', 'Maps modified date to updated timestamp', TRUE),
        ('UPDATE_DATE', 'UPDATED_TIMESTAMP', 'Alternative update date field', TRUE),
        ('PROCESS_DATE', 'PROCESSING_TIMESTAMP', 'Maps process date to processing timestamp', TRUE),
        
        -- Record metadata mappings
        ('ROW_NUMBER', 'RECORD_COUNT', 'Maps row number to record count', TRUE),
        ('RECORD_ID', 'RECORD_ID', 'Direct mapping for record identifier', TRUE),
        ('ID', 'RECORD_ID', 'Generic ID to record ID', TRUE),
        ('BATCH_ID', 'BATCH_ID', 'Direct mapping for batch identifier', TRUE),
        
        -- Customer/Entity mappings
        ('CUSTOMER_ID', 'CUSTOMER_ID', 'Direct customer identifier mapping', TRUE),
        ('CUST_ID', 'CUSTOMER_ID', 'Abbreviated customer ID', TRUE),
        ('CUSTOMER_NAME', 'CUSTOMER_NAME', 'Direct customer name mapping', TRUE),
        ('CUST_NAME', 'CUSTOMER_NAME', 'Abbreviated customer name', TRUE),
        ('ACCOUNT_ID', 'ACCOUNT_ID', 'Direct account identifier mapping', TRUE),
        ('ACCT_ID', 'ACCOUNT_ID', 'Abbreviated account ID', TRUE),
        
        -- Order/Transaction mappings
        ('ORDER_ID', 'ORDER_ID', 'Direct order identifier mapping', TRUE),
        ('ORDER_NUMBER', 'ORDER_NUMBER', 'Direct order number mapping', TRUE),
        ('ORDER_DATE', 'ORDER_DATE', 'Direct order date mapping', TRUE),
        ('TRANSACTION_ID', 'TRANSACTION_ID', 'Direct transaction identifier mapping', TRUE),
        ('TRANS_ID', 'TRANSACTION_ID', 'Abbreviated transaction ID', TRUE),
        ('TRANSACTION_DATE', 'TRANSACTION_DATE', 'Direct transaction date mapping', TRUE),
        ('TRANS_DATE', 'TRANSACTION_DATE', 'Abbreviated transaction date', TRUE),
        
        -- Amount/Value mappings
        ('AMOUNT', 'AMOUNT', 'Direct amount mapping', TRUE),
        ('TOTAL_AMOUNT', 'TOTAL_AMOUNT', 'Direct total amount mapping', TRUE),
        ('PRICE', 'UNIT_PRICE', 'Maps price to unit price', TRUE),
        ('UNIT_PRICE', 'UNIT_PRICE', 'Direct unit price mapping', TRUE),
        ('QUANTITY', 'QUANTITY', 'Direct quantity mapping', TRUE),
        ('QTY', 'QUANTITY', 'Abbreviated quantity', TRUE),
        
        -- Status/Flag mappings
        ('STATUS', 'STATUS', 'Direct status mapping', TRUE),
        ('ACTIVE', 'IS_ACTIVE', 'Maps active flag to is_active boolean', TRUE),
        ('DELETED', 'IS_DELETED', 'Maps deleted flag to is_deleted boolean', TRUE),
        ('ENABLED', 'IS_ENABLED', 'Maps enabled flag to is_enabled boolean', TRUE),
        
        -- Address mappings
        ('ADDRESS', 'ADDRESS_LINE_1', 'Maps address to first address line', TRUE),
        ('STREET', 'ADDRESS_LINE_1', 'Maps street to first address line', TRUE),
        ('CITY', 'CITY', 'Direct city mapping', TRUE),
        ('STATE', 'STATE', 'Direct state mapping', TRUE),
        ('ZIP', 'POSTAL_CODE', 'Maps zip to postal code', TRUE),
        ('ZIPCODE', 'POSTAL_CODE', 'Alternative zip code field', TRUE),
        ('POSTAL_CODE', 'POSTAL_CODE', 'Direct postal code mapping', TRUE),
        ('COUNTRY', 'COUNTRY', 'Direct country mapping', TRUE),
        
        -- Contact mappings
        ('EMAIL', 'EMAIL_ADDRESS', 'Maps email to email address', TRUE),
        ('EMAIL_ADDRESS', 'EMAIL_ADDRESS', 'Direct email address mapping', TRUE),
        ('PHONE', 'PHONE_NUMBER', 'Maps phone to phone number', TRUE),
        ('PHONE_NUMBER', 'PHONE_NUMBER', 'Direct phone number mapping', TRUE),
        ('MOBILE', 'MOBILE_NUMBER', 'Maps mobile to mobile number', TRUE),
        
        -- Description/Notes mappings
        ('DESCRIPTION', 'DESCRIPTION', 'Direct description mapping', TRUE),
        ('DESC', 'DESCRIPTION', 'Abbreviated description', TRUE),
        ('NOTES', 'NOTES', 'Direct notes mapping', TRUE),
        ('COMMENTS', 'COMMENTS', 'Direct comments mapping', TRUE),
        
        -- Category/Type mappings
        ('CATEGORY', 'CATEGORY', 'Direct category mapping', TRUE),
        ('TYPE', 'TYPE', 'Direct type mapping', TRUE),
        ('CLASS', 'CLASS', 'Direct class mapping', TRUE),
        ('CLASSIFICATION', 'CLASSIFICATION', 'Direct classification mapping', TRUE)
) AS source (source_field, target_field, description, active)
ON target.source_field = source.source_field AND target.target_field = source.target_field
WHEN NOT MATCHED THEN
    INSERT (source_field, target_field, description, active)
    VALUES (source.source_field, source.target_field, source.description, source.active);

-- Transformation Rules: Rules engine definitions
CREATE TABLE IF NOT EXISTS transformation_rules (
    rule_id VARCHAR(50) PRIMARY KEY,
    rule_name VARCHAR(500) NOT NULL,
    rule_type VARCHAR(50) NOT NULL, -- DATA_QUALITY, BUSINESS_LOGIC, STANDARDIZATION, DEDUPLICATION
    target_table VARCHAR(500),
    target_column VARCHAR(500),
    rule_logic VARCHAR(5000) NOT NULL, -- SQL expression or condition
    rule_parameters VARIANT, -- JSON for complex rule configurations
    priority INTEGER DEFAULT 100,
    error_action VARCHAR(50) DEFAULT 'LOG', -- LOG, REJECT, QUARANTINE
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    active BOOLEAN DEFAULT TRUE
)
COMMENT = 'Transformation rules for data quality, business logic, standardization, and deduplication. Valid rule_type: DATA_QUALITY, BUSINESS_LOGIC, STANDARDIZATION, DEDUPLICATION. Valid error_action: LOG, REJECT, QUARANTINE';

-- Silver Processing Log: Transformation audit trail
CREATE TABLE IF NOT EXISTS silver_processing_log (
    batch_id VARCHAR(100) PRIMARY KEY,
    source_table VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    start_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    end_timestamp TIMESTAMP_NTZ,
    status VARCHAR(50) DEFAULT 'PROCESSING', -- PROCESSING, SUCCESS, FAILED, QUARANTINED
    records_read INTEGER,
    records_processed INTEGER,
    records_inserted INTEGER,
    records_updated INTEGER,
    records_rejected INTEGER,
    rules_applied INTEGER,
    error_message VARCHAR(5000),
    processing_metadata VARIANT, -- JSON for additional processing details
    created_by VARCHAR(500) DEFAULT CURRENT_USER()
)
COMMENT = 'Audit trail for Silver layer transformation batches. Valid status values: PROCESSING, SUCCESS, FAILED, QUARANTINED';

-- Data Quality Metrics: Quality tracking
CREATE TABLE IF NOT EXISTS data_quality_metrics (
    metric_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    batch_id VARCHAR(100),
    table_name VARCHAR(500) NOT NULL,
    column_name VARCHAR(500),
    metric_type VARCHAR(100) NOT NULL, -- NULL_COUNT, FORMAT_VIOLATIONS, RANGE_VIOLATIONS, DUPLICATE_COUNT, etc.
    metric_value FLOAT NOT NULL,
    threshold_value FLOAT,
    pass_fail VARCHAR(10), -- PASS, FAIL, WARNING
    rule_id VARCHAR(50),
    measurement_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    details VARIANT, -- JSON for additional metric details
    FOREIGN KEY (batch_id) REFERENCES silver_processing_log(batch_id),
    FOREIGN KEY (rule_id) REFERENCES transformation_rules(rule_id)
)
COMMENT = 'Data quality metrics tracking for Silver layer tables. Valid pass_fail values: PASS, FAIL, WARNING';

-- Quarantine Table: Records that failed validation
CREATE TABLE IF NOT EXISTS quarantine_records (
    quarantine_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    batch_id VARCHAR(100),
    source_table VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    source_record VARIANT NOT NULL, -- Original Bronze record
    failed_rules VARIANT, -- Array of rule_ids that failed
    error_details VARIANT, -- JSON with detailed error information
    quarantine_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    resolved BOOLEAN DEFAULT FALSE,
    resolution_action VARCHAR(100),
    resolution_timestamp TIMESTAMP_NTZ,
    resolution_by VARCHAR(500),
    FOREIGN KEY (batch_id) REFERENCES silver_processing_log(batch_id)
)
COMMENT = 'Quarantine table for records that failed validation rules';

-- Processing Watermarks: Track incremental processing state
CREATE TABLE IF NOT EXISTS processing_watermarks (
    watermark_id VARCHAR(100) PRIMARY KEY,
    source_table VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    last_processed_id NUMBER(38,0),
    last_processed_timestamp TIMESTAMP_NTZ,
    records_processed NUMBER(38,0) DEFAULT 0,
    last_batch_id VARCHAR(100),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Watermarks for incremental Bronze to Silver processing';

-- LLM Prompt Templates: Customizable prompts for LLM-assisted mapping
CREATE TABLE IF NOT EXISTS llm_prompt_templates (
    template_id VARCHAR(50) PRIMARY KEY,
    template_name VARCHAR(500) NOT NULL,
    template_text VARCHAR(10000) NOT NULL,
    model_name VARCHAR(100),
    description VARCHAR(5000),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    active BOOLEAN DEFAULT TRUE
)
COMMENT = 'Customizable prompt templates for LLM-assisted field mapping';

-- Insert default LLM prompt template (using MERGE to avoid duplicates)
MERGE INTO llm_prompt_templates AS target
USING (
    SELECT 
        'DEFAULT_FIELD_MAPPING' AS template_id,
        'Default Field Mapping Prompt' AS template_name,
        'You are a data mapping expert. Given the following source fields from a Bronze data table and target fields from a Silver schema, create accurate field mappings.

Source Fields (Bronze):
{source_fields}

Target Fields (Silver) - YOU MUST ONLY MAP TO THESE EXACT COLUMNS:
{target_fields}

CRITICAL INSTRUCTIONS:
1. ONLY map to target fields that are listed above - DO NOT invent or suggest new column names
2. Match each source field to the most appropriate target field based on semantic meaning
3. Consider common abbreviations (amt=Amount, dt=Date, id=Identifier, qty=Quantity, etc.)
4. Each target field should be mapped only once (one-to-one mapping)
5. Return confidence scores (0-1) for each mapping
6. If no good match exists in the target fields list, omit the mapping entirely
7. DO NOT create mappings to columns that are not in the target fields list above

OUTPUT FORMAT:
Return ONLY a valid JSON array. Do not include any explanatory text, markdown formatting, or code blocks. Start your response with [ and end with ].

Required JSON structure:
[
  {
    "source_field": "source_field_name",
    "target_field": "TABLE.COLUMN_NAME",
    "confidence": 0.95,
    "reasoning": "brief explanation"
  }
]

Example response:
[{"source_field": "claim_id", "target_field": "CLAIMS.CLAIM_NUM", "confidence": 0.95, "reasoning": "Direct match for claim identifier"}]

REMEMBER: Only use target field names from the list provided above. Any mappings to unlisted columns will be rejected.' AS template_text,
        'Default prompt template for LLM-assisted field mapping using Snowflake Cortex AI' AS description
) AS source
ON target.template_id = source.template_id
WHEN NOT MATCHED THEN
    INSERT (template_id, template_name, template_text, description)
    VALUES (source.template_id, source.template_name, source.template_text, source.description);

-- ============================================
-- GRANT PERMISSIONS TO ROLES
-- ============================================
-- Purpose: Grant appropriate permissions on Silver schema objects
-- to READWRITE and READONLY roles

USE ROLE IDENTIFIER($role_admin);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- Grant schema usage to all roles
GRANT USAGE ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);
GRANT USAGE ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT ALL PRIVILEGES ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);

-- ============================================
-- READONLY ROLE GRANTS
-- ============================================

-- SELECT on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);
-- SELECT on all future tables
GRANT SELECT ON FUTURE TABLES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- READ on all existing stages
GRANT READ ON ALL STAGES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);
-- READ on all future stages
GRANT READ ON FUTURE STAGES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- USAGE on all existing procedures
GRANT USAGE ON ALL PROCEDURES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);
-- USAGE on all future procedures
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- MONITOR on all existing tasks
GRANT MONITOR ON ALL TASKS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);
-- MONITOR on all future tasks
GRANT MONITOR ON FUTURE TASKS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readonly);

-- ============================================
-- READWRITE ROLE GRANTS
-- ============================================

-- DML on all existing tables
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
-- DML on all future tables
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- READ and WRITE on all existing stages
GRANT READ, WRITE ON ALL STAGES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
-- READ and WRITE on all future stages
GRANT READ, WRITE ON FUTURE STAGES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- CREATE privileges on schema (must be granted separately)
GRANT CREATE TABLE ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE VIEW ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE STAGE ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE FILE FORMAT ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE SEQUENCE ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE FUNCTION ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT CREATE PROCEDURE ON SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- OPERATE on all existing tasks
GRANT OPERATE ON ALL TASKS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);
-- OPERATE on all future tasks
GRANT OPERATE ON FUTURE TASKS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_readwrite);

-- ============================================
-- ADMIN ROLE GRANTS (ALL PRIVILEGES)
-- ============================================

-- ALL PRIVILEGES on all existing objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL VIEWS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL STAGES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL FILE FORMATS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON ALL TASKS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);

-- ALL PRIVILEGES on all future objects
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE VIEWS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE STAGES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE FILE FORMATS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE SEQUENCES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE FUNCTIONS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE PROCEDURES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT ALL PRIVILEGES ON FUTURE TASKS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);

-- Grant cross-schema access to Bronze schema for Silver transformations
GRANT USAGE ON SCHEMA IDENTIFIER($DATABASE_NAME || '.' || $BRONZE_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT SELECT ON ALL TABLES IN SCHEMA IDENTIFIER($DATABASE_NAME || '.' || $BRONZE_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT SELECT ON FUTURE TABLES IN SCHEMA IDENTIFIER($DATABASE_NAME || '.' || $BRONZE_SCHEMA_NAME) TO ROLE IDENTIFIER($role_admin);

-- ============================================
-- LOAD SAMPLE TRANSFORMATION RULES
-- ============================================
-- Purpose: Load sample transformation rules for healthcare claims processing
-- Note: This uses MERGE to be idempotent - safe to run multiple times

MERGE INTO transformation_rules AS target
USING (
    SELECT * FROM (VALUES
        -- Data Quality Rules
        ('DQ001', 'Validate First Name Not Null', 'DATA_QUALITY', 'CLAIMS', 'FIRST_NAME', 'IS NOT NULL', NULL::VARIANT, 10, 'REJECT', 'Ensure patient first name is always populated', TRUE),
        ('DQ002', 'Validate Last Name Not Null', 'DATA_QUALITY', 'CLAIMS', 'LAST_NAME', 'IS NOT NULL', NULL::VARIANT, 10, 'REJECT', 'Ensure patient last name is always populated', TRUE),
        ('DQ003', 'Validate Date of Birth Format', 'DATA_QUALITY', 'CLAIMS', 'DOB', 'IS NOT NULL AND TRY_TO_DATE(DOB) IS NOT NULL', NULL::VARIANT, 20, 'QUARANTINE', 'Ensure DOB is a valid date', TRUE),
        ('DQ004', 'Validate Claim Number Format', 'DATA_QUALITY', 'CLAIMS', 'CLAIM_NUM', 'RLIKE ''^[A-Z0-9]{8,20}$''', NULL::VARIANT, 30, 'QUARANTINE', 'Claim number must be 8-20 alphanumeric characters', TRUE),
        ('DQ005', 'Validate Billed Charges Non-Negative', 'DATA_QUALITY', 'CLAIMS', 'BILLED_CHARGES', '>= 0', NULL::VARIANT, 40, 'REJECT', 'Billed charges cannot be negative', TRUE),
        ('DQ006', 'Validate Allowed Amount Non-Negative', 'DATA_QUALITY', 'CLAIMS', 'ALLOWED_AMT', '>= 0', NULL::VARIANT, 40, 'REJECT', 'Allowed amount cannot be negative', TRUE),
        ('DQ007', 'Validate Deductible Non-Negative', 'DATA_QUALITY', 'CLAIMS', 'DEDUCTIBLE', '>= 0', NULL::VARIANT, 40, 'REJECT', 'Deductible cannot be negative', TRUE),
        ('DQ008', 'Validate Copay Non-Negative', 'DATA_QUALITY', 'CLAIMS', 'COPAY', '>= 0', NULL::VARIANT, 40, 'REJECT', 'Copay cannot be negative', TRUE),
        ('DQ009', 'Validate Coinsurance Non-Negative', 'DATA_QUALITY', 'CLAIMS', 'COINSURANCE', '>= 0', NULL::VARIANT, 40, 'REJECT', 'Coinsurance cannot be negative', TRUE),
        ('DQ010', 'Validate Plan Paid Non-Negative', 'DATA_QUALITY', 'CLAIMS', 'PLAN_PAID', '>= 0', NULL::VARIANT, 40, 'REJECT', 'Plan paid amount cannot be negative', TRUE),
        ('DQ011', 'Validate Claim Type Values', 'DATA_QUALITY', 'CLAIMS', 'CLAIM_TYPE', 'IN (''MEDICAL'', ''PHARMACY'', ''DENTAL'', ''VISION'', ''MENTAL_HEALTH'')', NULL::VARIANT, 50, 'LOG', 'Claim type must be one of the valid values', TRUE),
        ('DQ012', 'Validate Plan Type Values', 'DATA_QUALITY', 'CLAIMS', 'PLAN_TYPE', 'IN (''HMO'', ''PPO'', ''EPO'', ''POS'', ''HDHP'')', NULL::VARIANT, 50, 'LOG', 'Plan type must be one of the valid values', TRUE),
        ('DQ013', 'Validate Provider NPI Format', 'DATA_QUALITY', 'CLAIMS', 'PROVIDER_NPI', 'RLIKE ''^[0-9]{10}$''', NULL::VARIANT, 60, 'QUARANTINE', 'Provider NPI must be exactly 10 digits', TRUE),
        ('DQ014', 'Validate Provider TIN Format', 'DATA_QUALITY', 'CLAIMS', 'PROVIDER_TIN', 'RLIKE ''^[0-9]{9}$''', NULL::VARIANT, 60, 'QUARANTINE', 'Provider TIN must be exactly 9 digits (EIN format)', TRUE),
        -- Standardization Rules
        ('STD001', 'Standardize First Name', 'STANDARDIZATION', 'CLAIMS', 'FIRST_NAME', 'UPPER', NULL::VARIANT, 100, 'LOG', 'Convert first name to uppercase', TRUE),
        ('STD002', 'Standardize Last Name', 'STANDARDIZATION', 'CLAIMS', 'LAST_NAME', 'UPPER', NULL::VARIANT, 100, 'LOG', 'Convert last name to uppercase', TRUE),
        ('STD003', 'Standardize Subscriber First Name', 'STANDARDIZATION', 'CLAIMS', 'SUBSCRIBER_FIRST', 'UPPER', NULL::VARIANT, 100, 'LOG', 'Convert subscriber first name to uppercase', TRUE),
        ('STD004', 'Standardize Subscriber Last Name', 'STANDARDIZATION', 'CLAIMS', 'SUBSCRIBER_LAST', 'UPPER', NULL::VARIANT, 100, 'LOG', 'Convert subscriber last name to uppercase', TRUE),
        ('STD005', 'Standardize Group Name', 'STANDARDIZATION', 'CLAIMS', 'GROUP_NAME', 'UPPER', NULL::VARIANT, 100, 'LOG', 'Convert group name to uppercase', TRUE),
        ('STD006', 'Standardize Provider Name', 'STANDARDIZATION', 'CLAIMS', 'PROVIDER_NAME', 'UPPER', NULL::VARIANT, 100, 'LOG', 'Convert provider name to uppercase', TRUE),
        ('STD007', 'Trim Provider Address', 'STANDARDIZATION', 'CLAIMS', 'PROVIDER_ADDRESS', 'TRIM', NULL::VARIANT, 110, 'LOG', 'Remove leading/trailing whitespace from provider address', TRUE),
        ('STD008', 'Standardize Claim Type', 'STANDARDIZATION', 'CLAIMS', 'CLAIM_TYPE', 'UPPER', NULL::VARIANT, 110, 'LOG', 'Convert claim type to uppercase', TRUE),
        ('STD009', 'Standardize Plan Type', 'STANDARDIZATION', 'CLAIMS', 'PLAN_TYPE', 'UPPER', NULL::VARIANT, 110, 'LOG', 'Convert plan type to uppercase', TRUE)
    ) AS t (rule_id, rule_name, rule_type, target_table, target_column, rule_logic, rule_parameters, priority, error_action, description, active)
    UNION ALL
    SELECT 'DD001', 'Deduplicate by Claim Number', 'DEDUPLICATION', 'CLAIMS', NULL, 'CLAIM_NUM', 
           PARSE_JSON('{"strategy": "KEEP_FIRST"}'), 300, 'LOG', 'Remove duplicate claims keeping the first occurrence', TRUE
) AS source
ON target.rule_id = source.rule_id
WHEN MATCHED THEN UPDATE SET
    rule_name = source.rule_name,
    rule_type = source.rule_type,
    target_table = source.target_table,
    target_column = source.target_column,
    rule_logic = source.rule_logic,
    rule_parameters = source.rule_parameters,
    priority = source.priority,
    error_action = source.error_action,
    description = source.description,
    active = source.active,
    updated_timestamp = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    rule_id, rule_name, rule_type, target_table, target_column,
    rule_logic, rule_parameters, priority, error_action, description, active
) VALUES (
    source.rule_id, source.rule_name, source.rule_type, source.target_table, source.target_column,
    source.rule_logic, source.rule_parameters, source.priority, source.error_action, source.description, source.active
);

-- ============================================
-- TRANSFORMATION MONITORING VIEWS
-- ============================================

-- View: Transformation Status Summary
CREATE OR REPLACE VIEW v_transformation_status_summary AS
SELECT 
    target_table,
    status,
    COUNT(*) AS batch_count,
    SUM(records_processed) AS total_processed,
    SUM(records_rejected) AS total_rejected,
    AVG(DATEDIFF(second, start_timestamp, end_timestamp)) AS avg_duration_seconds,
    MAX(end_timestamp) AS last_batch_timestamp
FROM silver_processing_log
WHERE end_timestamp IS NOT NULL
GROUP BY target_table, status
ORDER BY target_table, status;

COMMENT ON VIEW v_transformation_status_summary IS 'Summary of transformation batches by target table and status. Shows batch counts, total records processed/rejected, average duration, and last batch timestamp.';

-- View: Recent Transformation Batches
CREATE OR REPLACE VIEW v_recent_transformation_batches AS
SELECT 
    batch_id,
    source_table,
    target_table,
    status,
    records_read,
    records_processed,
    records_rejected,
    rules_applied,
    DATEDIFF(second, start_timestamp, end_timestamp) AS duration_seconds,
    start_timestamp,
    end_timestamp,
    error_message
FROM silver_processing_log
ORDER BY start_timestamp DESC
LIMIT 100;

COMMENT ON VIEW v_recent_transformation_batches IS 'Most recent 100 transformation batches with full details. Shows source/target tables, processing statistics, timing, and any error messages.';

-- View: Data Quality Dashboard
CREATE OR REPLACE VIEW v_data_quality_dashboard AS
SELECT 
    dqm.metric_id,
    dqm.batch_id,
    dqm.table_name,
    dqm.column_name,
    dqm.metric_type,
    dqm.metric_value,
    dqm.threshold_value,
    dqm.pass_fail,
    dqm.rule_id,
    dqm.measurement_timestamp,
    dqm.details
FROM data_quality_metrics dqm
ORDER BY 
    CASE 
        WHEN dqm.pass_fail = 'FAIL' THEN 1 
        WHEN dqm.pass_fail = 'WARNING' THEN 2 
        ELSE 3 
    END,
    dqm.measurement_timestamp DESC;

COMMENT ON VIEW v_data_quality_dashboard IS 'Data quality metrics dashboard showing all metrics with pass/fail status. Ordered by failing metrics first for quick identification of issues.';

-- View: Quarantine Summary
CREATE OR REPLACE VIEW v_quarantine_summary AS
SELECT 
    target_table,
    COUNT(*) AS total_quarantined_records,
    COUNT(CASE WHEN resolved = TRUE THEN 1 END) AS resolved_records,
    COUNT(CASE WHEN resolved = FALSE THEN 1 END) AS unresolved_records,
    MIN(quarantine_timestamp) AS first_quarantine_timestamp,
    MAX(quarantine_timestamp) AS last_quarantine_timestamp
FROM quarantine_records
GROUP BY target_table
ORDER BY unresolved_records DESC, total_quarantined_records DESC;

COMMENT ON VIEW v_quarantine_summary IS 'Summary of quarantined records by target table. Shows total, resolved, and unresolved counts with first and last quarantine timestamps.';

-- View: Watermark Status
CREATE OR REPLACE VIEW v_watermark_status AS
SELECT 
    watermark_id,
    source_table,
    target_table,
    last_processed_id,
    last_processed_timestamp,
    records_processed,
    last_batch_id,
    updated_timestamp,
    DATEDIFF('hour', updated_timestamp, CURRENT_TIMESTAMP()) AS hours_since_update,
    CASE 
        WHEN updated_timestamp IS NULL THEN 'Never Processed'
        WHEN DATEDIFF('hour', updated_timestamp, CURRENT_TIMESTAMP()) > 24 THEN 'Stale (>24h)'
        WHEN DATEDIFF('hour', updated_timestamp, CURRENT_TIMESTAMP()) > 6 THEN 'Warning (>6h)'
        ELSE 'Current'
    END AS status
FROM processing_watermarks
ORDER BY updated_timestamp DESC NULLS LAST;

COMMENT ON VIEW v_watermark_status IS 'Processing watermark status showing last processed timestamps and staleness indicators. Helps monitor incremental processing health.';

