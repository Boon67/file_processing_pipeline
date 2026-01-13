#!/bin/bash

# ============================================
# UNDEPLOY SCRIPT: Complete Cleanup
# ============================================
# Purpose: Removes all deployed components including:
#   - Streamlit application
#   - Database and all schemas/tables/stages
#   - Custom roles
# WARNING: This will permanently delete all data!
#
# Prerequisites:
#   - Snowflake CLI (snow) installed and configured
#   - Connection must have SYSADMIN and SECURITYADMIN permissions
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
    PYTHON_CMD="python"  # Will fail later if not found
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# BANNER
# ============================================
echo -e "${RED}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              ⚠️  UNDEPLOY BRONZE PIPELINE  ⚠️                ║
║                                                              ║
║  This script will PERMANENTLY DELETE:                        ║
║    • Streamlit Application                                   ║
║    • Database and ALL data                                   ║
║    • All stages and files                                    ║
║    • Custom roles                                            ║
║                                                              ║
║  THIS CANNOT BE UNDONE!                                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ============================================
# LOAD CONFIGURATION
# ============================================
echo -e "${BLUE}Loading configuration...${NC}"

# Check for custom config first, then default
if [ -f "custom.config" ]; then
    echo -e "${GREEN}Loading custom.config${NC}"
    source custom.config
elif [ -f "default.config" ]; then
    echo -e "${GREEN}Loading default.config${NC}"
    source default.config
else
    echo -e "${RED}Error: No configuration file found!${NC}"
    echo "Please ensure default.config or custom.config exists."
    exit 1
fi

# Display configuration
echo ""
echo -e "${YELLOW}Configuration loaded:${NC}"
echo "  Database: ${DATABASE_NAME}"
echo "  Schema: ${SCHEMA_NAME}"
echo "  Streamlit App: ${STREAMLIT_APP_NAME}"
echo ""

# ============================================
# CONFIRMATION
# ============================================
echo -e "${RED}⚠️  WARNING: This will permanently delete ALL data!${NC}"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Undeploy cancelled.${NC}"
    exit 0
fi

echo ""
read -p "Type the database name '${DATABASE_NAME}' to confirm: " CONFIRM_DB

if [ "$CONFIRM_DB" != "$DATABASE_NAME" ]; then
    echo -e "${RED}Database name does not match. Undeploy cancelled.${NC}"
    exit 1
fi

echo ""
echo -e "${RED}Starting undeploy process...${NC}"
echo ""

# ============================================
# SNOWFLAKE CONNECTION SETUP
# ============================================
echo -e "${BLUE}Step 1: Setting up Snowflake connection${NC}"

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
    if [ "${USE_DEFAULT_CLI_CONNECTION:-false}" = "true" ] && [ -n "$DEFAULT_CONN" ]; then
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
    local sql_file=$1
    if [ "$USE_DEFAULT_CONNECTION" = true ]; then
        snow sql -f "$sql_file"
    else
        snow sql --connection "$SNOW_CONNECTION" -f "$sql_file"
    fi
}

if [ "$USE_DEFAULT_CONNECTION" = true ]; then
    echo -e "${GREEN}✓ Connected to Snowflake (using default connection)${NC}"
else
    echo -e "${GREEN}✓ Connected to Snowflake (connection: ${SNOW_CONNECTION})${NC}"
fi
echo ""

# ============================================
# PERMISSION CHECKS
# ============================================
echo -e "${BLUE}Step 2: Checking required permissions${NC}"

# Temporarily disable exit on error for role checks
set +e

# Helper function to run snow sql with or without connection parameter
run_snow_sql_check() {
    if [ "$USE_DEFAULT_CONNECTION" = true ]; then
        snow sql "$@"
    else
        snow sql --connection "$SNOW_CONNECTION" "$@"
    fi
}

# Create temporary file for role checks
TEMP_CHECK=$(mktemp)

# Test SYSADMIN access
cat > "$TEMP_CHECK" << 'EOF'
USE ROLE SYSADMIN;
SELECT 'SYSADMIN_OK' as result;
EOF

SYSADMIN_RESULT=$(run_snow_sql_check -f "$TEMP_CHECK" 2>&1)
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

SECURITYADMIN_RESULT=$(run_snow_sql_check -f "$TEMP_CHECK" 2>&1)
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

# Check if user has required roles
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
    echo -e "${YELLOW}This script requires both SYSADMIN and SECURITYADMIN roles to:${NC}"
    echo "  - Drop database objects (SYSADMIN)"
    echo "  - Drop custom roles (SECURITYADMIN)"
    echo ""
    echo -e "${YELLOW}Please have your Snowflake administrator grant the missing role(s):${NC}"
    for role in "${MISSING_ROLES[@]}"; do
        echo -e "${YELLOW}  GRANT ROLE ${role} TO USER $(whoami);${NC}"
    done
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ All required roles available - proceeding with undeploy${NC}"
echo ""

# ============================================
# CREATE TEMPORARY DIRECTORY
# ============================================
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"
echo ""

# ============================================
# REMOVE STREAMLIT APPS
# ============================================
echo -e "${BLUE}Step 3: Removing Streamlit applications${NC}"

# Use SYSADMIN with the custom ADMIN role to drop Streamlit apps
STREAMLIT_DROP_SQL="${TEMP_DIR}/drop_streamlit.sql"
ADMIN_ROLE="${DATABASE_NAME}_ADMIN"

