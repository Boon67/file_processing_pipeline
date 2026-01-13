#!/bin/bash

# ============================================
# BRONZE LAYER DEPLOYMENT
# ============================================
# This script deploys the Bronze layer (file ingestion pipeline) to Snowflake
# It runs all Bronze SQL scripts in the correct order with optional
# database and schema name customization
#
# Prerequisites:
#   - Snowflake CLI (snow) installed and configured
#   - Connection must have SYSADMIN and SECURITYADMIN permissions
#   - Python installed (python or python3)
#
# Usage:
#   ./deploy_bronze.sh                    # Uses default.config
#   ./deploy_bronze.sh custom.config      # Uses custom config file
#   ./deploy.sh                           # Deploy complete solution (Bronze + Silver)
#
# Supported Platforms:
#   - macOS
#   - Linux
#   - Windows (Git Bash, WSL, or Cygwin)
# ============================================

set -e  # Exit on error

# Detect OS for platform-specific commands
OS_TYPE="$(uname -s 2>/dev/null || echo 'Unknown')"
case "${OS_TYPE}" in
    Linux*)     OS="Linux";;
    Darwin*)    OS="macOS";;
    CYGWIN*|MINGW*|MSYS*|MINGW32*|MINGW64*)  OS="Windows";;
    *)          OS="Unknown";;
esac

# Detect Python command (prefer python, fall back to python3)
if command -v python &> /dev/null; then
    PYTHON_CMD="python"
elif command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
else
    echo "ERROR: Python is not installed or not in PATH"
    echo "Please install Python from: https://www.python.org/downloads/"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default config file
CONFIG_FILE="${1:-default.config}"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: Configuration file not found: ${CONFIG_FILE}${NC}"
    echo "Please ensure the configuration file exists or run without arguments to use default.config"
    exit 1
fi

# Load configuration from file
echo -e "${BLUE}Loading configuration from: ${CONFIG_FILE}${NC}"
source "$CONFIG_FILE"

# Set deployment behavior flags (with defaults if not set in config)
ACCEPT_DEFAULTS="${ACCEPT_DEFAULTS:-false}"
USE_DEFAULT_CLI_CONNECTION="${USE_DEFAULT_CLI_CONNECTION:-false}"

# Set defaults from config file
DEFAULT_DATABASE="${DATABASE_NAME}"
DEFAULT_SCHEMA="${SCHEMA_NAME}"
DEFAULT_WAREHOUSE="${WAREHOUSE_NAME}"
DEFAULT_SRC_STAGE="${SRC_STAGE_NAME}"
DEFAULT_COMPLETED_STAGE="${COMPLETED_STAGE_NAME}"
DEFAULT_ERROR_STAGE="${ERROR_STAGE_NAME}"
DEFAULT_ARCHIVE_STAGE="${ARCHIVE_STAGE_NAME}"
DEFAULT_DISCOVER_TASK="${DISCOVER_TASK_NAME}"
DEFAULT_PROCESS_TASK="${PROCESS_TASK_NAME}"
DEFAULT_MOVE_SUCCESS_TASK="${MOVE_SUCCESS_TASK_NAME}"
DEFAULT_MOVE_FAILED_TASK="${MOVE_FAILED_TASK_NAME}"
DEFAULT_STREAMLIT_APP="${STREAMLIT_APP_NAME:-Bronze_Ingestion_Pipeline}"
DEFAULT_DISCOVER_SCHEDULE="${DISCOVER_TASK_SCHEDULE_MINUTES:-60}"

