#!/bin/bash

# ============================================
# SNOWFLAKE FILE PROCESSING PIPELINE - MASTER DEPLOYMENT
# ============================================
# This script deploys the complete solution:
#   1. Bronze Layer (File Ingestion)
#   2. Silver Layer (Data Transformation)
#
# Prerequisites:
#   - Snowflake CLI (snow) installed and configured
#   - Connection must have SYSADMIN and SECURITYADMIN permissions
#
# Usage:
#   ./deploy.sh                    # Deploy both layers with default.config
#   ./deploy.sh custom.config      # Deploy both layers with custom config
#   ./deploy.sh --bronze-only      # Deploy Bronze layer only
#   ./deploy.sh --silver-only      # Deploy Silver layer only
# ============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Parse command line arguments
DEPLOY_BRONZE=true
DEPLOY_SILVER=true
CONFIG_FILE="default.config"

for arg in "$@"; do
    case $arg in
        --bronze-only)
            DEPLOY_SILVER=false
            shift
            ;;
        --silver-only)
            DEPLOY_BRONZE=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [CONFIG_FILE]"
            echo ""
            echo "Options:"
            echo "  --bronze-only    Deploy only the Bronze layer"
            echo "  --silver-only    Deploy only the Silver layer"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Arguments:"
            echo "  CONFIG_FILE      Configuration file (default: default.config)"
            echo ""
            echo "Examples:"
            echo "  $0                        # Deploy both layers with default config"
            echo "  $0 custom.config          # Deploy both layers with custom config"
            echo "  $0 --bronze-only          # Deploy Bronze layer only"
            echo "  $0 --silver-only          # Deploy Silver layer only"
            exit 0
            ;;
        *)
            if [ -f "$arg" ]; then
                CONFIG_FILE="$arg"
            fi
            ;;
    esac
done

# Print banner
clear 2>/dev/null || true
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║   ${MAGENTA}Snowflake File Processing Pipeline - Master Deployment${CYAN}   ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: Configuration file not found: ${CONFIG_FILE}${NC}"
    echo "Please ensure the configuration file exists or run without arguments to use default.config"
    exit 1
fi

echo -e "${BLUE}Configuration: ${CONFIG_FILE}${NC}"
echo ""

# Determine what to deploy
if [ "$DEPLOY_BRONZE" = true ] && [ "$DEPLOY_SILVER" = true ]; then
    echo -e "${GREEN}Deployment Mode: Full Stack (Bronze + Silver)${NC}"
elif [ "$DEPLOY_BRONZE" = true ]; then
    echo -e "${GREEN}Deployment Mode: Bronze Layer Only${NC}"
elif [ "$DEPLOY_SILVER" = true ]; then
    echo -e "${GREEN}Deployment Mode: Silver Layer Only${NC}"
fi
echo ""

# Check if deployment scripts exist
if [ "$DEPLOY_BRONZE" = true ] && [ ! -f "deploy_bronze.sh" ]; then
    echo -e "${RED}ERROR: deploy_bronze.sh not found${NC}"
    exit 1
fi

if [ "$DEPLOY_SILVER" = true ] && [ ! -f "deploy_silver.sh" ]; then
    echo -e "${RED}ERROR: deploy_silver.sh not found${NC}"
    exit 1
fi

# Deployment start time
START_TIME=$(date +%s)

# ============================================
# BRONZE LAYER DEPLOYMENT
# ============================================
if [ "$DEPLOY_BRONZE" = true ]; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}║   ${YELLOW}🥉 BRONZE LAYER - File Ingestion Pipeline${CYAN}                ║${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}Starting Bronze layer deployment...${NC}"
    echo ""
    
    # Run Bronze deployment
    if bash deploy_bronze.sh "$CONFIG_FILE"; then
        echo ""
        echo -e "${GREEN}✓ Bronze layer deployment completed successfully${NC}"
        BRONZE_SUCCESS=true
    else
        echo ""
        echo -e "${RED}✗ Bronze layer deployment failed${NC}"
        BRONZE_SUCCESS=false
        
        # If Bronze fails and Silver is also to be deployed, ask if we should continue
        if [ "$DEPLOY_SILVER" = true ]; then
            echo ""
            echo -e "${YELLOW}Bronze layer deployment failed.${NC}"
            read -p "Continue with Silver layer deployment? (yes/no): " CONTINUE
            if [[ ! "$CONTINUE" =~ ^[Yy][Ee][Ss]$ ]]; then
                echo -e "${RED}Deployment cancelled.${NC}"
                exit 1
            fi
        else
            exit 1
        fi
    fi
fi

