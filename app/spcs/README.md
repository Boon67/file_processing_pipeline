# Snowpark Container Services (SPCS) Deployment

This directory contains deployment scripts and configuration for running the Pipeline React Application in Snowpark Container Services.

## Overview

SPCS allows you to run containerized applications directly within Snowflake, providing:
- **Seamless Integration**: Direct access to Snowflake resources
- **Security**: Session token authentication (no credentials needed)
- **Scalability**: Auto-scaling based on demand
- **Isolation**: Runs within Snowflake security boundary

## Prerequisites

- Snowflake account with SPCS enabled
- Docker installed locally
- Snowflake CLI or SQL client
- Appropriate Snowflake roles (SYSADMIN, ADMIN)

## Deployment Steps

### 1. Build Docker Image

```bash
cd /Users/tboon/code/file_processing_pipeline/app

# Build the image
docker build -t snowflake-pipeline-app:latest .
```

### 2. Get Snowflake Registry URL

```sql
USE ROLE SYSADMIN;
USE DATABASE DB_INGEST_PIPELINE;

-- Create image repository
CREATE IMAGE REPOSITORY IF NOT EXISTS DB_INGEST_PIPELINE.PUBLIC.PIPELINE_APP_REPO;

-- Get repository URL
SHOW IMAGE REPOSITORIES IN SCHEMA PUBLIC;
```

The URL will be in format: `<org>-<account>.registry.snowflakecomputing.com/db_ingest_pipeline/public/pipeline_app_repo`

### 3. Push Image to Snowflake Registry

```bash
# Set repository URL (replace with your actual URL)
export REPO_URL="myorg-myaccount.registry.snowflakecomputing.com/db_ingest_pipeline/public/pipeline_app_repo"

# Tag image
docker tag snowflake-pipeline-app:latest $REPO_URL/snowflake-pipeline-app:latest

# Login to Snowflake registry
docker login $REPO_URL -u <your_snowflake_username>
# Enter your Snowflake password when prompted

# Push image
docker push $REPO_URL/snowflake-pipeline-app:latest
```

### 4. Deploy Service

```sql
-- Run the deployment script
-- Edit deploy.sql first to replace <ACCOUNT_LOCATOR> with your account locator

USE ROLE SYSADMIN;
USE DATABASE DB_INGEST_PIPELINE;

-- Execute the deployment script
@spcs/deploy.sql
```

### 5. Monitor Deployment

```sql
-- Check service status
SHOW SERVICES IN DATABASE DB_INGEST_PIPELINE;

-- Get detailed status
CALL SYSTEM$GET_SERVICE_STATUS('PIPELINE_APP_SERVICE');

-- View logs
CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100);

-- Get endpoint URL
SHOW ENDPOINTS IN SERVICE PIPELINE_APP_SERVICE;
```

### 6. Access Application

Once the service is running:

1. Get the endpoint URL from `SHOW ENDPOINTS`
2. Open the URL in your browser
3. The application will automatically authenticate using the session token
4. No credentials needed!

## Service Configuration

### Compute Pool

```sql
CREATE COMPUTE POOL PIPELINE_APP_POOL
  MIN_NODES = 1
  MAX_NODES = 3
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 3600;
```

**Configuration Options:**
- `MIN_NODES`: Minimum number of nodes (1 for development, 2+ for production)
- `MAX_NODES`: Maximum nodes for auto-scaling
- `INSTANCE_FAMILY`: Instance type (CPU_X64_XS, CPU_X64_S, CPU_X64_M, etc.)
- `AUTO_SUSPEND_SECS`: Idle time before suspension (3600 = 1 hour)

### Service Specification

```yaml
spec:
  containers:
  - name: app
    image: /db_ingest_pipeline/public/pipeline_app_repo/snowflake-pipeline-app:latest
    env:
      SNOWFLAKE_ACCOUNT: <ACCOUNT_LOCATOR>
      SNOWFLAKE_DATABASE: DB_INGEST_PIPELINE
      SNOWFLAKE_WAREHOUSE: COMPUTE_WH
      NODE_ENV: production
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
```

**Key Elements:**
- **image**: Path to container image in Snowflake registry
- **env**: Environment variables for the application
- **volumeMounts**: Mounts session token at `/snowflake/session/token`
- **endpoints**: Exposes port 8080 publicly
- **volumes**: Session token volume for authentication

## Authentication

### SPCS Session Token

The application automatically uses the session token mounted at `/snowflake/session/token`:

```javascript
// In server/utils/snowflake.js
const token = fs.readFileSync('/snowflake/session/token', 'utf8').trim();

const config = {
  account: process.env.SNOWFLAKE_ACCOUNT,
  authenticator: 'OAUTH',
  token: token,
  // ... other config
};
```

**Benefits:**
- ✅ No credentials in environment variables
- ✅ Automatic token rotation by Snowflake
- ✅ Runs within Snowflake security boundary
- ✅ Simplified authentication

## Permissions

The service needs the following permissions:

```sql
-- Database and schema access
GRANT USAGE ON DATABASE DB_INGEST_PIPELINE TO SERVICE PIPELINE_APP_SERVICE;
GRANT USAGE ON SCHEMA BRONZE TO SERVICE PIPELINE_APP_SERVICE;
GRANT USAGE ON SCHEMA SILVER TO SERVICE PIPELINE_APP_SERVICE;

-- Table access
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA BRONZE TO SERVICE PIPELINE_APP_SERVICE;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA SILVER TO SERVICE PIPELINE_APP_SERVICE;

-- Stage access
GRANT READ, WRITE ON STAGE BRONZE.FILE_STAGE TO SERVICE PIPELINE_APP_SERVICE;

-- Procedure and task execution
GRANT USAGE ON ALL PROCEDURES IN SCHEMA BRONZE TO SERVICE PIPELINE_APP_SERVICE;
GRANT EXECUTE TASK ON ACCOUNT TO SERVICE PIPELINE_APP_SERVICE;
```

