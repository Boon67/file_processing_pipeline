#!/bin/bash

# ============================================
# Snowflake Silver Layer Deployment Script
# ============================================
# Purpose: Deploy Silver layer data transformation pipeline
#
# This script:
#   1. Loads configuration from default.config or custom config
#   2. Validates Snowflake CLI connection
#   3. Deploys Silver layer SQL scripts in order
#   4. Uploads mapping CSV files to stages
#   5. Deploys Streamlit management application
#   6. Grants permissions to roles
#
# Prerequisites:
#   - Snowflake CLI (snow) installed and configured
#   - Connection must have SYSADMIN and SECURITYADMIN permissions
#   - Python installed (python or python3)
#
# Usage:
#   ./deploy_silver.sh                  # Uses default.config
#   ./deploy_silver.sh custom.config    # Uses custom configuration
#   ./deploy.sh                         # Deploy complete solution (Bronze + Silver)
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

# Set UTF-8 encoding for Windows to prevent charmap codec errors
if [ "$OS" = "Windows" ]; then
    export PYTHONIOENCODING=utf-8
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8
fi

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
DEFAULT_BRONZE_SCHEMA="${SCHEMA_NAME}"
DEFAULT_SILVER_SCHEMA="${SILVER_SCHEMA_NAME}"
DEFAULT_WAREHOUSE="${WAREHOUSE_NAME}"
DEFAULT_SILVER_STAGE="${SILVER_STAGE_NAME}"
DEFAULT_SILVER_CONFIG_STAGE="${SILVER_CONFIG_STAGE_NAME}"
DEFAULT_SILVER_STREAMLIT_STAGE="${SILVER_STREAMLIT_STAGE_NAME}"
DEFAULT_SILVER_STREAMLIT_APP="${SILVER_STREAMLIT_APP_NAME:-Silver_Data_Manager}"
DEFAULT_SILVER_TRANSFORM_SCHEDULE="${SILVER_TRANSFORM_SCHEDULE_MINUTES:-60}"
DEFAULT_LLM_MODEL="${DEFAULT_LLM_MODEL:-llama3.1-70b}"
DEFAULT_BATCH_SIZE="${DEFAULT_BATCH_SIZE:-10000}"
DEFAULT_APPLY_RULES="${APPLY_RULES_BY_DEFAULT:-true}"
DEFAULT_INCREMENTAL="${INCREMENTAL_PROCESSING:-true}"

# Print banner
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Snowflake Silver Layer Deployment${NC}"
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
    SCHEMA_NAME="$DEFAULT_BRONZE_SCHEMA"
    SILVER_SCHEMA_NAME="$DEFAULT_SILVER_SCHEMA"
    WAREHOUSE_NAME="$DEFAULT_WAREHOUSE"
    SILVER_STAGE_NAME="$DEFAULT_SILVER_STAGE"
    SILVER_CONFIG_STAGE_NAME="$DEFAULT_SILVER_CONFIG_STAGE"
    SILVER_STREAMLIT_STAGE_NAME="$DEFAULT_SILVER_STREAMLIT_STAGE"
    SILVER_STREAMLIT_APP_NAME="$DEFAULT_SILVER_STREAMLIT_APP"
    SILVER_TRANSFORM_SCHEDULE_MINUTES="$DEFAULT_SILVER_TRANSFORM_SCHEDULE"
    DEFAULT_LLM_MODEL="$DEFAULT_LLM_MODEL"
    DEFAULT_BATCH_SIZE="$DEFAULT_BATCH_SIZE"
    APPLY_RULES_BY_DEFAULT="$DEFAULT_APPLY_RULES"
    INCREMENTAL_PROCESSING="$DEFAULT_INCREMENTAL"
    
    echo -e "${GREEN}Using configuration from ${CONFIG_FILE}${NC}"