# ============================================
# SILVER LAYER DEPLOYMENT
# ============================================
if [ "$DEPLOY_SILVER" = true ]; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}║   ${YELLOW}🥈 SILVER LAYER - Data Transformation Pipeline${CYAN}           ║${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check if Bronze layer exists (if not deploying Bronze now)
    if [ "$DEPLOY_BRONZE" = false ]; then
        echo -e "${BLUE}Checking Bronze layer prerequisites...${NC}"
        # This check will be done by deploy_silver.sh
    fi
    
    echo -e "${BLUE}Starting Silver layer deployment...${NC}"
    echo ""
    
    # Run Silver deployment
    if bash deploy_silver.sh "$CONFIG_FILE"; then
        echo ""
        echo -e "${GREEN}✓ Silver layer deployment completed successfully${NC}"
        SILVER_SUCCESS=true
    else
        echo ""
        echo -e "${RED}✗ Silver layer deployment failed${NC}"
        SILVER_SUCCESS=false
        exit 1
    fi
fi

# ============================================
# DEPLOYMENT SUMMARY
# ============================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║   ${GREEN}🎉 DEPLOYMENT SUMMARY${CYAN}                                      ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Bronze summary
if [ "$DEPLOY_BRONZE" = true ]; then
    if [ "$BRONZE_SUCCESS" = true ]; then
        echo -e "${GREEN}✓ Bronze Layer: DEPLOYED${NC}"
        echo "  - Database & Roles created"
        echo "  - 6 Stages configured"
        echo "  - 2 Tables created"
        echo "  - 4 Stored Procedures deployed"
        echo "  - 5 Tasks configured"
        echo "  - Streamlit App deployed"
    else
        echo -e "${RED}✗ Bronze Layer: FAILED${NC}"
    fi
    echo ""
fi

# Silver summary
if [ "$DEPLOY_SILVER" = true ]; then
    if [ "$SILVER_SUCCESS" = true ]; then
        echo -e "${GREEN}✓ Silver Layer: DEPLOYED${NC}"
        echo "  - Silver Schema created"
        echo "  - 3 Stages configured"
        echo "  - 8 Metadata Tables created"
        echo "  - 25+ Stored Procedures deployed"
        echo "  - 6 Tasks configured"
        echo "  - Streamlit App deployed"
        echo "  - Sample configurations loaded"
    else
        echo -e "${RED}✗ Silver Layer: FAILED${NC}"
    fi
    echo ""
fi

# Overall status
if [ "$BRONZE_SUCCESS" = true ] || [ "$SILVER_SUCCESS" = true ]; then
    echo -e "${GREEN}Overall Status: SUCCESS${NC}"
else
    echo -e "${RED}Overall Status: FAILED${NC}"
fi

echo ""
echo -e "${BLUE}Deployment Time: ${MINUTES}m ${SECONDS}s${NC}"
echo -e "${BLUE}Configuration: ${CONFIG_FILE}${NC}"
echo ""

# ============================================
# NEXT STEPS
# ============================================
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║   ${YELLOW}📋 NEXT STEPS${CYAN}                                              ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DEPLOY_BRONZE" = true ] && [ "$BRONZE_SUCCESS" = true ]; then
    echo -e "${GREEN}Bronze Layer:${NC}"
    echo "  1. Access Streamlit app in Snowsight"
    echo "  2. Upload test files to @SRC stage"
    echo "  3. Monitor processing in Streamlit"
    echo "  4. Resume tasks to start automation"
    echo ""
fi

if [ "$DEPLOY_SILVER" = true ] && [ "$SILVER_SUCCESS" = true ]; then
    echo -e "${GREEN}Silver Layer:${NC}"
    echo "  1. Access Silver Streamlit app in Snowsight"
    echo "  2. Define target schemas"
    echo "  3. Configure field mappings (Manual/ML/LLM)"
    echo "  4. Set up transformation rules"
    echo "  5. Resume tasks to start transformation"
    echo ""
fi

echo -e "${BLUE}Documentation:${NC}"
echo "  - Main README: README.md"
echo "  - Bronze Layer: bronze/README.md"
echo "  - Silver Layer: silver/README.md"
echo ""

echo -e "${BLUE}Monitoring:${NC}"
echo "  - Streamlit Apps: Snowsight → Streamlit"
echo "  - Task History: INFORMATION_SCHEMA.TASK_HISTORY()"
echo "  - Processing Logs: Check layer-specific log tables"
echo ""

echo -e "${BLUE}Troubleshooting:${NC}"
echo "  - Bronze Diagnostics: snow sql -f bronze/diagnose_discover_files.sql"
echo "  - Silver Validation: snow sql -f silver/test_silver_deployment.sql"
echo "  - Undeploy: ./undeploy.sh"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}║   Deployment completed at: $(date '+%Y-%m-%d %H:%M:%S')       ${GREEN}║${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Exit with appropriate code
if [ "$BRONZE_SUCCESS" = true ] || [ "$SILVER_SUCCESS" = true ]; then
    exit 0
else
    exit 1
fi
