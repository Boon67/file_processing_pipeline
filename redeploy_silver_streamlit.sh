#!/bin/bash

# ============================================
# Quick Redeploy Silver Streamlit App
# ============================================
# Purpose: Redeploy only the Silver Streamlit app without rerunning full deployment
#
# Usage:
#   ./redeploy_silver_streamlit.sh
# ============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
CONFIG_FILE="${1:-default.config}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: Configuration file not found: ${CONFIG_FILE}${NC}"
    exit 1
fi

echo -e "${BLUE}Loading configuration from: ${CONFIG_FILE}${NC}"
source "$CONFIG_FILE"

# Set defaults
DATABASE_NAME="${DATABASE_NAME:-db_ingest_pipeline}"
WAREHOUSE_NAME="${WAREHOUSE_NAME:-COMPUTE_WH}"
SILVER_STREAMLIT_APP_NAME="${SILVER_STREAMLIT_APP_NAME:-SILVER_DATA_MANAGER}"
SILVER_STREAMLIT_STAGE_NAME="${SILVER_STREAMLIT_STAGE_NAME:-SILVER_STREAMLIT}"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Redeploying Silver Streamlit App${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "  Database:      ${DATABASE_NAME}"
echo "  Warehouse:     ${WAREHOUSE_NAME}"
echo "  App Name:      ${SILVER_STREAMLIT_APP_NAME}"
echo "  Stage:         ${SILVER_STREAMLIT_STAGE_NAME}"
echo ""

# Check if snow CLI is installed
if ! command -v snow &> /dev/null; then
    echo -e "${RED}ERROR: Snowflake CLI (snow) is not installed${NC}"
    exit 1
fi

# Get connection
CONNECTIONS_JSON=$(snow connection list --format json 2>/dev/null)
CONNECTION_COUNT=$(echo "$CONNECTIONS_JSON" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data))" 2>/dev/null || echo "0")

if [ "$CONNECTION_COUNT" = "1" ]; then
    SNOW_CONNECTION=$(echo "$CONNECTIONS_JSON" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data[0].get('connection_name', data[0].get('name', '')))" 2>/dev/null)
    USE_DEFAULT_CONNECTION=false
else
    echo -e "${YELLOW}Multiple connections found. Using default connection.${NC}"
    USE_DEFAULT_CONNECTION=true
fi

# Streamlit directory
STREAMLIT_DIR="silver/silver_streamlit"

if [ ! -f "${STREAMLIT_DIR}/streamlit_app.py" ]; then
    echo -e "${RED}ERROR: ${STREAMLIT_DIR}/streamlit_app.py not found${NC}"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo -e "${BLUE}Using temp directory: ${TEMP_DIR}${NC}"

# Generate snowflake.yml
STREAMLIT_TITLE=$(echo "${SILVER_STREAMLIT_APP_NAME}" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')

STREAMLIT_YML="${TEMP_DIR}/snowflake.yml"
cat > "$STREAMLIT_YML" << EOF
definition_version: 2

entities:
  streamlit_app:
    type: streamlit
    identifier:
      name: ${SILVER_STREAMLIT_APP_NAME}
    title: ${STREAMLIT_TITLE}
    query_warehouse: ${WAREHOUSE_NAME}
    main_file: streamlit_app.py
    stage: PUBLIC.${SILVER_STREAMLIT_STAGE_NAME}
    artifacts:
      - streamlit_app.py
      - environment.yml
EOF

# Copy to streamlit directory
cp "$STREAMLIT_YML" "${STREAMLIT_DIR}/snowflake.yml"

echo -e "${GREEN}Deploying Streamlit app...${NC}"

# Change to streamlit directory
cd "$STREAMLIT_DIR"

# Deploy
if [ "$USE_DEFAULT_CONNECTION" = true ]; then
    DEPLOY_CMD="snow streamlit deploy --replace --database \"${DATABASE_NAME}\" --schema PUBLIC"
else
    DEPLOY_CMD="snow streamlit deploy --replace --database \"${DATABASE_NAME}\" --schema PUBLIC --connection \"$SNOW_CONNECTION\""
fi

if eval "$DEPLOY_CMD"; then
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  ✅ Streamlit App Redeployed Successfully!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${BLUE}Access your app:${NC}"
    echo "  1. Navigate to Snowsight"
    echo "  2. Click 'Streamlit' in the left sidebar"
    echo "  3. Open '${SILVER_STREAMLIT_APP_NAME}'"
    echo ""
    echo -e "${YELLOW}Note: It may take a few seconds for changes to appear${NC}"
else
    echo -e "${RED}ERROR: Deployment failed${NC}"
    exit 1
fi

# Return to project root
cd ../..

# Cleanup
rm -rf "$TEMP_DIR"

echo -e "${GREEN}Done!${NC}"

