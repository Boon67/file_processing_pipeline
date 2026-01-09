#!/bin/bash

# ============================================
# Deployment Test Script
# ============================================
# This script validates the deployment without actually deploying
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Deployment Pre-Flight Validation                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0

# Check 1: Configuration file exists
echo -e "${BLUE}[1/10] Checking configuration file...${NC}"
if [ -f "default.config" ]; then
    echo -e "${GREEN}✓ default.config found${NC}"
else
    echo -e "${RED}✗ default.config not found${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 2: Main deployment scripts exist
echo -e "${BLUE}[2/10] Checking deployment scripts...${NC}"
for script in deploy.sh deploy_bronze.sh deploy_silver.sh; do
    if [ -f "$script" ]; then
        echo -e "${GREEN}✓ $script found${NC}"
    else
        echo -e "${RED}✗ $script not found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Check 3: Bronze SQL files exist
echo -e "${BLUE}[3/10] Checking Bronze SQL files...${NC}"
BRONZE_SQL_FILES=(
    "bronze/1_Setup_Database_Roles.sql"
    "bronze/2_Bronze_Schema_Tables.sql"
    "bronze/3_Bronze_Setup_Logic.sql"
    "bronze/4_Bronze_Tasks.sql"
)

for file in "${BRONZE_SQL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $(basename $file)${NC}"
    else
        echo -e "${RED}✗ $file not found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Check 4: Silver SQL files exist
echo -e "${BLUE}[4/10] Checking Silver SQL files...${NC}"
SILVER_SQL_FILES=(
    "silver/1_Silver_Schema_Setup.sql"
    "silver/2_Silver_Target_Schemas.sql"
    "silver/3_Silver_Mapping_Procedures.sql"
    "silver/4_Silver_Rules_Engine.sql"
    "silver/5_Silver_Transformation_Logic.sql"
    "silver/6_Silver_Tasks.sql"
    "silver/7_Silver_Standard_Metadata_Columns.sql"
)

for file in "${SILVER_SQL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $(basename $file)${NC}"
    else
        echo -e "${RED}✗ $file not found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Check 5: Silver config CSV files exist
echo -e "${BLUE}[5/10] Checking Silver configuration CSV files...${NC}"
CSV_FILES=(
    "silver/mappings/target_tables.csv"
    "silver/mappings/field_mappings.csv"
    "silver/mappings/transformation_rules.csv"
)

for file in "${CSV_FILES[@]}"; do
    if [ -f "$file" ]; then
        LINES=$(wc -l < "$file" | tr -d ' ')
        echo -e "${GREEN}✓ $(basename $file) ($LINES lines)${NC}"
    else
        echo -e "${RED}✗ $file not found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Check 6: Bronze Streamlit app exists
echo -e "${BLUE}[6/10] Checking Bronze Streamlit application...${NC}"
if [ -f "bronze/bronze_streamlit/streamlit_app.py" ]; then
    echo -e "${GREEN}✓ Bronze Streamlit app found${NC}"
else
    echo -e "${RED}✗ Bronze Streamlit app not found${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 7: Silver Streamlit app exists
echo -e "${BLUE}[7/10] Checking Silver Streamlit application...${NC}"
if [ -f "silver/silver_streamlit/streamlit_app.py" ]; then
    echo -e "${GREEN}✓ Silver Streamlit app found${NC}"
else
    echo -e "${RED}✗ Silver Streamlit app not found${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 8: Verify no references to deleted files
echo -e "${BLUE}[8/10] Checking for references to deleted files...${NC}"
DELETED_REFS=$(grep -r "5_Silver_Transformation_Views\|4_Silver_Rules_Views\|6_Silver_Tasks_Enhanced" deploy*.sh 2>/dev/null || true)
if [ -z "$DELETED_REFS" ]; then
    echo -e "${GREEN}✓ No references to deleted files${NC}"
else
    echo -e "${RED}✗ Found references to deleted files:${NC}"
    echo "$DELETED_REFS"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 9: Verify CSV files have content
echo -e "${BLUE}[9/10] Validating CSV file content...${NC}"
for file in "${CSV_FILES[@]}"; do
    if [ -f "$file" ]; then
        LINES=$(wc -l < "$file" | tr -d ' ')
        if [ "$LINES" -gt 1 ]; then
            echo -e "${GREEN}✓ $(basename $file) has data ($LINES lines)${NC}"
        else
            echo -e "${YELLOW}⚠ $(basename $file) appears empty${NC}"
        fi
    fi
done
echo ""

# Check 10: Verify Snowflake CLI is installed
echo -e "${BLUE}[10/10] Checking Snowflake CLI...${NC}"
if command -v snow &> /dev/null; then
    SNOW_VERSION=$(snow --version 2>&1 | head -1 || echo "unknown")
    echo -e "${GREEN}✓ Snowflake CLI installed: $SNOW_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ Snowflake CLI not found (required for actual deployment)${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Validation Summary                                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo -e "${GREEN}✓ Ready for deployment${NC}"
    echo ""
    echo -e "${BLUE}To deploy:${NC}"
    echo "  ./deploy.sh                 # Full deployment"
    echo "  ./deploy.sh --bronze-only   # Bronze only"
    echo "  ./deploy.sh --silver-only   # Silver only"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
    echo -e "${RED}✗ Please fix errors before deploying${NC}"
    echo ""
    exit 1
fi