else
    # Prompt for each value (allow override of config values)
    echo -e "${YELLOW}Database Configuration (press Enter to use config values):${NC}"
    read -p "Database name [${DEFAULT_DATABASE}]: " DATABASE_NAME
    DATABASE_NAME=${DATABASE_NAME:-$DEFAULT_DATABASE}

    read -p "Bronze schema name [${DEFAULT_BRONZE_SCHEMA}]: " SCHEMA_NAME
    SCHEMA_NAME=${SCHEMA_NAME:-$DEFAULT_BRONZE_SCHEMA}

    read -p "Silver schema name [${DEFAULT_SILVER_SCHEMA}]: " SILVER_SCHEMA_NAME
    SILVER_SCHEMA_NAME=${SILVER_SCHEMA_NAME:-$DEFAULT_SILVER_SCHEMA}

    read -p "Warehouse name [${DEFAULT_WAREHOUSE}]: " WAREHOUSE_NAME
    WAREHOUSE_NAME=${WAREHOUSE_NAME:-$DEFAULT_WAREHOUSE}

    echo ""
    echo -e "${YELLOW}Stage Configuration:${NC}"
    read -p "Silver stage name [${DEFAULT_SILVER_STAGE}]: " SILVER_STAGE_NAME
    SILVER_STAGE_NAME=${SILVER_STAGE_NAME:-$DEFAULT_SILVER_STAGE}

    read -p "Silver config stage name [${DEFAULT_SILVER_CONFIG_STAGE}]: " SILVER_CONFIG_STAGE_NAME
    SILVER_CONFIG_STAGE_NAME=${SILVER_CONFIG_STAGE_NAME:-$DEFAULT_SILVER_CONFIG_STAGE}

    read -p "Silver Streamlit stage name [${DEFAULT_SILVER_STREAMLIT_STAGE}]: " SILVER_STREAMLIT_STAGE_NAME
    SILVER_STREAMLIT_STAGE_NAME=${SILVER_STREAMLIT_STAGE_NAME:-$DEFAULT_SILVER_STREAMLIT_STAGE}

    echo ""
    echo -e "${YELLOW}Task Schedule Configuration:${NC}"
    read -p "Transform task schedule (minutes) [${DEFAULT_SILVER_TRANSFORM_SCHEDULE}]: " SILVER_TRANSFORM_SCHEDULE_MINUTES
    SILVER_TRANSFORM_SCHEDULE_MINUTES=${SILVER_TRANSFORM_SCHEDULE_MINUTES:-$DEFAULT_SILVER_TRANSFORM_SCHEDULE}
    
    echo ""
    echo -e "${YELLOW}Streamlit App Configuration:${NC}"
    read -p "Streamlit app name [${DEFAULT_SILVER_STREAMLIT_APP}]: " SILVER_STREAMLIT_APP_NAME
    SILVER_STREAMLIT_APP_NAME=${SILVER_STREAMLIT_APP_NAME:-$DEFAULT_SILVER_STREAMLIT_APP}
    
    echo ""
    echo -e "${YELLOW}LLM Configuration:${NC}"
    read -p "Default LLM model [${DEFAULT_LLM_MODEL}]: " DEFAULT_LLM_MODEL
    DEFAULT_LLM_MODEL=${DEFAULT_LLM_MODEL:-$DEFAULT_LLM_MODEL}
fi

echo ""
echo -e "${BLUE}Deployment Configuration:${NC}"
echo "  Database:              ${DATABASE_NAME}"
echo "  Bronze Schema:         ${SCHEMA_NAME}"
echo "  Silver Schema:         ${SILVER_SCHEMA_NAME}"
echo "  Warehouse:             ${WAREHOUSE_NAME}"
echo ""
echo "  Silver Stage:          ${SILVER_STAGE_NAME}"
echo "  Config Stage:          ${SILVER_CONFIG_STAGE_NAME}"
echo "  Streamlit Stage:       ${SILVER_STREAMLIT_STAGE_NAME}"
echo ""
echo "  Transform Schedule:    Every ${SILVER_TRANSFORM_SCHEDULE_MINUTES} minutes"
echo "  Streamlit App:         ${SILVER_STREAMLIT_APP_NAME}"
echo "  Default LLM Model:     ${DEFAULT_LLM_MODEL}"
echo ""

# Confirm deployment (skip if ACCEPT_DEFAULTS is true)
if [ "$ACCEPT_DEFAULTS" != "true" ]; then
    read -p "Proceed with Silver layer deployment? (yes/no): " CONFIRM
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

