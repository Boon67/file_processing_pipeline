-- ============================================================================
-- Snowpark Container Services (SPCS) Deployment
-- Snowflake Pipeline React Application
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE DB_INGEST_PIPELINE;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================================
-- Step 1: Create Image Repository
-- ============================================================================

CREATE IMAGE REPOSITORY IF NOT EXISTS DB_INGEST_PIPELINE.PUBLIC.PIPELINE_APP_REPO;

-- Show repository URL (use this for docker push)
SHOW IMAGE REPOSITORIES IN SCHEMA PUBLIC;

-- ============================================================================
-- Step 2: Create Compute Pool (if not exists)
-- ============================================================================

-- Check existing compute pools
SHOW COMPUTE POOLS;

-- Create compute pool for the application
CREATE COMPUTE POOL IF NOT EXISTS PIPELINE_APP_POOL
  MIN_NODES = 1
  MAX_NODES = 3
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 3600
  COMMENT = 'Compute pool for Pipeline React Application';

-- ============================================================================
-- Step 3: Create Service Specification
-- ============================================================================

-- The service will run the containerized React app
CREATE OR REPLACE SERVICE PIPELINE_APP_SERVICE
  IN COMPUTE POOL PIPELINE_APP_POOL
  FROM SPECIFICATION $$
    spec:
      containers:
      - name: app
        image: /db_ingest_pipeline/public/pipeline_app_repo/snowflake-pipeline-app:latest
        env:
          SNOWFLAKE_ACCOUNT: <ACCOUNT_LOCATOR>
          SNOWFLAKE_DATABASE: DB_INGEST_PIPELINE
          SNOWFLAKE_WAREHOUSE: COMPUTE_WH
          SNOWFLAKE_SCHEMA: BRONZE
          NODE_ENV: production
          PORT: 8080
        volumeMounts:
        - name: session-token
          mountPath: /snowflake/session
      endpoints:
      - name: app
        port: 8080
        public: true
      volumes:
      - name: session-token
        source: session
  MIN_INSTANCES = 1
  MAX_INSTANCES = 3
  AUTO_RESUME = TRUE
  COMMENT = 'Pipeline React Application Service';

-- ============================================================================
-- Step 4: Grant Permissions
-- ============================================================================

-- Grant usage on compute pool
GRANT USAGE ON COMPUTE POOL PIPELINE_APP_POOL TO ROLE ADMIN;
GRANT USAGE ON COMPUTE POOL PIPELINE_APP_POOL TO ROLE READWRITE;

-- Grant monitor on service
GRANT MONITOR ON SERVICE PIPELINE_APP_SERVICE TO ROLE ADMIN;
GRANT MONITOR ON SERVICE PIPELINE_APP_SERVICE TO ROLE READWRITE;

-- Grant database access to service
GRANT USAGE ON DATABASE DB_INGEST_PIPELINE TO SERVICE PIPELINE_APP_SERVICE;
GRANT USAGE ON SCHEMA BRONZE TO SERVICE PIPELINE_APP_SERVICE;
GRANT USAGE ON SCHEMA SILVER TO SERVICE PIPELINE_APP_SERVICE;

-- Grant table access
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA BRONZE TO SERVICE PIPELINE_APP_SERVICE;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA SILVER TO SERVICE PIPELINE_APP_SERVICE;

-- Grant stage access
GRANT READ, WRITE ON STAGE BRONZE.FILE_STAGE TO SERVICE PIPELINE_APP_SERVICE;
GRANT READ, WRITE ON STAGE BRONZE.ERROR_STAGE TO SERVICE PIPELINE_APP_SERVICE;
GRANT READ, WRITE ON STAGE BRONZE.ARCHIVE_STAGE TO SERVICE PIPELINE_APP_SERVICE;

-- Grant procedure execution
GRANT USAGE ON ALL PROCEDURES IN SCHEMA BRONZE TO SERVICE PIPELINE_APP_SERVICE;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA SILVER TO SERVICE PIPELINE_APP_SERVICE;

-- Grant task execution
GRANT EXECUTE TASK ON ACCOUNT TO SERVICE PIPELINE_APP_SERVICE;

-- ============================================================================
-- Step 5: Monitor Service
-- ============================================================================

-- Check service status
SHOW SERVICES IN DATABASE DB_INGEST_PIPELINE;

-- Get service details
DESC SERVICE PIPELINE_APP_SERVICE;

-- Get service logs
CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100);

-- Get service status
CALL SYSTEM$GET_SERVICE_STATUS('PIPELINE_APP_SERVICE');

-- Get endpoint URL
SHOW ENDPOINTS IN SERVICE PIPELINE_APP_SERVICE;

-- ============================================================================
-- Step 6: Service Management Commands
-- ============================================================================

-- Suspend service
-- ALTER SERVICE PIPELINE_APP_SERVICE SUSPEND;

-- Resume service
-- ALTER SERVICE PIPELINE_APP_SERVICE RESUME;

-- Drop service (cleanup)
-- DROP SERVICE IF EXISTS PIPELINE_APP_SERVICE;

-- Drop compute pool (cleanup)
-- DROP COMPUTE POOL IF EXISTS PIPELINE_APP_POOL;

-- ============================================================================
-- Deployment Instructions
-- ============================================================================

/*

1. Build and Push Docker Image:
   
   # Get repository URL from SHOW IMAGE REPOSITORIES
   export REPO_URL="<org>-<account>.registry.snowflakecomputing.com/db_ingest_pipeline/public/pipeline_app_repo"
   
   # Build image
   cd app
   docker build -t snowflake-pipeline-app:latest .
   
   # Tag image
   docker tag snowflake-pipeline-app:latest $REPO_URL/snowflake-pipeline-app:latest
   
   # Login to Snowflake registry
   docker login $REPO_URL -u <username>
   
   # Push image
   docker push $REPO_URL/snowflake-pipeline-app:latest

2. Update Service Specification:
   
   - Replace <ACCOUNT_LOCATOR> with your Snowflake account locator
   - Adjust MIN_INSTANCES and MAX_INSTANCES as needed
   - Update environment variables if needed

3. Deploy Service:
   
   - Run this SQL script
   - Monitor service status
   - Get endpoint URL

4. Access Application:
   
   - Use the endpoint URL from SHOW ENDPOINTS
   - The application will authenticate using the session token
   - No credentials needed in the UI

5. Monitor and Troubleshoot:
   
   - Check service status: CALL SYSTEM$GET_SERVICE_STATUS('PIPELINE_APP_SERVICE')
   - View logs: CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100)
   - Check endpoints: SHOW ENDPOINTS IN SERVICE PIPELINE_APP_SERVICE

*/

-- ============================================================================
-- Health Check
-- ============================================================================

-- Once service is running, test the health endpoint
-- Use the endpoint URL + /health

-- Example using SQL (if service is accessible):
-- SELECT SYSTEM$GET_SERVICE_HEALTH('PIPELINE_APP_SERVICE');
