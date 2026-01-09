#!/bin/bash

# ============================================
# UNDEPLOY SCRIPT: Complete Cleanup
# ============================================
# Purpose: Removes all deployed components including:
#   - Streamlit application
#   - Database and all schemas/tables/stages
#   - Custom roles
# WARNING: This will permanently delete all data!
# ============================================

set -e  # Exit on error

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

# Check if USE_DEFAULT_CLI_CONNECTION is set
if [ "${USE_DEFAULT_CLI_CONNECTION}" = true ]; then
    USE_DEFAULT_CONNECTION=true
    echo "Using default Snowflake CLI connection"
else
    USE_DEFAULT_CONNECTION=false
fi

# Function to run snow SQL commands
run_snow_sql() {
    local sql_file=$1
    if [ "$USE_DEFAULT_CONNECTION" = true ]; then
        snow sql -f "$sql_file"
    else
        snow sql -f "$sql_file" --connection "$SNOW_CONNECTION"
    fi
}

# If not using default, select connection
if [ "$USE_DEFAULT_CONNECTION" = false ]; then
    # List available connections
    echo "Available Snowflake CLI connections:"
    CONNECTIONS_JSON=$(snow connection list --format json 2>/dev/null || echo "[]")
    
    if [ "$CONNECTIONS_JSON" = "[]" ]; then
        echo -e "${RED}No Snowflake CLI connections found. Please run 'snow connection add' first.${NC}"
        exit 1
    fi
    
    # Parse connection names
    CONNECTIONS=$(echo "$CONNECTIONS_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for conn in data:
        # Handle both 'connection_name' and 'name' keys
        name = conn.get('connection_name') or conn.get('name')
        if name:
            print(name)
except:
    pass
" 2>/dev/null)
    
    if [ -z "$CONNECTIONS" ]; then
        echo -e "${RED}Could not parse connections. Please check your Snowflake CLI setup.${NC}"
        exit 1
    fi
    
    # Count connections
    CONNECTION_COUNT=$(echo "$CONNECTIONS" | wc -l | tr -d ' ')
    
    if [ "$CONNECTION_COUNT" -eq 1 ]; then
        SNOW_CONNECTION="$CONNECTIONS"
        echo "Using connection: $SNOW_CONNECTION"
    else
        echo "$CONNECTIONS" | nl
        echo ""
        read -p "Select connection number: " CONN_NUM
        SNOW_CONNECTION=$(echo "$CONNECTIONS" | sed -n "${CONN_NUM}p")
        
        if [ -z "$SNOW_CONNECTION" ]; then
            echo -e "${RED}Invalid selection${NC}"
            exit 1
        fi
        
        echo "Selected connection: $SNOW_CONNECTION"
    fi
fi

echo ""

# ============================================
# PERMISSION CHECKS
# ============================================
echo -e "${BLUE}Step 2: Checking permissions${NC}"

# Temporarily disable exit on error for permission checks
set +e

# Check SYSADMIN
SYSADMIN_CHECK=$(snow sql -q "USE ROLE SYSADMIN; SELECT 'OK' as result;" --format json 2>&1)
if echo "$SYSADMIN_CHECK" | grep -q "OK"; then
    echo -e "${GREEN}✓ SYSADMIN role available${NC}"
else
    echo -e "${RED}✗ SYSADMIN role not available${NC}"
    echo "This script requires SYSADMIN privileges."
    exit 1
fi

# Check SECURITYADMIN
SECURITYADMIN_CHECK=$(snow sql -q "USE ROLE SECURITYADMIN; SELECT 'OK' as result;" --format json 2>&1)
if echo "$SECURITYADMIN_CHECK" | grep -q "OK"; then
    echo -e "${GREEN}✓ SECURITYADMIN role available${NC}"
else
    echo -e "${RED}✗ SECURITYADMIN role not available${NC}"
    echo "This script requires SECURITYADMIN privileges."
    exit 1
fi

# Check ACCOUNTADMIN (for Streamlit)
ACCOUNTADMIN_CHECK=$(snow sql -q "USE ROLE ACCOUNTADMIN; SELECT 'OK' as result;" --format json 2>&1)
if echo "$ACCOUNTADMIN_CHECK" | grep -q "OK"; then
    echo -e "${GREEN}✓ ACCOUNTADMIN role available${NC}"
    HAS_ACCOUNTADMIN=true
else
    echo -e "${YELLOW}⚠ ACCOUNTADMIN role not available (Streamlit removal may fail)${NC}"
    HAS_ACCOUNTADMIN=false
fi

# Re-enable exit on error
set -e

echo ""

# ============================================
# CREATE TEMPORARY DIRECTORY
# ============================================
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"
echo ""

# ============================================
# REMOVE STREAMLIT APP
# ============================================
echo -e "${BLUE}Step 3: Removing Streamlit application${NC}"

if [ "$HAS_ACCOUNTADMIN" = true ]; then
    STREAMLIT_DROP_SQL="${TEMP_DIR}/drop_streamlit.sql"
    cat > "$STREAMLIT_DROP_SQL" << EOF
USE ROLE ACCOUNTADMIN;
DROP STREAMLIT IF EXISTS ${DATABASE_NAME}.PUBLIC.${STREAMLIT_APP_NAME};
EOF
    
    if run_snow_sql "$STREAMLIT_DROP_SQL" 2>&1 | tee /tmp/streamlit_drop.log; then
        echo -e "${GREEN}✓ Streamlit app removed${NC}"
    else
        echo -e "${YELLOW}⚠ Could not remove Streamlit app (may not exist)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipping Streamlit removal (ACCOUNTADMIN required)${NC}"
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