## Monitoring

### Service Status

```sql
-- Overall status
SHOW SERVICES IN DATABASE DB_INGEST_PIPELINE;

-- Detailed status
CALL SYSTEM$GET_SERVICE_STATUS('PIPELINE_APP_SERVICE');

-- Health check
SELECT SYSTEM$GET_SERVICE_HEALTH('PIPELINE_APP_SERVICE');
```

### Logs

```sql
-- Get last 100 log lines
CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100);

-- Get logs from specific container instance
CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 1000);
```

### Endpoints

```sql
-- Show endpoint URLs
SHOW ENDPOINTS IN SERVICE PIPELINE_APP_SERVICE;

-- Test health endpoint
-- Visit: <endpoint_url>/health
```

## Management

### Suspend Service

```sql
ALTER SERVICE PIPELINE_APP_SERVICE SUSPEND;
```

### Resume Service

```sql
ALTER SERVICE PIPELINE_APP_SERVICE RESUME;
```

### Update Service

```sql
-- After pushing new image version
ALTER SERVICE PIPELINE_APP_SERVICE FROM SPECIFICATION $$
  -- Updated specification
$$;
```

### Scale Service

```sql
-- Adjust instance count
ALTER SERVICE PIPELINE_APP_SERVICE 
  SET MIN_INSTANCES = 2
  MAX_INSTANCES = 5;
```

## Troubleshooting

### Service Won't Start

**Check:**
1. Image exists in registry: `SHOW IMAGES IN IMAGE REPOSITORY PIPELINE_APP_REPO;`
2. Compute pool is active: `SHOW COMPUTE POOLS;`
3. Service logs: `CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100);`

**Common Issues:**
- Image not found: Push image again
- Insufficient permissions: Check grants
- Invalid specification: Review YAML syntax

### Cannot Access Endpoint

**Check:**
1. Service is running: `SHOW SERVICES;`
2. Endpoint is public: `SHOW ENDPOINTS IN SERVICE PIPELINE_APP_SERVICE;`
3. Network connectivity

### Authentication Errors

**Check:**
1. Session token volume is mounted
2. Environment variables are correct
3. Service has database permissions

**Debug:**
```sql
-- Check service logs for auth errors
CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100);
```

### Performance Issues

**Solutions:**
1. Increase compute pool size:
   ```sql
   ALTER COMPUTE POOL PIPELINE_APP_POOL SET INSTANCE_FAMILY = CPU_X64_M;
   ```

2. Add more instances:
   ```sql
   ALTER SERVICE PIPELINE_APP_SERVICE SET MAX_INSTANCES = 5;
   ```

3. Check warehouse size:
   ```sql
   ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = MEDIUM;
   ```

## Cost Optimization

### Auto-Suspend

```sql
-- Suspend compute pool after 30 minutes of inactivity
ALTER COMPUTE POOL PIPELINE_APP_POOL SET AUTO_SUSPEND_SECS = 1800;
```

### Right-Sizing

- **Development**: CPU_X64_XS, MIN_NODES=1
- **Testing**: CPU_X64_S, MIN_NODES=1, MAX_NODES=2
- **Production**: CPU_X64_M, MIN_NODES=2, MAX_NODES=5

### Monitoring Costs

```sql
-- Check compute pool usage
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.COMPUTE_POOL_HISTORY
WHERE COMPUTE_POOL_NAME = 'PIPELINE_APP_POOL'
ORDER BY START_TIME DESC
LIMIT 100;

-- Check service costs
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.SERVICE_HISTORY
WHERE SERVICE_NAME = 'PIPELINE_APP_SERVICE'
ORDER BY START_TIME DESC
LIMIT 100;
```

## Cleanup

### Remove Service

```sql
-- Suspend first
ALTER SERVICE PIPELINE_APP_SERVICE SUSPEND;

-- Drop service
DROP SERVICE IF EXISTS PIPELINE_APP_SERVICE;

-- Drop compute pool
DROP COMPUTE POOL IF EXISTS PIPELINE_APP_POOL;

-- Drop image repository (optional)
DROP IMAGE REPOSITORY IF EXISTS PIPELINE_APP_REPO;
```

## Best Practices

### Security
- ✅ Use session token authentication
- ✅ Grant minimal required permissions
- ✅ Use private endpoints for sensitive data
- ✅ Enable audit logging

### Reliability
- ✅ Set MIN_INSTANCES >= 2 for production
- ✅ Configure health checks
- ✅ Monitor service logs
- ✅ Set up alerts

### Performance
- ✅ Right-size compute pool
- ✅ Enable auto-scaling
- ✅ Use appropriate warehouse size
- ✅ Monitor query performance

### Cost
- ✅ Enable auto-suspend
- ✅ Use smallest instance family that meets needs
- ✅ Monitor usage regularly
- ✅ Suspend non-production services when not in use

## Additional Resources

- [Snowpark Container Services Documentation](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview)
- [SPCS Tutorials](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/tutorials)
- [Container Registry](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-registry)

## Support

For issues:
1. Check service logs
2. Review troubleshooting section
3. Consult Snowflake documentation
4. Contact Snowflake support

---

**Version**: 1.0.0  
**Last Updated**: January 14, 2026
