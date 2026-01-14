#!/bin/bash

# Validation script to check project structure before deployment

echo "=== Validating Project Structure ==="
echo ""

ERRORS=0

# Check Bronze SQL files
echo "Checking Bronze layer files..."
for file in "bronze/1_Setup_Database_Roles.sql" \
            "bronze/2_Bronze_Schema_Tables.sql" \
            "bronze/3_Bronze_Setup_Logic.sql" \
            "bronze/4_Bronze_Tasks.sql"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file - MISSING"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "Checking Bronze Streamlit files..."
for file in "bronze/bronze_streamlit/streamlit_app.py" \
            "bronze/bronze_streamlit/environment.yml" \
            "bronze/bronze_streamlit/snowflake.yml" \
            "bronze/bronze_streamlit/deploy_streamlit.sql" \
            "bronze/bronze_streamlit/README.md" \
            "bronze/bronze_streamlit/DEPLOYMENT.md"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file - MISSING"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "Checking deployment scripts..."
for file in "deploy.sh" \
            "undeploy.sh" \
            "default.config"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file - MISSING"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "Checking for old streamlit folder (should NOT exist)..."
if [ -d "streamlit" ] && [ -f "streamlit/streamlit_app.py" ]; then
    echo "  ✗ Old streamlit/ folder still exists - SHOULD BE REMOVED"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✓ Old streamlit/ folder properly removed"
fi

echo ""
echo "=== Validation Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo "✓ All checks passed! Structure is valid."
    exit 0
else
    echo "✗ Found $ERRORS error(s). Please fix before deploying."
    exit 1
fi

