# Deployment Guide

Complete guide for deploying the Snowflake Pipeline React Application in both standalone and SPCS modes.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Standalone Deployment](#standalone-deployment)
3. [SPCS Deployment](#spcs-deployment)
4. [Configuration](#configuration)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

- **Docker**: Version 20.10+
- **Node.js**: Version 20+ (for local development)
- **Snowflake Account**: With appropriate permissions
- **Git**: For cloning the repository

### Snowflake Requirements

- Database: `DB_INGEST_PIPELINE` (created by Bronze/Silver deployment)
- Warehouse: `COMPUTE_WH` or equivalent
- Roles: Access to SYSADMIN, ADMIN roles
- For SPCS: SPCS feature enabled on account

### Network Requirements

- **Standalone**: Outbound HTTPS (443) to Snowflake
- **SPCS**: No external network requirements

## Standalone Deployment

### Option 1: Docker Compose (Recommended for Local)

```bash
# 1. Navigate to app directory
cd /Users/tboon/code/file_processing_pipeline/app

# 2. Create environment file
cat > .env << EOF
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_DATABASE=DB_INGEST_PIPELINE
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_SCHEMA=BRONZE
EOF

# 3. Build and start
docker-compose up -d

# 4. Check logs
docker-compose logs -f

# 5. Access application
open http://localhost:8080
```

### Option 2: Docker Run

```bash
# 1. Build image
docker build -t snowflake-pipeline-app:latest .

# 2. Run container
docker run -d \
  --name pipeline-app \
  -p 8080:8080 \
  -e SNOWFLAKE_ACCOUNT=your_account \
  -e SNOWFLAKE_USER=your_user \
  -e SNOWFLAKE_PASSWORD=your_password \
  -e SNOWFLAKE_DATABASE=DB_INGEST_PIPELINE \
  -e SNOWFLAKE_WAREHOUSE=COMPUTE_WH \
  snowflake-pipeline-app:latest

# 3. Check logs
docker logs -f pipeline-app

# 4. Access application
open http://localhost:8080
```

### Option 3: Cloud Deployment (AWS ECS Example)

```bash
# 1. Build and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

docker tag snowflake-pipeline-app:latest <account>.dkr.ecr.us-east-1.amazonaws.com/pipeline-app:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/pipeline-app:latest

# 2. Create ECS task definition (see ecs-task-definition.json)

# 3. Create ECS service

# 4. Configure load balancer and DNS
```

## SPCS Deployment

### Step 1: Prepare Image

```bash
# Navigate to app directory
cd /Users/tboon/code/file_processing_pipeline/app

# Build image
docker build -t snowflake-pipeline-app:latest .
```

### Step 2: Get Registry URL

```sql
USE ROLE SYSADMIN;
USE DATABASE DB_INGEST_PIPELINE;

-- Create image repository
CREATE IMAGE REPOSITORY IF NOT EXISTS DB_INGEST_PIPELINE.PUBLIC.PIPELINE_APP_REPO;

-- Get repository URL
SHOW IMAGE REPOSITORIES IN SCHEMA PUBLIC;
```

Copy the `repository_url` from the output.

### Step 3: Push to Snowflake Registry

```bash
# Set variables
export REPO_URL="<org>-<account>.registry.snowflakecomputing.com/db_ingest_pipeline/public/pipeline_app_repo"
export SF_USER="your_username"

# Tag image
docker tag snowflake-pipeline-app:latest $REPO_URL/snowflake-pipeline-app:latest

# Login to Snowflake registry
docker login $REPO_URL -u $SF_USER

# Push image
docker push $REPO_URL/snowflake-pipeline-app:latest

# Verify
docker images | grep snowflake-pipeline-app
```

### Step 4: Deploy Service

```sql
-- 1. Edit spcs/deploy.sql
-- Replace <ACCOUNT_LOCATOR> with your account locator
-- Example: xy12345 (from xy12345.snowflakecomputing.com)

-- 2. Run deployment script
USE ROLE SYSADMIN;
USE DATABASE DB_INGEST_PIPELINE;
USE WAREHOUSE COMPUTE_WH;

-- Execute the script
-- (Copy and paste contents of spcs/deploy.sql)
```

### Step 5: Monitor Deployment

```sql
-- Check service status
SHOW SERVICES IN DATABASE DB_INGEST_PIPELINE;

-- Wait for status to be 'READY'
-- This may take 5-10 minutes

-- Get detailed status
CALL SYSTEM$GET_SERVICE_STATUS('PIPELINE_APP_SERVICE');

-- View logs
CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100);
```

### Step 6: Get Endpoint URL

```sql
-- Show endpoints
SHOW ENDPOINTS IN SERVICE PIPELINE_APP_SERVICE;

-- Copy the ingress_url
-- Example: https://pipeline-app-service-xy12345.snowflakecomputing.app
```

### Step 7: Access Application

Open the endpoint URL in your browser. The application will automatically authenticate using the SPCS session token.

## Configuration

### Environment Variables

#### Required for Standalone

| Variable | Description | Example |
|----------|-------------|---------|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier | `xy12345` |
| `SNOWFLAKE_USER` | Snowflake username | `admin_user` |
| `SNOWFLAKE_PASSWORD` | Snowflake password | `SecurePass123!` |
| `SNOWFLAKE_DATABASE` | Database name | `DB_INGEST_PIPELINE` |
| `SNOWFLAKE_WAREHOUSE` | Warehouse name | `COMPUTE_WH` |

#### Required for SPCS

| Variable | Description | Example |
|----------|-------------|---------|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier | `xy12345` |
| `SNOWFLAKE_DATABASE` | Database name | `DB_INGEST_PIPELINE` |
| `SNOWFLAKE_WAREHOUSE` | Warehouse name | `COMPUTE_WH` |

#### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `8080` |
| `NODE_ENV` | Environment | `production` |
| `LOG_LEVEL` | Logging level | `info` |
| `API_RATE_LIMIT` | Rate limit per window | `100` |
| `API_RATE_WINDOW` | Rate limit window (minutes) | `15` |

### Docker Build Arguments

```bash
# Custom Node version
docker build --build-arg NODE_VERSION=20-alpine -t pipeline-app .

# Development build
docker build --target backend-build -t pipeline-app:dev .
```

## Verification

### Health Check

```bash
# Standalone
curl http://localhost:8080/health

# SPCS
curl https://<endpoint-url>/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2026-01-14T12:00:00.000Z",
  "mode": "SPCS",
  "snowflake": {
    "connected": true,
    "version": "8.0.0"
  },
  "uptime": 123.456
}
```

### API Endpoints

```bash
# Get configuration
curl http://localhost:8080/api/config

# List TPAs
curl http://localhost:8080/api/tpas

# Get system stats
curl http://localhost:8080/api/stats

# Bronze files
curl http://localhost:8080/api/bronze/files

# Silver mappings
curl http://localhost:8080/api/silver/mappings
```

### UI Verification

1. **Home Page**: Should load without errors
2. **Bronze Upload**: Can select TPA and upload files
3. **Processing Status**: Shows files and their status
4. **Raw Data Viewer**: Displays raw data with filters
5. **Silver Mappings**: Shows field mappings
6. **Silver Rules**: Shows transformation rules

## Troubleshooting

### Container Won't Start

**Symptoms**: Container exits immediately

**Check:**
```bash
# View logs
docker logs pipeline-app

# Common issues:
# - Missing environment variables
# - Invalid Snowflake credentials
# - Network connectivity
```

**Solutions:**
```bash
# Verify environment variables
docker exec pipeline-app env | grep SNOWFLAKE

# Test Snowflake connectivity
docker exec pipeline-app node -e "
  const snowflake = require('snowflake-sdk');
  const conn = snowflake.createConnection({
    account: process.env.SNOWFLAKE_ACCOUNT,
    username: process.env.SNOWFLAKE_USER,
    password: process.env.SNOWFLAKE_PASSWORD
  });
  conn.connect((err) => {
    if (err) console.error('Error:', err);
    else console.log('Connected!');
  });
"
```

### SPCS Service Won't Start

**Symptoms**: Service stuck in "PENDING" or "FAILED" state

**Check:**
```sql
-- Service status
CALL SYSTEM$GET_SERVICE_STATUS('PIPELINE_APP_SERVICE');

-- Service logs
CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100);

-- Compute pool status
SHOW COMPUTE POOLS;
```

**Common Issues:**

1. **Image not found**
   ```sql
   -- Verify image exists
   SHOW IMAGES IN IMAGE REPOSITORY PIPELINE_APP_REPO;
   
   -- Re-push if needed
   ```

2. **Insufficient permissions**
   ```sql
   -- Re-grant permissions
   GRANT USAGE ON DATABASE DB_INGEST_PIPELINE TO SERVICE PIPELINE_APP_SERVICE;
   ```

3. **Compute pool not ready**
   ```sql
   -- Check pool status
   SHOW COMPUTE POOLS;
   
   -- Resume if suspended
   ALTER COMPUTE POOL PIPELINE_APP_POOL RESUME;
   ```

### Cannot Connect to Snowflake

**Symptoms**: Health check fails, "Unable to connect" errors

**Check:**
```bash
# Verify credentials
echo $SNOWFLAKE_ACCOUNT
echo $SNOWFLAKE_USER

# Test network connectivity
ping <account>.snowflakecomputing.com

# Check Snowflake status
# Visit: https://status.snowflake.com/
```

**Solutions:**
- Verify account identifier (not full URL)
- Check username/password
- Verify network allows HTTPS (443)
- Check Snowflake IP whitelist

### File Upload Fails

**Symptoms**: Upload returns error, files not appearing in stage

**Check:**
```sql
-- Verify stage exists
SHOW STAGES IN SCHEMA BRONZE;

-- Check stage permissions
SHOW GRANTS ON STAGE BRONZE.FILE_STAGE;

-- List stage contents
LIST @BRONZE.FILE_STAGE;
```

**Solutions:**
```sql
-- Grant stage permissions
GRANT READ, WRITE ON STAGE BRONZE.FILE_STAGE TO ROLE ADMIN;

-- Verify file size limits (default 100MB)
-- Increase if needed in server/routes/bronze.js
```

### UI Not Loading

**Symptoms**: Blank page, 404 errors

**Check:**
```bash
# Verify frontend build
docker exec pipeline-app ls -la /app/public

# Check nginx/express logs
docker logs pipeline-app
```

**Solutions:**
```bash
# Rebuild with fresh frontend build
docker build --no-cache -t snowflake-pipeline-app:latest .

# Verify build output
docker run --rm snowflake-pipeline-app:latest ls -la /app/public
```

## Performance Tuning

### Standalone

```bash
# Increase container resources
docker run -d \
  --cpus="2" \
  --memory="4g" \
  -p 8080:8080 \
  snowflake-pipeline-app:latest
```

### SPCS

```sql
-- Increase compute pool size
ALTER COMPUTE POOL PIPELINE_APP_POOL 
  SET INSTANCE_FAMILY = CPU_X64_M;

-- Add more instances
ALTER SERVICE PIPELINE_APP_SERVICE 
  SET MAX_INSTANCES = 5;

-- Increase warehouse size
ALTER WAREHOUSE COMPUTE_WH 
  SET WAREHOUSE_SIZE = MEDIUM;
```

## Monitoring

### Standalone

```bash
# Container stats
docker stats pipeline-app

# Logs
docker logs -f pipeline-app

# Health check
watch -n 5 'curl -s http://localhost:8080/health | jq'
```

### SPCS

```sql
-- Service status
CALL SYSTEM$GET_SERVICE_STATUS('PIPELINE_APP_SERVICE');

-- Logs (last 100 lines)
CALL SYSTEM$GET_SERVICE_LOGS('PIPELINE_APP_SERVICE', 0, 'app', 100);

-- Compute pool usage
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.COMPUTE_POOL_HISTORY
WHERE COMPUTE_POOL_NAME = 'PIPELINE_APP_POOL'
ORDER BY START_TIME DESC
LIMIT 10;
```

## Maintenance

### Updates

**Standalone:**
```bash
# Pull latest code
git pull

# Rebuild
docker build -t snowflake-pipeline-app:latest .

# Restart
docker-compose down
docker-compose up -d
```

**SPCS:**
```bash
# Rebuild and push
docker build -t snowflake-pipeline-app:latest .
docker tag snowflake-pipeline-app:latest $REPO_URL/snowflake-pipeline-app:latest
docker push $REPO_URL/snowflake-pipeline-app:latest

# Update service
# Service will automatically pull new image on next restart
```

### Backup

```sql
-- Backup configuration
CREATE TABLE bronze.tpa_master_backup AS SELECT * FROM bronze.tpa_master;
CREATE TABLE silver.field_mappings_backup AS SELECT * FROM silver.field_mappings;
CREATE TABLE silver.transformation_rules_backup AS SELECT * FROM silver.transformation_rules;
```

### Cleanup

**Standalone:**
```bash
docker-compose down -v
docker rmi snowflake-pipeline-app:latest
```

**SPCS:**
```sql
ALTER SERVICE PIPELINE_APP_SERVICE SUSPEND;
DROP SERVICE PIPELINE_APP_SERVICE;
DROP COMPUTE POOL PIPELINE_APP_POOL;
```

## Support

For issues:
1. Check logs (Docker or SPCS)
2. Review troubleshooting section
3. Verify configuration
4. Check Snowflake status
5. Contact support

---

**Version**: 1.0.0  
**Last Updated**: January 14, 2026