# Print banner
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Snowflake Bronze Layer Deployment${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if snow CLI is installed
if ! command -v snow &> /dev/null; then
    echo -e "${RED}ERROR: Snowflake CLI (snow) is not installed or not in PATH${NC}"
    echo "Please install Snowflake CLI from: https://docs.snowflake.com/en/developer-guide/snowflake-cli/index"
    echo ""
    echo "Installation: pip install snowflake-cli-labs"
    exit 1
fi

# Get list of available connections
echo -e "${BLUE}Checking Snowflake CLI connection...${NC}"
CONNECTIONS_JSON=$(snow connection list --format json 2>/dev/null)
CONNECTION_COUNT=$(echo "$CONNECTIONS_JSON" | $PYTHON_CMD -c "import sys, json; data = json.load(sys.stdin); print(len(data))" 2>/dev/null || echo "0")

if [ "$CONNECTION_COUNT" = "0" ]; then
    echo -e "${RED}ERROR: No Snowflake connections configured${NC}"
    echo "Please configure a connection with: snow connection add"
    exit 1
elif [ "$CONNECTION_COUNT" = "1" ]; then
    # Only one connection, use it
    SNOW_CONNECTION=$(echo "$CONNECTIONS_JSON" | $PYTHON_CMD -c "import sys, json; data = json.load(sys.stdin); print(data[0].get('connection_name', data[0].get('name', '')))" 2>/dev/null)
    USE_DEFAULT_CONNECTION=false
else
    # Multiple connections exist
    # Get default connection
    DEFAULT_CONN=$(echo "$CONNECTIONS_JSON" | $PYTHON_CMD -c "import sys, json; data = json.load(sys.stdin); print(next((c.get('connection_name', c.get('name', '')) for c in data if c.get('is_default', False)), ''))" 2>/dev/null)
    
    # Check if we should use default automatically
    if [ "$USE_DEFAULT_CLI_CONNECTION" = "true" ] && [ -n "$DEFAULT_CONN" ]; then
        # Use the default connection without prompting
        SNOW_CONNECTION="$DEFAULT_CONN"
        USE_DEFAULT_CONNECTION=false
        echo -e "${GREEN}Using default connection: ${SNOW_CONNECTION}${NC}"
    else
        # Multiple connections, let user choose
        echo -e "${YELLOW}Multiple Snowflake connections found:${NC}"
        echo ""
        
        # Display connections
        CONN_NAMES=()
        INDEX=1
        while IFS= read -r line; do
            CONN_NAME=$(echo "$line" | $PYTHON_CMD -c "import sys, json; c = json.loads(sys.stdin.read()); print(c.get('connection_name', c.get('name', '')))" 2>/dev/null)
            CONN_NAMES+=("$CONN_NAME")
            
            if [ "$CONN_NAME" = "$DEFAULT_CONN" ]; then
                echo -e "  ${INDEX}. ${GREEN}${CONN_NAME} (default)${NC}"
            else
                echo "  ${INDEX}. ${CONN_NAME}"
            fi
            INDEX=$((INDEX + 1))
        done < <(echo "$CONNECTIONS_JSON" | $PYTHON_CMD -c "import sys, json; [print(json.dumps(c)) for c in json.load(sys.stdin)]" 2>/dev/null)
        
        echo ""
        if [ -n "$DEFAULT_CONN" ]; then
            read -p "Select connection [1-${CONNECTION_COUNT}] (Enter for default): " CONN_CHOICE
            if [ -z "$CONN_CHOICE" ]; then
                SNOW_CONNECTION="$DEFAULT_CONN"
            else
                SNOW_CONNECTION="${CONN_NAMES[$((CONN_CHOICE-1))]}"
            fi
        else
            read -p "Select connection [1-${CONNECTION_COUNT}]: " CONN_CHOICE
            SNOW_CONNECTION="${CONN_NAMES[$((CONN_CHOICE-1))]}"
        fi
        
        if [ -z "$SNOW_CONNECTION" ]; then
            echo -e "${RED}Invalid selection${NC}"
            exit 1
        fi
        
        USE_DEFAULT_CONNECTION=false
    fi
fi

# Helper function to run snow sql with or without connection parameter
run_snow_sql() {
    if [ "$USE_DEFAULT_CONNECTION" = true ]; then
        snow sql "$@"
    else
        snow sql --connection "$SNOW_CONNECTION" "$@"
    fi
}

if [ "$USE_DEFAULT_CONNECTION" = true ]; then
    echo -e "${GREEN}✓ Connected to Snowflake (using default connection)${NC}"
else
    echo -e "${GREEN}✓ Connected to Snowflake (connection: ${SNOW_CONNECTION})${NC}"
fi
echo -e "${GREEN}✓ Configuration loaded from: ${CONFIG_FILE}${NC}"
echo ""

# Check for required roles
echo -e "${BLUE}Checking required permissions...${NC}"

# Temporarily disable exit on error for role checks
set +e

# Try to use SYSADMIN role - if this fails, user doesn't have access
TEMP_CHECK=$(mktemp)

# Test SYSADMIN access
cat > "$TEMP_CHECK" << 'EOF'
USE ROLE SYSADMIN;
SELECT 'SYSADMIN_OK' as result;
EOF

SYSADMIN_RESULT=$(run_snow_sql -f "$TEMP_CHECK" 2>&1)
SYSADMIN_EXIT=$?

if [ $SYSADMIN_EXIT -eq 0 ] && echo "$SYSADMIN_RESULT" | grep -q "SYSADMIN_OK"; then
    HAS_SYSADMIN=1
else
    HAS_SYSADMIN=0
fi

# Test SECURITYADMIN access
cat > "$TEMP_CHECK" << 'EOF'
USE ROLE SECURITYADMIN;
SELECT 'SECURITYADMIN_OK' as result;
EOF

SECURITYADMIN_RESULT=$(run_snow_sql -f "$TEMP_CHECK" 2>&1)
SECURITYADMIN_EXIT=$?

if [ $SECURITYADMIN_EXIT -eq 0 ] && echo "$SECURITYADMIN_RESULT" | grep -q "SECURITYADMIN_OK"; then
    HAS_SECURITYADMIN=1
else
    HAS_SECURITYADMIN=0
fi

rm -f "$TEMP_CHECK"

# Re-enable exit on error
set -e

# Display role check results
echo ""
echo -e "${BLUE}Role Access Status:${NC}"

# Check SYSADMIN
if [ "$HAS_SYSADMIN" = "1" ]; then
    echo -e "${GREEN}  ✓ SYSADMIN role: Available${NC}"
else
    echo -e "${RED}  ✗ SYSADMIN role: NOT Available${NC}"
fi

# Check SECURITYADMIN
if [ "$HAS_SECURITYADMIN" = "1" ]; then
    echo -e "${GREEN}  ✓ SECURITYADMIN role: Available${NC}"
else
    echo -e "${RED}  ✗ SECURITYADMIN role: NOT Available${NC}"
fi

echo ""

# Check if user has both required roles
MISSING_ROLES=()
if [ "$HAS_SYSADMIN" = "0" ]; then
    MISSING_ROLES+=("SYSADMIN")
fi
if [ "$HAS_SECURITYADMIN" = "0" ]; then
    MISSING_ROLES+=("SECURITYADMIN")
fi

if [ ${#MISSING_ROLES[@]} -gt 0 ]; then
    echo -e "${RED}✗ ERROR: Missing required roles${NC}"
    echo ""
    echo -e "${YELLOW}This deployment requires both SYSADMIN and SECURITYADMIN roles to:${NC}"
    echo "  - Create and manage database objects (SYSADMIN)"
    echo "  - Create and grant roles (SECURITYADMIN)"
    echo ""
    echo -e "${YELLOW}Please have your Snowflake administrator grant the missing role(s):${NC}"
    for role in "${MISSING_ROLES[@]}"; do
        echo -e "${YELLOW}  GRANT ROLE ${role} TO USER $(whoami);${NC}"
    done
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ All required roles available - proceeding with deployment${NC}"
echo ""

# Get configuration values - prompt only if not accepting defaults
if [ "$ACCEPT_DEFAULTS" = "true" ]; then
    # Use all default values without prompting
    DATABASE_NAME="$DEFAULT_DATABASE"
    SCHEMA_NAME="$DEFAULT_SCHEMA"
    WAREHOUSE_NAME="$DEFAULT_WAREHOUSE"
    SRC_STAGE_NAME="$DEFAULT_SRC_STAGE"
    COMPLETED_STAGE_NAME="$DEFAULT_COMPLETED_STAGE"
    ERROR_STAGE_NAME="$DEFAULT_ERROR_STAGE"
    ARCHIVE_STAGE_NAME="$DEFAULT_ARCHIVE_STAGE"
    DISCOVER_TASK_NAME="$DEFAULT_DISCOVER_TASK"
    PROCESS_TASK_NAME="$DEFAULT_PROCESS_TASK"
    MOVE_SUCCESS_TASK_NAME="$DEFAULT_MOVE_SUCCESS_TASK"
    MOVE_FAILED_TASK_NAME="$DEFAULT_MOVE_FAILED_TASK"
    STREAMLIT_APP_NAME="$DEFAULT_STREAMLIT_APP"
    DISCOVER_TASK_SCHEDULE_MINUTES="$DEFAULT_DISCOVER_SCHEDULE"
    
    echo -e "${GREEN}Using configuration from ${CONFIG_FILE}${NC}"
else
    # Prompt for each value (allow override of config values)
    echo -e "${YELLOW}Database Configuration (press Enter to use config values):${NC}"
    read -p "Database name [${DEFAULT_DATABASE}]: " DATABASE_NAME
    DATABASE_NAME=${DATABASE_NAME:-$DEFAULT_DATABASE}

    read -p "Schema name [${DEFAULT_SCHEMA}]: " SCHEMA_NAME
    SCHEMA_NAME=${SCHEMA_NAME:-$DEFAULT_SCHEMA}

    read -p "Warehouse name [${DEFAULT_WAREHOUSE}]: " WAREHOUSE_NAME
    WAREHOUSE_NAME=${WAREHOUSE_NAME:-$DEFAULT_WAREHOUSE}

    echo ""
    echo -e "${YELLOW}Stage Configuration:${NC}"
    read -p "Source stage name [${DEFAULT_SRC_STAGE}]: " SRC_STAGE_NAME
    SRC_STAGE_NAME=${SRC_STAGE_NAME:-$DEFAULT_SRC_STAGE}

    read -p "Completed stage name [${DEFAULT_COMPLETED_STAGE}]: " COMPLETED_STAGE_NAME
    COMPLETED_STAGE_NAME=${COMPLETED_STAGE_NAME:-$DEFAULT_COMPLETED_STAGE}

    read -p "Error stage name [${DEFAULT_ERROR_STAGE}]: " ERROR_STAGE_NAME
    ERROR_STAGE_NAME=${ERROR_STAGE_NAME:-$DEFAULT_ERROR_STAGE}
    
    read -p "Archive stage name (30+ day old files) [${DEFAULT_ARCHIVE_STAGE}]: " ARCHIVE_STAGE_NAME
    ARCHIVE_STAGE_NAME=${ARCHIVE_STAGE_NAME:-$DEFAULT_ARCHIVE_STAGE}

    echo ""
    echo -e "${YELLOW}Task Configuration:${NC}"
    read -p "Discover files task name [${DEFAULT_DISCOVER_TASK}]: " DISCOVER_TASK_NAME
    DISCOVER_TASK_NAME=${DISCOVER_TASK_NAME:-$DEFAULT_DISCOVER_TASK}

    read -p "Process files task name [${DEFAULT_PROCESS_TASK}]: " PROCESS_TASK_NAME
    PROCESS_TASK_NAME=${PROCESS_TASK_NAME:-$DEFAULT_PROCESS_TASK}

    read -p "Move successful files task name [${DEFAULT_MOVE_SUCCESS_TASK}]: " MOVE_SUCCESS_TASK_NAME
    MOVE_SUCCESS_TASK_NAME=${MOVE_SUCCESS_TASK_NAME:-$DEFAULT_MOVE_SUCCESS_TASK}

    read -p "Move failed files task name [${DEFAULT_MOVE_FAILED_TASK}]: " MOVE_FAILED_TASK_NAME
    MOVE_FAILED_TASK_NAME=${MOVE_FAILED_TASK_NAME:-$DEFAULT_MOVE_FAILED_TASK}
    
    echo ""
    echo -e "${YELLOW}Task Schedule Configuration:${NC}"
    read -p "Discovery task schedule (minutes) [${DEFAULT_DISCOVER_SCHEDULE}]: " DISCOVER_TASK_SCHEDULE_MINUTES
    DISCOVER_TASK_SCHEDULE_MINUTES=${DISCOVER_TASK_SCHEDULE_MINUTES:-$DEFAULT_DISCOVER_SCHEDULE}
    
    echo ""
    echo -e "${YELLOW}Streamlit App Configuration:${NC}"
    read -p "Streamlit app name [${DEFAULT_STREAMLIT_APP}]: " STREAMLIT_APP_NAME
    STREAMLIT_APP_NAME=${STREAMLIT_APP_NAME:-$DEFAULT_STREAMLIT_APP}
fi

echo ""
echo -e "${BLUE}Deployment Configuration:${NC}"
echo "  Database:        ${DATABASE_NAME}"
echo "  Schema:          ${SCHEMA_NAME}"
echo "  Warehouse:       ${WAREHOUSE_NAME}"
echo ""
echo "  Source Stage:    ${SRC_STAGE_NAME}"
echo "  Completed Stage: ${COMPLETED_STAGE_NAME}"
echo "  Error Stage:     ${ERROR_STAGE_NAME}"
echo "  Archive Stage:   ${ARCHIVE_STAGE_NAME}"
echo ""
echo "  Discover Task:   ${DISCOVER_TASK_NAME}"
echo "  Process Task:    ${PROCESS_TASK_NAME}"
echo "  Move Success:    ${MOVE_SUCCESS_TASK_NAME}"
echo "  Move Failed:     ${MOVE_FAILED_TASK_NAME}"
echo ""
echo "  Task Schedule:"
echo "    Discovery:     Every ${DISCOVER_TASK_SCHEDULE_MINUTES} minutes"
echo ""
echo "  Streamlit App:   ${STREAMLIT_APP_NAME}"
echo ""

# Confirm deployment (skip if ACCEPT_DEFAULTS is true)
if [ "$ACCEPT_DEFAULTS" != "true" ]; then
    read -p "Proceed with deployment? (yes/no): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${RED}Deployment cancelled.${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}Auto-proceeding with deployment (ACCEPT_DEFAULTS=true)${NC}"
fi

# Create temporary directory for modified SQL files
TEMP_DIR=$(mktemp -d)
echo ""
echo -e "${BLUE}Creating temporary working directory: ${TEMP_DIR}${NC}"

# Cross-platform sed in-place function
sed_inplace() {
    if [ "$OS" = "macOS" ]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Function to replace variables in SQL files
replace_variables() {
    local input_file=$1
    local output_file=$2
    
    # Use a more careful approach with sed to avoid breaking SQL
    # First copy the file, then do replacements in place
    cp "$input_file" "$output_file"
    
    # Replace database name
    sed_inplace "s/'db_ingest_pipeline'/'${DATABASE_NAME}'/g" "$output_file"
    sed_inplace "s/= 'db_ingest_pipeline'/= '${DATABASE_NAME}'/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$DATABASE_NAME)/IDENTIFIER('${DATABASE_NAME}')/g" "$output_file"
    
    # Replace schema name  
    sed_inplace "s/'BRONZE'/'${SCHEMA_NAME}'/g" "$output_file"
    sed_inplace "s/= 'BRONZE'/= '${SCHEMA_NAME}'/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$SCHEMA_NAME)/IDENTIFIER('${SCHEMA_NAME}')/g" "$output_file"
    
    # Replace warehouse name
    sed_inplace "s/'COMPUTE_WH'/'${WAREHOUSE_NAME}'/g" "$output_file"
    sed_inplace "s/= 'COMPUTE_WH'/= '${WAREHOUSE_NAME}'/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$WAREHOUSE_NAME)/IDENTIFIER('${WAREHOUSE_NAME}')/g" "$output_file"
    sed_inplace "s/'\\\$WAREHOUSE_NAME'/'${WAREHOUSE_NAME}'/g" "$output_file"
    
    # Replace stage names (be careful with @SRC to not replace in strings)
    sed_inplace "s/IDENTIFIER(\\\$SRC_STAGE_NAME)/IDENTIFIER('${SRC_STAGE_NAME}')/g" "$output_file"
    sed_inplace "s/= 'SRC'/= '${SRC_STAGE_NAME}'/g" "$output_file"
    sed_inplace "s/@SRC/@${SRC_STAGE_NAME}/g" "$output_file"
    sed_inplace "s/'SRC'/'${SRC_STAGE_NAME}'/g" "$output_file"
    sed_inplace "s/'\\\$SRC_STAGE_NAME'/'${SRC_STAGE_NAME}'/g" "$output_file"
    
    sed_inplace "s/IDENTIFIER(\\\$COMPLETED_STAGE_NAME)/IDENTIFIER('${COMPLETED_STAGE_NAME}')/g" "$output_file"
    sed_inplace "s/@SRC_COMPLETED/@${COMPLETED_STAGE_NAME}/g" "$output_file"
    sed_inplace "s/'SRC_COMPLETED'/'${COMPLETED_STAGE_NAME}'/g" "$output_file"
    
    sed_inplace "s/IDENTIFIER(\\\$ERROR_STAGE_NAME)/IDENTIFIER('${ERROR_STAGE_NAME}')/g" "$output_file"
    sed_inplace "s/@SRC_ERROR/@${ERROR_STAGE_NAME}/g" "$output_file"
    sed_inplace "s/'SRC_ERROR'/'${ERROR_STAGE_NAME}'/g" "$output_file"
    
    sed_inplace "s/IDENTIFIER(\\\$ARCHIVE_STAGE_NAME)/IDENTIFIER('${ARCHIVE_STAGE_NAME}')/g" "$output_file"
    sed_inplace "s/@SRC_ARCHIVE/@${ARCHIVE_STAGE_NAME}/g" "$output_file"
    sed_inplace "s/'SRC_ARCHIVE'/'${ARCHIVE_STAGE_NAME}'/g" "$output_file"
    
    # Replace task names
    sed_inplace "s/discover_files_task/${DISCOVER_TASK_NAME}/g" "$output_file"
    sed_inplace "s/process_files_task/${PROCESS_TASK_NAME}/g" "$output_file"
    sed_inplace "s/move_successful_files_task/${MOVE_SUCCESS_TASK_NAME}/g" "$output_file"
    sed_inplace "s/move_failed_files_task/${MOVE_FAILED_TASK_NAME}/g" "$output_file"
    sed_inplace "s/archive_old_files_task/${ARCHIVE_TASK_NAME}/g" "$output_file"
    sed_inplace "s/'\\\$DISCOVER_TASK_NAME'/'${DISCOVER_TASK_NAME}'/g" "$output_file"
    
    # Replace task schedule (replace the entire schedule string)
    sed_inplace "s/'\\\$DISCOVER_TASK_SCHEDULE_MINUTES MINUTE'/'${DISCOVER_TASK_SCHEDULE_MINUTES} MINUTE'/g" "$output_file"
    sed_inplace "s/'\\\$DISCOVER_TASK_SCHEDULE_MINUTES'/'${DISCOVER_TASK_SCHEDULE_MINUTES}'/g" "$output_file"
    
    # Replace Streamlit app name
    sed_inplace "s/IDENTIFIER(\\\$STREAMLIT_APP_NAME)/IDENTIFIER('${STREAMLIT_APP_NAME}')/g" "$output_file"
}

# Function to execute SQL file
execute_sql() {
    local sql_file=$1
    local description=$2
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Executing: ${description}${NC}"
    echo -e "${GREEN}File: ${sql_file}${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Use snow sql to execute the SQL file
    if run_snow_sql -f "$sql_file" ; then
        echo -e "${GREEN}✓ Successfully executed: ${description}${NC}"
    else
        echo -e "${RED}✗ Failed to execute: ${description}${NC}"
        echo -e "${RED}Please check your connection has SYSADMIN and SECURITYADMIN permissions${NC}"
        exit 1
    fi
}

# Prepare SQL files with variable substitution
echo ""
echo -e "${BLUE}Preparing SQL files...${NC}"

SQL_FILES=(
    "bronze/1_Setup_Database_Roles.sql"
    "bronze/2_Bronze_Schema_Tables.sql"
    "bronze/3_Bronze_Setup_Logic.sql"
    "bronze/4_Bronze_Tasks.sql"
)

DESCRIPTIONS=(
    "Step 1: Database and RBAC Setup"
    "Step 2: Schema, Stages, and Tables"
    "Step 3: File Processing Stored Procedures"
    "Step 4: Task Pipeline Creation and Activation"
)

for i in "${!SQL_FILES[@]}"; do
    sql_file="${SQL_FILES[$i]}"
    if [ ! -f "$sql_file" ]; then
        echo -e "${RED}ERROR: File not found: ${sql_file}${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    temp_file="${TEMP_DIR}/$(basename ${sql_file})"
    replace_variables "$sql_file" "$temp_file"
    echo -e "  ${GREEN}✓${NC} Prepared: $(basename ${sql_file})"
done

# Execute SQL files in order
echo ""
echo -e "${BLUE}Starting pipeline deployment...${NC}"

for i in "${!SQL_FILES[@]}"; do
    temp_file="${TEMP_DIR}/$(basename ${SQL_FILES[$i]})"
    execute_sql "$temp_file" "${DESCRIPTIONS[$i]}"
done

# Deploy Streamlit app
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Deploying Streamlit in Snowflake Application${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if streamlit app exists
if [ ! -f "bronze/bronze_streamlit/streamlit_app.py" ]; then
    echo -e "${YELLOW}⚠ Warning: bronze/bronze_streamlit/streamlit_app.py not found, skipping Streamlit deployment${NC}"
else
    echo ""
    echo -e "${GREEN}Step 5: Uploading configuration files (optional)${NC}"
    
    # Upload config files to CONFIG_STAGE in PUBLIC schema
    # Note: This is optional - Streamlit app has default values as fallback
    CONFIG_STAGE_PATH="@${DATABASE_NAME}.PUBLIC.CONFIG_STAGE"
    
    echo -e "${BLUE}Uploading configuration to ${CONFIG_STAGE_PATH}...${NC}"
    echo -e "${BLUE}(Streamlit app will use defaults if upload fails)${NC}"
    
    # Upload the config file being used
    if [ -f "$CONFIG_FILE" ]; then
        if [ "$USE_DEFAULT_CONNECTION" = true ]; then
            UPLOAD_CMD="snow stage copy \"$CONFIG_FILE\" \"${CONFIG_STAGE_PATH}/\" --overwrite"
        else
            UPLOAD_CMD="snow stage copy \"$CONFIG_FILE\" \"${CONFIG_STAGE_PATH}/\" --overwrite --connection \"$SNOW_CONNECTION\""
        fi
        if eval "$UPLOAD_CMD" 2>/dev/null; then
            echo -e "${GREEN}✓ Uploaded configuration file - Streamlit app will use your custom settings${NC}"
        else
            echo -e "${YELLOW}⚠ Config upload skipped - Streamlit app will use default values${NC}"
            echo -e "${YELLOW}  (This is fine if you're using default database/schema/warehouse names)${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}Step 6: Creating Streamlit stages${NC}"
    
    # First create the stages using SQL (required before snow streamlit deploy)
    STREAMLIT_STAGES_SQL="${TEMP_DIR}/create_streamlit_stages.sql"
    cat > "$STREAMLIT_STAGES_SQL" << EOF
USE ROLE ACCOUNTADMIN;
USE DATABASE ${DATABASE_NAME};
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

-- Grant permissions
SET role_admin = '${DATABASE_NAME}_ADMIN';
SET role_readwrite = '${DATABASE_NAME}_READWRITE';
SET role_readonly = '${DATABASE_NAME}_READONLY';

GRANT READ ON STAGE CONFIG_STAGE TO ROLE IDENTIFIER(\$role_admin);
GRANT READ ON STAGE CONFIG_STAGE TO ROLE IDENTIFIER(\$role_readwrite);
GRANT READ ON STAGE CONFIG_STAGE TO ROLE IDENTIFIER(\$role_readonly);

GRANT USAGE ON SCHEMA PUBLIC TO ROLE IDENTIFIER(\$role_admin);
GRANT USAGE ON SCHEMA PUBLIC TO ROLE IDENTIFIER(\$role_readwrite);
GRANT USAGE ON SCHEMA PUBLIC TO ROLE IDENTIFIER(\$role_readonly);
EOF
    
    if run_snow_sql -f "$STREAMLIT_STAGES_SQL" 2>/dev/null; then
        echo -e "${GREEN}✓ Successfully created Streamlit stages${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Could not create stages (may already exist)${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}Step 7: Deploying Streamlit application using Snowflake CLI${NC}"
    
    echo -e "${BLUE}Using Snowflake CLI native Streamlit deployment...${NC}"
    echo -e "${BLUE}App Name: ${STREAMLIT_APP_NAME}${NC}"
    echo -e "${BLUE}Database: ${DATABASE_NAME}.PUBLIC${NC}"
    echo -e "${BLUE}Warehouse: ${WAREHOUSE_NAME}${NC}"
    
    # Generate snowflake.yml with actual values (ctx.env not available in SiS)
    # Convert app name to user-friendly title (replace underscores with spaces, title case)
    STREAMLIT_TITLE=$(echo "${STREAMLIT_APP_NAME}" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
    
    STREAMLIT_YML="${TEMP_DIR}/snowflake.yml"
    cat > "$STREAMLIT_YML" << EOF
definition_version: 2

entities:
  streamlit_app:
    type: streamlit
    identifier:
      name: ${STREAMLIT_APP_NAME}
    title: ${STREAMLIT_TITLE}
    query_warehouse: ${WAREHOUSE_NAME}
    main_file: streamlit_app.py
    stage: STREAMLIT_STAGE
    artifacts:
      - streamlit_app.py
      - environment.yml
EOF
    
    # Copy generated snowflake.yml to streamlit directory
    cp "$STREAMLIT_YML" bronze/bronze_streamlit/snowflake.yml
    
    # Change to streamlit directory for deployment
    cd bronze/bronze_streamlit
    
    # Deploy using snow streamlit deploy
    if [ "$USE_DEFAULT_CONNECTION" = true ]; then
        DEPLOY_CMD="snow streamlit deploy --replace --database \"${DATABASE_NAME}\" --schema PUBLIC"
    else
        DEPLOY_CMD="snow streamlit deploy --replace --database \"${DATABASE_NAME}\" --schema PUBLIC --connection \"$SNOW_CONNECTION\""
    fi
    
    if eval "$DEPLOY_CMD" 2>&1 | tee /tmp/streamlit_deploy.log; then
        echo -e "${GREEN}✓ Successfully deployed Streamlit app${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Streamlit deployment had issues (check /tmp/streamlit_deploy.log)${NC}"
    fi
    
    # Return to project root
    cd ../..
    
    # Grant permissions to the Streamlit app
    echo -e "${BLUE}Granting permissions to pipeline roles...${NC}"
    GRANT_SQL="${TEMP_DIR}/grant_streamlit_permissions.sql"
    cat > "$GRANT_SQL" << EOF
USE ROLE ACCOUNTADMIN;
USE DATABASE ${DATABASE_NAME};
USE SCHEMA PUBLIC;

SET role_admin = '${DATABASE_NAME}_ADMIN';
SET role_readwrite = '${DATABASE_NAME}_READWRITE';
SET role_readonly = '${DATABASE_NAME}_READONLY';

GRANT USAGE ON STREAMLIT "${STREAMLIT_APP_NAME}" TO ROLE IDENTIFIER(\$role_admin);
GRANT USAGE ON STREAMLIT "${STREAMLIT_APP_NAME}" TO ROLE IDENTIFIER(\$role_readwrite);
GRANT USAGE ON STREAMLIT "${STREAMLIT_APP_NAME}" TO ROLE IDENTIFIER(\$role_readonly);
EOF
    
    if run_snow_sql -f "$GRANT_SQL" 2>/dev/null; then
        echo -e "${GREEN}✓ Successfully granted permissions${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Could not grant permissions${NC}"
    fi
fi

# Cleanup
echo ""
echo -e "${BLUE}Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"

# Success message
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Bronze Layer Deployment Completed! 🎉${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Pipeline Configuration:${NC}"
echo "  Database:        ${DATABASE_NAME}"
echo "  Schema:          ${SCHEMA_NAME}"
echo "  Warehouse:       ${WAREHOUSE_NAME}"
echo ""
echo "  Stages:"
echo "    Source:        @${DATABASE_NAME}.${SCHEMA_NAME}.${SRC_STAGE_NAME}"
echo "    Completed:     @${DATABASE_NAME}.${SCHEMA_NAME}.${COMPLETED_STAGE_NAME}"
echo "    Error:         @${DATABASE_NAME}.${SCHEMA_NAME}.${ERROR_STAGE_NAME}"
echo "    Archive:       @${DATABASE_NAME}.${SCHEMA_NAME}.${ARCHIVE_STAGE_NAME}"
echo ""
echo "  Tasks:"
echo "    1. ${DISCOVER_TASK_NAME} (every ${DISCOVER_TASK_SCHEDULE_MINUTES} min)"
echo "    2. ${PROCESS_TASK_NAME}"
echo "    3. ${MOVE_SUCCESS_TASK_NAME}"
echo "    4. ${MOVE_FAILED_TASK_NAME}"
echo "    5. archive_old_files_task (daily 2 AM)"
echo ""
echo -e "${BLUE}Streamlit Application:${NC}"
if [ -f "bronze/bronze_streamlit/streamlit_app.py" ]; then
    echo "  App Name:        ${STREAMLIT_APP_NAME}"
    echo "  Location:        ${DATABASE_NAME}.PUBLIC"
    echo "  Configuration:   @${DATABASE_NAME}.PUBLIC.CONFIG_STAGE"
    echo ""
    echo "  Access Steps:"
    echo "    1. Navigate to Snowsight"
    echo "    2. Click 'Streamlit' in the left sidebar"
    echo "    3. Open '${STREAMLIT_APP_NAME}'"
else
    echo "  Not deployed (bronze/bronze_streamlit/streamlit_app.py not found)"
fi
echo ""
echo -e "${BLUE}Upload Files:${NC}"
echo "  Via Streamlit:   Open ${STREAMLIT_APP_NAME} in Snowsight"
echo "  Via CLI:         PUT file:///path/to/file.csv @${DATABASE_NAME}.${SCHEMA_NAME}.${SRC_STAGE_NAME};"
echo ""
echo -e "${BLUE}Monitor Processing:${NC}"
echo -e "${YELLOW}     USE DATABASE ${DATABASE_NAME};${NC}"
echo -e "${YELLOW}     USE SCHEMA ${SCHEMA_NAME};${NC}"
echo -e "${YELLOW}     SELECT * FROM file_processing_queue ORDER BY discovered_timestamp DESC;${NC}"
echo ""
echo -e "${BLUE}View task execution history:${NC}"
echo -e "${YELLOW}     SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME${NC}"
echo -e "${YELLOW}     FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())${NC}"
echo -e "${YELLOW}     WHERE NAME IN ('${DISCOVER_TASK_NAME}', '${PROCESS_TASK_NAME}',${NC}"
echo -e "${YELLOW}                    '${MOVE_SUCCESS_TASK_NAME}', '${MOVE_FAILED_TASK_NAME}')${NC}"
echo -e "${YELLOW}     ORDER BY SCHEDULED_TIME DESC LIMIT 20;${NC}"
echo ""
echo -e "${BLUE}To suspend the pipeline:${NC}"
echo -e "${YELLOW}     ALTER TASK ${DATABASE_NAME}.${SCHEMA_NAME}.${DISCOVER_TASK_NAME} SUSPEND;${NC}"
echo ""
echo -e "${BLUE}To resume the pipeline:${NC}"
echo -e "${YELLOW}     ALTER TASK ${DATABASE_NAME}.${SCHEMA_NAME}.${MOVE_FAILED_TASK_NAME} RESUME;${NC}"
echo -e "${YELLOW}     ALTER TASK ${DATABASE_NAME}.${SCHEMA_NAME}.${MOVE_SUCCESS_TASK_NAME} RESUME;${NC}"
echo -e "${YELLOW}     ALTER TASK ${DATABASE_NAME}.${SCHEMA_NAME}.${PROCESS_TASK_NAME} RESUME;${NC}"
echo -e "${YELLOW}     ALTER TASK ${DATABASE_NAME}.${SCHEMA_NAME}.${DISCOVER_TASK_NAME} RESUME;${NC}"
echo ""
echo -e "${GREEN}Deployment completed at: $(date)${NC}"