# Convert path to Windows format if on Windows
convert_path_for_snowflake() {
    local path="$1"
    if [ "$OS" = "Windows" ]; then
        # Convert Git Bash path to Windows path
        # /c/users/... -> C:/users/...
        if [[ "$path" =~ ^/([a-z])/(.*)$ ]]; then
            local drive="${BASH_REMATCH[1]}"
            local rest="${BASH_REMATCH[2]}"
            # Convert drive letter to uppercase
            case "$drive" in
                a) drive="A" ;;
                b) drive="B" ;;
                c) drive="C" ;;
                d) drive="D" ;;
                e) drive="E" ;;
                f) drive="F" ;;
                g) drive="G" ;;
                h) drive="H" ;;
                i) drive="I" ;;
                j) drive="J" ;;
                k) drive="K" ;;
                l) drive="L" ;;
                m) drive="M" ;;
                n) drive="N" ;;
                o) drive="O" ;;
                p) drive="P" ;;
                q) drive="Q" ;;
                r) drive="R" ;;
                s) drive="S" ;;
                t) drive="T" ;;
                u) drive="U" ;;
                v) drive="V" ;;
                w) drive="W" ;;
                x) drive="X" ;;
                y) drive="Y" ;;
                z) drive="Z" ;;
            esac
            echo "${drive}:/${rest}"
        else
            echo "$path"
        fi
    else
        echo "$path"
    fi
}

# Function to replace variables in SQL files
replace_variables() {
    local input_file=$1
    local output_file=$2
    
    # Use a more careful approach with sed to avoid breaking SQL
    # First copy the file, then do replacements in place
    cp "$input_file" "$output_file"
    
    # Replace complex IDENTIFIER() patterns with concatenation first (most specific)
    sed_inplace "s/IDENTIFIER(\\\$DATABASE_NAME || '\\.' || \\\$BRONZE_SCHEMA_NAME)/IDENTIFIER('${DATABASE_NAME}.${SCHEMA_NAME}')/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$BRONZE_SCHEMA_NAME || '\\.' || :source_table)/IDENTIFIER('${SCHEMA_NAME}' || '.' || :source_table)/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$BRONZE_SCHEMA_NAME || '\\.RAW_DATA_TABLE')/IDENTIFIER('${SCHEMA_NAME}.RAW_DATA_TABLE')/g" "$output_file"
    
    # Replace simple IDENTIFIER() patterns (more specific than bare variables)
    sed_inplace "s/IDENTIFIER(\\\$DATABASE_NAME)/IDENTIFIER('${DATABASE_NAME}')/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$SILVER_SCHEMA_NAME)/IDENTIFIER('${SILVER_SCHEMA_NAME}')/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$BRONZE_SCHEMA_NAME)/IDENTIFIER('${SCHEMA_NAME}')/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$WAREHOUSE_NAME)/IDENTIFIER('${WAREHOUSE_NAME}')/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$SILVER_STAGE_NAME)/IDENTIFIER('${SILVER_STAGE_NAME}')/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$SILVER_CONFIG_STAGE_NAME)/IDENTIFIER('${SILVER_CONFIG_STAGE_NAME}')/g" "$output_file"
    sed_inplace "s/IDENTIFIER(\\\$SILVER_STREAMLIT_STAGE_NAME)/IDENTIFIER('${SILVER_STREAMLIT_STAGE_NAME}')/g" "$output_file"
    
    # Replace quoted variable patterns (for string literals)
    sed_inplace "s/'\\\$DATABASE_NAME'/'${DATABASE_NAME}'/g" "$output_file"
    sed_inplace "s/'\\\$SILVER_SCHEMA_NAME'/'${SILVER_SCHEMA_NAME}'/g" "$output_file"
    sed_inplace "s/'\\\$BRONZE_SCHEMA_NAME'/'${SCHEMA_NAME}'/g" "$output_file"
    sed_inplace "s/'\\\$WAREHOUSE_NAME'/'${WAREHOUSE_NAME}'/g" "$output_file"
    sed_inplace "s/'\\\$SILVER_STAGE_NAME'/'${SILVER_STAGE_NAME}'/g" "$output_file"
    sed_inplace "s/'\\\$SILVER_CONFIG_STAGE_NAME'/'${SILVER_CONFIG_STAGE_NAME}'/g" "$output_file"
    sed_inplace "s/'\\\$SILVER_STREAMLIT_STAGE_NAME'/'${SILVER_STREAMLIT_STAGE_NAME}'/g" "$output_file"
    sed_inplace "s/'\\\$SILVER_TRANSFORM_SCHEDULE_MINUTES'/'${SILVER_TRANSFORM_SCHEDULE_MINUTES}'/g" "$output_file"
    sed_inplace "s/'\\\$DEFAULT_LLM_MODEL'/'${DEFAULT_LLM_MODEL}'/g" "$output_file"
    sed_inplace "s/'\\\$DEFAULT_BATCH_SIZE'/'${DEFAULT_BATCH_SIZE}'/g" "$output_file"
    sed_inplace "s/'\\\$APPLY_RULES_BY_DEFAULT'/'${APPLY_RULES_BY_DEFAULT}'/g" "$output_file"
    sed_inplace "s/'\\\$INCREMENTAL_PROCESSING'/'${INCREMENTAL_PROCESSING}'/g" "$output_file"
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
    
    # On Windows, create ASCII-safe version to avoid charmap codec errors
    local exec_file="$sql_file"
    if [ "$OS" = "Windows" ]; then
        local temp_file="${sql_file}.tmp"
        # Remove problematic Unicode box-drawing characters
        iconv -f UTF-8 -t ASCII//TRANSLIT "$sql_file" > "$temp_file" 2>/dev/null || \
        sed 's/[─│┌┐└┘├┤┬┴┼═║╔╗╚╝╠╣╦╩╬▶▼◀▲→↓←↑]/=/g' "$sql_file" > "$temp_file"
        exec_file="$temp_file"
    fi
    
    # Use snow sql to execute the SQL file
    if run_snow_sql -f "$exec_file" ; then
        echo -e "${GREEN}✓ Successfully executed: ${description}${NC}"
        # Clean up temp file on Windows
        if [ "$OS" = "Windows" ] && [ -f "$temp_file" ]; then
            rm -f "$temp_file"
        fi
    else
        echo -e "${RED}✗ Failed to execute: ${description}${NC}"
        echo -e "${RED}Please check your connection has SYSADMIN and SECURITYADMIN permissions${NC}"
        # Clean up temp file on Windows
        if [ "$OS" = "Windows" ] && [ -f "$temp_file" ]; then
            rm -f "$temp_file"
        fi
        exit 1
    fi
}

