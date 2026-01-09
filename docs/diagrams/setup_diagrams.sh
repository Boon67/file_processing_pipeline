#!/bin/bash

# Setup Diagrams Script
# Consolidates all diagrams to docs/diagrams/ folder

set -e

echo "================================================"
echo "  Diagram Setup & Generation"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

echo -e "${BLUE}Project root: ${PROJECT_ROOT}${NC}"
echo -e "${BLUE}Diagrams folder: ${SCRIPT_DIR}${NC}"
echo ""

# Step 1: Copy existing Bronze diagram if it exists
echo -e "${BLUE}Step 1: Copying existing Bronze diagram...${NC}"
if [ -f "$PROJECT_ROOT/workflow_diagram_professional.png" ]; then
    cp "$PROJECT_ROOT/workflow_diagram_professional.png" "$SCRIPT_DIR/workflow_diagram_bronze_professional.png"
    echo -e "${GREEN}✓ Bronze diagram copied${NC}"
else
    echo -e "${YELLOW}⚠ Bronze diagram not found at root, will generate${NC}"
fi
echo ""

# Step 2: Check Python and matplotlib
echo -e "${BLUE}Step 2: Checking prerequisites...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}✗ Python 3 not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python 3 found${NC}"

if python3 -c "import matplotlib" 2>/dev/null; then
    echo -e "${GREEN}✓ Matplotlib installed${NC}"
else
    echo -e "${YELLOW}⚠ Matplotlib not installed${NC}"
    echo "  Install with: pip install matplotlib"
    echo ""
    read -p "Install matplotlib now? (y/n): " INSTALL
    if [[ "$INSTALL" =~ ^[Yy]$ ]]; then
        pip install matplotlib
    else
        echo "Skipping diagram generation"
        exit 0
    fi
fi
echo ""

# Step 3: Generate diagrams
echo -e "${BLUE}Step 3: Generating diagrams...${NC}"

# Generate main diagrams (Bronze, overall, structure)
if [ -f "$SCRIPT_DIR/generate_diagrams.py" ]; then
    echo "Generating main diagrams..."
    cd "$SCRIPT_DIR"
    python3 generate_diagrams.py
    echo -e "${GREEN}✓ Main diagrams generated${NC}"
else
    echo -e "${YELLOW}⚠ generate_diagrams.py not found${NC}"
fi

# Generate Silver diagram
if [ -f "$SCRIPT_DIR/generate_silver_diagram.py" ]; then
    echo "Generating Silver diagram..."
    cd "$SCRIPT_DIR"
    python3 generate_silver_diagram.py
    echo -e "${GREEN}✓ Silver diagram generated${NC}"
else
    echo -e "${YELLOW}⚠ generate_silver_diagram.py not found${NC}"
fi
echo ""

# Step 4: List generated diagrams
echo -e "${BLUE}Step 4: Generated diagrams:${NC}"
cd "$SCRIPT_DIR"
for file in *.png; do
    if [ -f "$file" ]; then
        SIZE=$(ls -lh "$file" | awk '{print $5}')
        echo -e "${GREEN}  ✓ $file${NC} (${SIZE})"
    fi
done
echo ""

# Step 5: Verify README references
echo -e "${BLUE}Step 5: Verifying README references...${NC}"
if grep -q "docs/diagrams/workflow_diagram_bronze_professional.png" "$PROJECT_ROOT/README.md"; then
    echo -e "${GREEN}✓ Bronze diagram referenced in README${NC}"
else
    echo -e "${YELLOW}⚠ Bronze diagram not referenced in README${NC}"
fi

if grep -q "docs/diagrams/workflow_diagram_silver_professional.png" "$PROJECT_ROOT/README.md"; then
    echo -e "${GREEN}✓ Silver diagram referenced in README${NC}"
else
    echo -e "${YELLOW}⚠ Silver diagram not referenced in README${NC}"
fi
echo ""

echo "================================================"
echo -e "${GREEN}  Diagram setup complete!${NC}"
echo "================================================"
echo ""
echo "Diagrams location: $SCRIPT_DIR"
echo ""
echo "View diagrams:"
echo "  - Bronze: open $SCRIPT_DIR/workflow_diagram_bronze_professional.png"
echo "  - Silver: open $SCRIPT_DIR/workflow_diagram_silver_professional.png"
echo ""
echo "Documentation:"
echo "  - Diagram Index: $SCRIPT_DIR/DIAGRAMS_INDEX.md"
echo "  - Diagram README: $SCRIPT_DIR/README.md"
echo ""