cat > "$STREAMLIT_DROP_SQL" << EOF
-- Use SYSADMIN to switch to the custom ADMIN role
USE ROLE SYSADMIN;

-- Switch to the database ADMIN role (which owns the Streamlit apps)
USE ROLE IDENTIFIER('${ADMIN_ROLE}');
USE DATABASE ${DATABASE_NAME};
USE SCHEMA PUBLIC;

-- Drop Bronze Streamlit app (if exists)
DROP STREAMLIT IF EXISTS ${STREAMLIT_APP_NAME};

-- Drop Silver Streamlit app (if exists)
DROP STREAMLIT IF EXISTS ${SILVER_STREAMLIT_APP_NAME:-SILVER_TRANSFORMATION_MANAGER};
EOF

if run_snow_sql "$STREAMLIT_DROP_SQL" 2>&1 | tee /tmp/streamlit_drop.log; then
    echo -e "${GREEN}✓ Streamlit apps removed${NC}"
else
    echo -e "${YELLOW}⚠ Could not remove Streamlit apps (may not exist or role may not have access)${NC}"
fi

echo ""

# ============================================
# SUSPEND AND DROP TASKS
# ============================================
echo -e "${BLUE}Step 4: Suspending and dropping tasks${NC}"

TASKS_DROP_SQL="${TEMP_DIR}/drop_tasks.sql"
cat > "$TASKS_DROP_SQL" << EOF
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

-- Suspend all tasks first
ALTER TASK IF EXISTS ${ARCHIVE_TASK_NAME} SUSPEND;
ALTER TASK IF EXISTS ${MOVE_FAILED_TASK_NAME} SUSPEND;
ALTER TASK IF EXISTS ${MOVE_SUCCESS_TASK_NAME} SUSPEND;
ALTER TASK IF EXISTS ${PROCESS_TASK_NAME} SUSPEND;
ALTER TASK IF EXISTS ${DISCOVER_TASK_NAME} SUSPEND;

-- Drop tasks in reverse dependency order
DROP TASK IF EXISTS ${ARCHIVE_TASK_NAME};
DROP TASK IF EXISTS ${MOVE_FAILED_TASK_NAME};
DROP TASK IF EXISTS ${MOVE_SUCCESS_TASK_NAME};
DROP TASK IF EXISTS ${PROCESS_TASK_NAME};
DROP TASK IF EXISTS ${DISCOVER_TASK_NAME};
EOF

if run_snow_sql "$TASKS_DROP_SQL" 2>&1 | tee /tmp/tasks_drop.log; then
    echo -e "${GREEN}✓ Tasks suspended and dropped${NC}"
else
    echo -e "${YELLOW}⚠ Some tasks may not have been dropped (may not exist)${NC}"
fi

echo ""

# ============================================
# DROP DATABASE
# ============================================
echo -e "${BLUE}Step 5: Dropping database${NC}"

DATABASE_DROP_SQL="${TEMP_DIR}/drop_database.sql"
cat > "$DATABASE_DROP_SQL" << EOF
USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS ${DATABASE_NAME};
EOF

if run_snow_sql "$DATABASE_DROP_SQL" 2>&1 | tee /tmp/database_drop.log; then
    echo -e "${GREEN}✓ Database dropped: ${DATABASE_NAME}${NC}"
else
    echo -e "${RED}✗ Failed to drop database${NC}"
    exit 1
fi

echo ""

# ============================================
# DROP ROLES
# ============================================
echo -e "${BLUE}Step 6: Dropping custom roles${NC}"

ROLES_DROP_SQL="${TEMP_DIR}/drop_roles.sql"
cat > "$ROLES_DROP_SQL" << EOF
USE ROLE SECURITYADMIN;

-- Drop roles
DROP ROLE IF EXISTS ${DATABASE_NAME}_ADMIN;
DROP ROLE IF EXISTS ${DATABASE_NAME}_READWRITE;
DROP ROLE IF EXISTS ${DATABASE_NAME}_READONLY;
EOF

if run_snow_sql "$ROLES_DROP_SQL" 2>&1 | tee /tmp/roles_drop.log; then
    echo -e "${GREEN}✓ Custom roles dropped${NC}"
else
    echo -e "${RED}✗ Failed to drop roles${NC}"
    exit 1
fi

echo ""

# ============================================
# CLEANUP
# ============================================
echo -e "${BLUE}Step 7: Cleaning up temporary files${NC}"
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✓ Temporary files cleaned up${NC}"

echo ""

# ============================================
# COMPLETION
# ============================================
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              ✅  UNDEPLOY COMPLETE  ✅                        ║
║                                                              ║
║  All components have been removed:                           ║
║    ✓ Streamlit Application                                   ║
║    ✓ Database and all data                                   ║
║    ✓ All stages and files                                    ║
║    ✓ Custom roles                                            ║
║                                                              ║
║  The environment has been completely cleaned up.             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  • Database '${DATABASE_NAME}' - REMOVED"
echo "  • Streamlit app '${STREAMLIT_APP_NAME}' - REMOVED"
echo "  • Custom roles - REMOVED"
echo "  • All data and configurations - REMOVED"
echo ""
echo -e "${GREEN}You can now run deploy.sh to reinstall if needed.${NC}"
echo ""