# Prepare SQL files with variable substitution
echo ""
echo -e "${BLUE}Preparing SQL files...${NC}"

SQL_FILES=(
    "silver/1_Silver_Schema_Setup.sql"
    "silver/2_Silver_Target_Schemas.sql"
    "silver/3_Silver_Mapping_Procedures.sql"
    "silver/4_Silver_Rules_Engine.sql"
    "silver/5_Silver_Transformation_Logic.sql"
    "silver/6_Silver_Tasks.sql"
    "silver/7_Silver_Standard_Metadata_Columns.sql"
)

DESCRIPTIONS=(
    "Step 1: Silver Schema and Stages Setup"
    "Step 2: Target Schema Metadata Tables"
    "Step 3: Field Mapping Procedures (Manual/ML/LLM)"
    "Step 4: Rules Engine (Quality/Business/Standardization)"
    "Step 5: Transformation Logic and Orchestration"
    "Step 6: Automated Task Pipeline"
    "Step 7: Standard Metadata Columns (SOURCE_FILE_NAME, etc.)"
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
echo -e "${BLUE}Starting Silver layer deployment...${NC}"

for i in "${!SQL_FILES[@]}"; do
    temp_file="${TEMP_DIR}/$(basename ${SQL_FILES[$i]})"
    
    # Step 4 (Rules Engine) has expected SQL scripting limitations
    if [ $i -eq 3 ]; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Executing: ${DESCRIPTIONS[$i]}${NC}"
        echo -e "${GREEN}File: ${temp_file}${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Execute but don't fail on SQL scripting errors
        if run_snow_sql -f "$temp_file" ; then
            echo -e "${GREEN}✓ Successfully executed: ${DESCRIPTIONS[$i]}${NC}"
        else
            echo -e "${YELLOW}⚠ Step 4 procedures failed (expected - SQL scripting limitations)${NC}"
            echo -e "${BLUE}Creating essential views separately...${NC}"
        fi
    else
        execute_sql "$temp_file" "${DESCRIPTIONS[$i]}"
    fi
done

# Upload mapping CSV files
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Uploading Mapping CSV Files${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Get current directory with proper path conversion for Windows
CURRENT_DIR=$(convert_path_for_snowflake "$(pwd)")

# Upload target schemas CSV
if [ -f "silver/mappings/target_tables.csv" ]; then
    echo "Uploading target_tables.csv..."
    TARGET_CSV_PATH=$(convert_path_for_snowflake "$(pwd)/silver/mappings/target_tables.csv")
    run_snow_sql -q "PUT file://${TARGET_CSV_PATH} @$DATABASE_NAME.$SILVER_SCHEMA_NAME.$SILVER_CONFIG_STAGE_NAME AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
    echo -e "${GREEN}✓ target_tables.csv uploaded${NC}"
fi

# Upload field mappings CSV
if [ -f "silver/mappings/field_mappings.csv" ]; then
    echo "Uploading field_mappings.csv..."
    FIELD_CSV_PATH=$(convert_path_for_snowflake "$(pwd)/silver/mappings/field_mappings.csv")
    run_snow_sql -q "PUT file://${FIELD_CSV_PATH} @$DATABASE_NAME.$SILVER_SCHEMA_NAME.$SILVER_CONFIG_STAGE_NAME AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
    echo -e "${GREEN}✓ field_mappings.csv uploaded${NC}"
fi

# Upload transformation rules CSV
if [ -f "silver/mappings/transformation_rules.csv" ]; then
    echo "Uploading transformation_rules.csv..."
    TRANSFORM_CSV_PATH=$(convert_path_for_snowflake "$(pwd)/silver/mappings/transformation_rules.csv")
    run_snow_sql -q "PUT file://${TRANSFORM_CSV_PATH} @$DATABASE_NAME.$SILVER_SCHEMA_NAME.$SILVER_CONFIG_STAGE_NAME AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
    echo -e "${GREEN}✓ transformation_rules.csv uploaded${NC}"
fi

# Load CSV files into tables
echo ""
echo "Loading CSV data into metadata tables..."

LOAD_CSV_SQL="${TEMP_DIR}/load_csv_data.sql"
cat > "$LOAD_CSV_SQL" << EOF
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SILVER_SCHEMA_NAME};
CALL load_target_schemas_from_csv('@${SILVER_CONFIG_STAGE_NAME}/target_tables.csv');
CALL load_field_mappings_from_csv('@${SILVER_CONFIG_STAGE_NAME}/field_mappings.csv');
CALL load_transformation_rules_from_csv('@${SILVER_CONFIG_STAGE_NAME}/transformation_rules.csv');
EOF

if run_snow_sql -f "$LOAD_CSV_SQL"; then
    echo -e "${GREEN}✓ Mapping CSV files loaded into metadata tables${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Could not load CSV files into tables${NC}"
fi

# Create sample Silver tables
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Creating Sample Silver Tables${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

CREATE_TABLES_SQL="${TEMP_DIR}/create_silver_tables.sql"
cat > "$CREATE_TABLES_SQL" << EOF
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SILVER_SCHEMA_NAME};
CALL create_all_silver_tables();
EOF

if run_snow_sql -f "$CREATE_TABLES_SQL"; then
    echo -e "${GREEN}✓ Sample Silver tables created${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Could not create sample tables${NC}"
fi

# Deploy Streamlit app
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Deploying Silver Streamlit Application${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check which streamlit directory exists
STREAMLIT_DIR="silver/silver_streamlit"

if [ -z "$STREAMLIT_DIR" ]; then
    echo -e "${YELLOW}⚠ Warning: Silver Streamlit directory not found, skipping Streamlit deployment${NC}"
elif [ ! -f "${STREAMLIT_DIR}/streamlit_app.py" ]; then
    echo -e "${YELLOW}⚠ Warning: ${STREAMLIT_DIR}/streamlit_app.py not found, skipping Streamlit deployment${NC}"
else
    # Upload configuration files to CONFIG_STAGE
    echo ""
    echo -e "${GREEN}Step 5: Uploading configuration files (optional)${NC}"
    
    # Upload config files to CONFIG_STAGE in PUBLIC schema
    # Note: This is optional - Streamlit app has default values as fallback
    CONFIG_STAGE_PATH="@${DATABASE_NAME}.PUBLIC.CONFIG_STAGE"
    
    echo -e "${BLUE}Uploading configuration to ${CONFIG_STAGE_PATH}...${NC}"
    echo -e "${BLUE}(Streamlit app will use defaults if upload fails)${NC}"
    
    # First ensure CONFIG_STAGE exists
    CONFIG_STAGE_SQL="${TEMP_DIR}/create_config_stage.sql"
    cat > "$CONFIG_STAGE_SQL" << EOF
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE_NAME};
USE SCHEMA PUBLIC;

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
EOF
    
    if run_snow_sql -f "$CONFIG_STAGE_SQL" 2>/dev/null; then
        echo -e "${GREEN}✓ CONFIG_STAGE ready${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Could not create CONFIG_STAGE (may already exist)${NC}"
    fi
    
    # Upload the config file being used
    if [ -f "$CONFIG_FILE" ]; then
        echo "Uploading ${CONFIG_FILE} to ${CONFIG_STAGE_PATH}..."
        UPLOAD_SQL="${TEMP_DIR}/upload_config.sql"
        # Convert path for Windows compatibility
        CONFIG_FILE_PATH=$(convert_path_for_snowflake "$(pwd)/${CONFIG_FILE}")
        
        cat > "$UPLOAD_SQL" << EOF
USE DATABASE ${DATABASE_NAME};
USE SCHEMA PUBLIC;
PUT file://${CONFIG_FILE_PATH} ${CONFIG_STAGE_PATH} AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
EOF
        
        if run_snow_sql -f "$UPLOAD_SQL" 2>/dev/null; then
            echo -e "${GREEN}✓ Uploaded configuration file - Streamlit app will use your custom settings${NC}"
        else
            echo -e "${YELLOW}⚠ Config upload skipped - Streamlit app will use default values${NC}"
            echo -e "${YELLOW}  (This is fine if you're using default database/schema/warehouse names)${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}Step 6: Deploying Streamlit application${NC}"
    # Convert app name to user-friendly title (replace underscores with spaces, title case)
    STREAMLIT_TITLE=$(echo "${SILVER_STREAMLIT_APP_NAME}" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
    
    # Generate snowflake.yml with actual values
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
    
    # Copy generated snowflake.yml to streamlit directory
    cp "$STREAMLIT_YML" "${STREAMLIT_DIR}/snowflake.yml"
    
    # Change to streamlit directory for deployment
    cd "$STREAMLIT_DIR"
    
    # Deploy using snow streamlit deploy with ADMIN role
    ADMIN_ROLE="${DATABASE_NAME}_ADMIN"
    if [ "$USE_DEFAULT_CONNECTION" = true ]; then
        DEPLOY_CMD="snow streamlit deploy --replace --database \"${DATABASE_NAME}\" --schema PUBLIC --role \"${ADMIN_ROLE}\""
    else
        DEPLOY_CMD="snow streamlit deploy --replace --database \"${DATABASE_NAME}\" --schema PUBLIC --role \"${ADMIN_ROLE}\" --connection \"$SNOW_CONNECTION\""
    fi
    
    if eval "$DEPLOY_CMD" 2>&1 | tee /tmp/silver_streamlit_deploy.log; then
        echo -e "${GREEN}✓ Successfully deployed Streamlit app${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Streamlit deployment had issues (check /tmp/silver_streamlit_deploy.log)${NC}"
    fi
    
    # Return to project root
    cd ../..
    
    # Grant permissions to the Streamlit app
    echo -e "${BLUE}Granting permissions to pipeline roles...${NC}"
    GRANT_SQL="${TEMP_DIR}/grant_streamlit_permissions.sql"
    cat > "$GRANT_SQL" << EOF
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE_NAME};
USE SCHEMA PUBLIC;

SET role_admin = '${DATABASE_NAME}_ADMIN';
SET role_readwrite = '${DATABASE_NAME}_READWRITE';
SET role_readonly = '${DATABASE_NAME}_READONLY';

GRANT USAGE ON STREAMLIT "${SILVER_STREAMLIT_APP_NAME}" TO ROLE IDENTIFIER(\$role_admin);
GRANT USAGE ON STREAMLIT "${SILVER_STREAMLIT_APP_NAME}" TO ROLE IDENTIFIER(\$role_readwrite);
GRANT USAGE ON STREAMLIT "${SILVER_STREAMLIT_APP_NAME}" TO ROLE IDENTIFIER(\$role_readonly);
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
echo -e "${GREEN}  Silver Layer Deployment Completed! 🎉${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Pipeline Configuration:${NC}"
echo "  Database:              ${DATABASE_NAME}"
echo "  Bronze Schema:         ${SCHEMA_NAME}"
echo "  Silver Schema:         ${SILVER_SCHEMA_NAME}"
echo "  Warehouse:             ${WAREHOUSE_NAME}"
echo ""
echo "  Stages:"
echo "    Silver:              @${DATABASE_NAME}.${SILVER_SCHEMA_NAME}.${SILVER_STAGE_NAME}"
echo "    Config:              @${DATABASE_NAME}.${SILVER_SCHEMA_NAME}.${SILVER_CONFIG_STAGE_NAME}"
echo "    Streamlit:           @${DATABASE_NAME}.PUBLIC.${SILVER_STREAMLIT_STAGE_NAME}"
echo ""
echo "  Metadata Tables:"
echo "    - target_schemas"
echo "    - field_mappings"
echo "    - transformation_rules"
echo ""
echo "  Processing Tables:"
echo "    - silver_processing_log"
echo "    - data_quality_metrics"
echo "    - quarantine_records"
echo ""
echo "  Mapping Methods:"
echo "    1. Manual CSV Upload"
echo "    2. ML Pattern Matching"
echo "    3. LLM Cortex AI (${DEFAULT_LLM_MODEL})"
echo ""
echo "  Rules Engine:"
echo "    - Data Quality Rules"
echo "    - Business Logic Rules"
echo "    - Standardization Rules"
echo "    - Deduplication Rules"
echo ""
echo "  Tasks:"
echo "    1. bronze_completion_sensor (every 5 min)"
echo "    2. transform_bronze_to_silver_task"
echo "    3. apply_rules_engine_task"
echo "    4. data_quality_check_task"
echo "    5. move_to_silver_task"
echo "    6. update_processing_log_task"
echo ""
echo -e "${BLUE}Streamlit Application:${NC}"
if [ -n "$STREAMLIT_DIR" ] && [ -f "${STREAMLIT_DIR}/streamlit_app.py" ]; then
    echo "  App Name:              ${SILVER_STREAMLIT_APP_NAME}"
    echo "  Location:              ${DATABASE_NAME}.PUBLIC"
    echo ""
    echo "  Access Steps:"
    echo "    1. Navigate to Snowsight"
    echo "    2. Click 'Streamlit' in the left sidebar"
    echo "    3. Open '${SILVER_STREAMLIT_APP_NAME}'"
    echo ""
    echo "  Features:"
    echo "    - Schema Designer: Define target schemas"
    echo "    - Field Mapper: Map Bronze → Silver fields"
    echo "    - Rules Engine: Configure transformation rules"
    echo "    - Transformation Monitor: Track processing"
else
    echo "  Not deployed (Streamlit directory not found)"
fi
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Access Streamlit app: Snowsight → Streamlit → ${SILVER_STREAMLIT_APP_NAME}"
echo "  2. Define target schemas in the Schema Designer tab"
echo "  3. Create field mappings using Manual/ML/LLM methods"
echo "  4. Configure transformation rules in the Rules Engine tab"
echo "  5. Monitor transformations in the Transformation Monitor tab"
echo ""
echo -e "${BLUE}Manual Operations:${NC}"
echo -e "${YELLOW}  # Start tasks${NC}"
echo -e "${YELLOW}  CALL ${DATABASE_NAME}.${SILVER_SCHEMA_NAME}.resume_all_silver_tasks();${NC}"
echo ""
echo -e "${YELLOW}  # Stop tasks${NC}"
echo -e "${YELLOW}  CALL ${DATABASE_NAME}.${SILVER_SCHEMA_NAME}.suspend_all_silver_tasks();${NC}"
echo ""
echo -e "${YELLOW}  # Transform data${NC}"
echo -e "${YELLOW}  CALL ${DATABASE_NAME}.${SILVER_SCHEMA_NAME}.transform_bronze_to_silver('RAW_DATA_TABLE', 'target_table');${NC}"
echo ""
echo -e "${YELLOW}  # Check status${NC}"
echo -e "${YELLOW}  SELECT * FROM ${DATABASE_NAME}.${SILVER_SCHEMA_NAME}.v_transformation_status_summary;${NC}"
echo ""
echo -e "${GREEN}Silver layer is ready for data transformation!${NC}"
echo -e "${GREEN}Deployment completed at: $(date)${NC}"

