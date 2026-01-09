-- ============================================
-- DEPLOY STREAMLIT APP TO SNOWFLAKE
-- ============================================
-- This script deploys the Streamlit application as a 
-- Streamlit in Snowflake (SiS) app to the PUBLIC schema
--
-- Prerequisites:
--   - ACCOUNTADMIN role (or appropriate privileges)
--   - Streamlit enabled in your account
--   - Pipeline already deployed (run deploy.sh first)
--   - Configuration files uploaded to @PUBLIC.CONFIG_STAGE
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================
-- Note: These values will be replaced by deploy.sh
-- Do not edit manually if using deploy.sh
SET DATABASE_NAME = 'db_ingest_pipeline';
SET SCHEMA_NAME = 'BRONZE';

USE ROLE ACCOUNTADMIN;  -- Required for creating Streamlit apps

-- ============================================
-- CREATE STAGES IN PUBLIC SCHEMA
-- ============================================

USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA PUBLIC;

-- Create stage for Streamlit app files
CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE='SNOWFLAKE_SSE')
    COMMENT = 'Stage for Streamlit in Snowflake application files';

-- Create stage for configuration files
CREATE STAGE IF NOT EXISTS CONFIG_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE='SNOWFLAKE_SSE')
    COMMENT = 'Stage for configuration files (default.config, custom.config)';

-- ============================================
-- CREATE STREAMLIT APP IN PUBLIC SCHEMA
-- ============================================

-- Create the Streamlit app with user-friendly name
-- Note: Files uploaded via PUT/snow stage copy create a subdirectory
-- ROOT_LOCATION points to the stage root, MAIN_FILE includes the subdirectory path
CREATE OR REPLACE STREAMLIT IDENTIFIER($STREAMLIT_APP_NAME)
    ROOT_LOCATION = '@STREAMLIT_STAGE'
    MAIN_FILE = '/streamlit_stage/streamlit_app.py'
    QUERY_WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    COMMENT = 'File Processing Pipeline - Upload and Management Interface';

-- Set the Python environment file (must be done via ALTER, not CREATE)
ALTER STREAMLIT IDENTIFIER($STREAMLIT_APP_NAME)
SET IMPORTS = ('@STREAMLIT_STAGE/streamlit_stage/environment.yml');

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant usage to pipeline roles
SET role_admin = (SELECT $DATABASE_NAME || '_ADMIN');
SET role_readwrite = (SELECT $DATABASE_NAME || '_READWRITE');
SET role_readonly = (SELECT $DATABASE_NAME || '_READONLY');

GRANT USAGE ON STREAMLIT IDENTIFIER($STREAMLIT_APP_NAME) TO ROLE IDENTIFIER($role_admin);
GRANT USAGE ON STREAMLIT IDENTIFIER($STREAMLIT_APP_NAME) TO ROLE IDENTIFIER($role_readwrite);
GRANT USAGE ON STREAMLIT IDENTIFIER($STREAMLIT_APP_NAME) TO ROLE IDENTIFIER($role_readonly);

-- Grant read access to CONFIG_STAGE
GRANT READ ON STAGE CONFIG_STAGE TO ROLE IDENTIFIER($role_admin);
GRANT READ ON STAGE CONFIG_STAGE TO ROLE IDENTIFIER($role_readwrite);
GRANT READ ON STAGE CONFIG_STAGE TO ROLE IDENTIFIER($role_readonly);

-- Grant usage on PUBLIC schema
GRANT USAGE ON SCHEMA PUBLIC TO ROLE IDENTIFIER($role_admin);
GRANT USAGE ON SCHEMA PUBLIC TO ROLE IDENTIFIER($role_readwrite);
GRANT USAGE ON SCHEMA PUBLIC TO ROLE IDENTIFIER($role_readonly);

-- ============================================
-- UPLOAD APPLICATION AND CONFIG FILES
-- ============================================
-- Note: You need to upload files to the stages
-- 
-- Upload configuration files:
--   PUT file://default.config @db_ingest_pipeline.PUBLIC.CONFIG_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--   PUT file://custom.config @db_ingest_pipeline.PUBLIC.CONFIG_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- 
-- Upload Streamlit app:
--   PUT file://streamlit/streamlit_app.py @db_ingest_pipeline.PUBLIC.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--   PUT file://streamlit/environment.yml @db_ingest_pipeline.PUBLIC.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--
-- Using deployment script (recommended):
--   ./deploy.sh
--
-- Using Snowsight UI:
--   1. Navigate to Data > Databases > db_ingest_pipeline > PUBLIC > Stages
--   2. Upload to CONFIG_STAGE: default.config (and optionally custom.config)
--   3. Upload to STREAMLIT_STAGE: streamlit_app.py and environment.yml
-- ============================================

-- ============================================
-- VERIFICATION
-- ============================================

-- Show created Streamlit app
SHOW STREAMLITS IN SCHEMA;

-- Show files in stage
LIST @STREAMLIT_STAGE;

-- ============================================
-- ACCESS THE APP
-- ============================================
-- To access the Streamlit app:
--   1. Navigate to Snowsight
--   2. Click on "Streamlit" in the left sidebar
--   3. Find the app by name (e.g., "Bronze Ingestion Pipeline")
--   4. Click to open the app
--
-- Or use direct URL:
--   https://<your-account>.snowflakecomputing.com/streamlit/<database>/PUBLIC/<app_name>
--
-- The app will automatically read configuration from:
--   @<database>.PUBLIC.CONFIG_STAGE/custom.config (if exists)
--   or @<database>.PUBLIC.CONFIG_STAGE/default.config
-- ============================================

SELECT 'Streamlit app created successfully in PUBLIC schema!' as status,
       $DATABASE_NAME || '.PUBLIC.' || $STREAMLIT_APP_NAME as app_name,
       'Navigate to Snowsight > Streamlit to access the app' as next_steps,
       'Configuration loaded from @PUBLIC.CONFIG_STAGE' as config_source;


