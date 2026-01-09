# Workflow Diagrams

Professional visual documentation of the Snowflake File Processing Pipeline architecture.

## Available Diagrams

### 1. Bronze Layer Workflow
**File**: `workflow_diagram_bronze_professional.png`

**Shows**:
- File ingestion process
- Task automation pipeline (5 tasks)
- Stage management (SRC, COMPLETED, ERROR, ARCHIVE)
- Streamlit UI integration
- File processing procedures (CSV/Excel)
- Error handling and archival

**Key Components**:
- User interface
- @SRC Stage (landing zone)
- discover_files_task (every 60 min)
- process_files_task
- move_successful_files_task
- move_failed_files_task
- archive_old_files_task (30-day retention)
- RAW_DATA_TABLE (VARIANT storage)
- file_processing_queue (status tracking)

---

### 2. Silver Layer Workflow
**File**: `workflow_diagram_silver_professional.png`

**Shows**:
- Data transformation pipeline
- Metadata-driven architecture
- 3 field mapping methods (Manual/ML/LLM)
- 4-stage rules engine
- Quality validation and quarantine
- Task automation (6 tasks)
- Incremental loading with watermarks

**Key Components**:
- Metadata Layer:
  - TARGET_SCHEMAS (table definitions)
  - FIELD_MAPPINGS (Bronze → Silver mappings)
  - TRANSFORMATION_RULES (DQ/BL/STD/DD rules)
- Mapping Engine:
  - Manual CSV upload (confidence: 1.0)
  - ML pattern matching (confidence: 0.6-0.95)
  - LLM Cortex AI (confidence: 0.7-1.0)
- Rules Engine:
  - Data Quality rules
  - Business Logic rules
  - Standardization rules
  - Deduplication rules
- Task Pipeline:
  - bronze_completion_sensor (every 5 min)
  - silver_discovery_task
  - silver_transformation_task
  - silver_quality_check_task
  - silver_publish_task
  - silver_quarantine_task
- Quality Management:
  - DATA_QUALITY_METRICS
  - QUARANTINE_RECORDS
  - Processing watermarks

---

## Generating Diagrams

### Prerequisites
```bash
pip install matplotlib
```

### Generate All Diagrams
```bash
cd docs/diagrams
python3 generate_diagrams.py
```

This will create:
- Bronze architecture diagram
- Silver architecture diagram
- Overall data flow diagram
- Project structure diagram

### Generate Individual Diagrams

**Bronze Layer Only**:
```bash
python3 generate_diagrams.py  # Bronze included in main script
```

**Silver Layer Only**:
```bash
python3 generate_silver_diagram.py
```

---

## Diagram Features

### Professional Quality
- **High Resolution**: 300 DPI for print quality
- **Color Coded**: Consistent color scheme across all diagrams
- **Clear Labels**: Descriptive text for all components
- **Arrows**: Show data flow and dependencies
- **Legends**: Component type identification

### Color Scheme
| Component Type | Color |
|----------------|-------|
| User Interface | Light Indigo |
| Streamlit App | Light Blue |
| Snowflake Stage | Light Yellow |
| Snowflake Task | Light Green |
| Stored Procedure | Light Blue |
| Data Table | Light Pink |
| Metadata Table | Light Purple |
| Mapping Engine | Light Orange |
| Rules Engine | Light Lime |
| Quality Check | Light Teal |

---

## Usage in Documentation

### Markdown
```markdown
![Bronze Layer Workflow](docs/diagrams/workflow_diagram_bronze_professional.png)
![Silver Layer Workflow](docs/diagrams/workflow_diagram_silver_professional.png)
```

### HTML
```html
<img src="docs/diagrams/workflow_diagram_bronze_professional.png" alt="Bronze Layer" width="800">
<img src="docs/diagrams/workflow_diagram_silver_professional.png" alt="Silver Layer" width="800">
```

### Presentations
- Use PNG files directly in PowerPoint, Keynote, Google Slides
- High DPI ensures clarity at any size
- Professional appearance for stakeholder presentations

---

## Customization

### Modify Colors
Edit the `colors` dictionary in the Python scripts:
```python
colors = {
    'user': '#E8EAF6',
    'streamlit': '#B3E5FC',
    'stage': '#FFF9C4',
    # ... etc
}
```

### Adjust Layout
Modify coordinates in `create_box()` and `create_arrow()` calls:
```python
create_box(ax, x, y, width, height, text, color)
create_arrow(ax, x1, y1, x2, y2, label, color)
```

### Change Resolution
Modify the `dpi` parameter in `plt.savefig()`:
```python
plt.savefig('diagram.png', dpi=300)  # Higher = better quality, larger file
```

---

## Diagram Maintenance

### When to Update

1. **Architecture Changes**
   - New tasks added
   - New procedures created
   - Schema modifications
   - Stage additions

2. **Feature Additions**
   - New mapping methods
   - New rule types
   - New quality checks
   - New integrations

3. **Process Changes**
   - Task dependencies modified
   - Data flow altered
   - Error handling updated

### Update Process

1. Edit the Python script
2. Regenerate the diagram
3. Verify visual quality
4. Update documentation references
5. Commit to version control

---

## File Locations

```
docs/diagrams/
├── README.md                                    # This file
├── generate_diagrams.py                         # Main diagram generator
├── generate_silver_diagram.py                   # Silver-specific generator
├── workflow_diagram_bronze_professional.png     # Bronze layer diagram
├── workflow_diagram_silver_professional.png     # Silver layer diagram
└── [other generated diagrams]
```

---

## Troubleshooting

### Diagram Not Generating

**Issue**: Script runs but no file created

**Solution**:
```bash
# Check matplotlib installation
python3 -c "import matplotlib; print(matplotlib.__version__)"

# Install if missing
pip install matplotlib

# Run with verbose output
python3 -u generate_silver_diagram.py
```

### Low Quality Output

**Issue**: Diagram appears pixelated

**Solution**:
- Increase DPI in script (e.g., `dpi=600`)
- Use vector format: `plt.savefig('diagram.svg')`

### Layout Issues

**Issue**: Components overlap or misaligned

**Solution**:
- Adjust figure size: `fig, ax = plt.subplots(figsize=(20, 24))`
- Modify component coordinates
- Adjust text sizes

---

## Version History

- **v1.0** (Dec 2024): Initial Bronze layer diagram
- **v2.0** (Dec 2024): Added Silver layer diagram
- **v2.1** (Dec 2024): Consolidated diagrams in docs/diagrams/

---

## Contributing

When adding new diagrams:

1. Follow the existing color scheme
2. Use consistent font sizes
3. Include legends
4. Add descriptive labels
5. Update this README
6. Commit both script and generated PNG

---

## License

These diagrams are part of the Snowflake File Processing Pipeline project and follow the same license as the main project.

## 🎯 Diagram Usage Guide

### For Presentations
1. **Export as PNG**: High DPI (300) for print quality
2. **Export as SVG**: Vector format for scaling
3. **Embed in Slides**: PowerPoint, Keynote, Google Slides
4. **Print Quality**: Suitable for posters and documentation

### For Documentation
1. **Markdown**: Use relative paths
2. **HTML**: Embed with img tags
3. **Wiki**: Upload to project wiki
4. **README**: Include in layer READMEs

### For Training
1. **Onboarding**: Show system overview
2. **Architecture Review**: Explain design decisions
3. **Troubleshooting**: Visual debugging aid
4. **Development**: Reference during coding

## 📐 Diagram Standards

### Naming Convention
```
{layer}_architecture.png          - Static architecture
workflow_diagram_{layer}_professional.png - Process flow
overall_data_flow.png             - End-to-end flow
project_structure.png             - File organization
```

### Quality Standards
- **Resolution**: 300 DPI minimum
- **Format**: PNG for raster, SVG for vector
- **Size**: Optimized for web and print
- **Colors**: Consistent across all diagrams
- **Labels**: Clear, readable text
- **Legends**: Component type identification

### Version Control
- Commit both script and generated image
- Update version in filename if major changes
- Keep old versions for reference
- Document changes in commit message

## 🔄 Regeneration Process

### When to Regenerate
1. **Architecture Changes**: New components added
2. **Process Updates**: Workflow modifications
3. **Visual Improvements**: Better layout or colors
4. **Error Corrections**: Fix inaccuracies
5. **Format Updates**: New diagram standards

### Regeneration Steps
```bash
# 1. Navigate to diagrams folder
cd docs/diagrams

# 2. Edit Python script
vim generate_diagrams.py  # or generate_silver_diagram.py

# 3. Run generator
python3 generate_diagrams.py

# 4. Verify output
open workflow_diagram_bronze_professional.png

# 5. Commit changes
git add generate_diagrams.py workflow_diagram_bronze_professional.png
git commit -m "Update Bronze architecture diagram"
```

### Quality Checklist
- [ ] All components visible and labeled
- [ ] Arrows show correct direction
- [ ] Colors match standard scheme
- [ ] Text is readable at normal size
- [ ] Legend is complete and accurate
- [ ] No overlapping elements
- [ ] File size is reasonable (< 1 MB)

## 🎨 Customization Examples

### Change Color Scheme
```python
# In generate_diagrams.py
colors = {
    'user': '#E8EAF6',      # Light Indigo
    'streamlit': '#B3E5FC',  # Light Blue
    'stage': '#FFF9C4',      # Light Yellow
    'task': '#C8E6C9',       # Light Green
    'procedure': '#BBDEFB',  # Light Blue
    'table': '#F8BBD0',      # Light Pink
}

# Change to custom colors
colors = {
    'user': '#FF6B6B',       # Red
    'streamlit': '#4ECDC4',  # Teal
    'stage': '#FFE66D',      # Yellow
    'task': '#95E1D3',       # Mint
    'procedure': '#A8E6CF',  # Green
    'table': '#FFD3B6',      # Peach
}
```

### Adjust Layout
```python
# Modify component positions
create_box(ax, x=2, y=18, width=4, height=1.5, 
           text='Component Name', color=colors['task'])

# Adjust spacing
x_spacing = 1.5  # Horizontal space between components
y_spacing = 2.0  # Vertical space between rows
```

### Add New Components
```python
# Add new component type
colors['new_type'] = '#FFCCBC'  # Light Orange

# Create component
create_box(ax, x=5, y=10, width=3, height=1.2,
           text='New Component', color=colors['new_type'])

# Add to legend
legend_elements.append(
    Patch(facecolor=colors['new_type'], label='New Type')
)
```

## 📊 Diagram Inventory

### Current Diagrams (6 total)

| Diagram | Size | Type | Last Updated |
|---------|------|------|--------------|
| `bronze_architecture.png` | 150 KB | Architecture | Jan 2026 |
| `silver_architecture.png` | 180 KB | Architecture | Jan 2026 |
| `workflow_diagram_bronze_professional.png` | 220 KB | Workflow | Jan 2026 |
| `workflow_diagram_silver_professional.png` | 250 KB | Workflow | Jan 2026 |
| `overall_data_flow.png` | 130 KB | Data Flow | Jan 2026 |
| `project_structure.png` | 100 KB | Structure | Jan 2026 |

### Planned Diagrams
- [ ] Gold layer architecture (future)
- [ ] End-to-end data lineage
- [ ] Security architecture
- [ ] Deployment architecture
- [ ] Network diagram

## 🛠️ Tools & Dependencies

### Required Software
```bash
# Python 3.8+
python3 --version

# Matplotlib
pip install matplotlib

# Optional: Graphviz for advanced diagrams
brew install graphviz  # macOS
apt-get install graphviz  # Ubuntu
```

### Alternative Tools

**For Vector Graphics:**
- **draw.io**: Web-based diagramming
- **Lucidchart**: Professional diagramming
- **Visio**: Microsoft diagramming tool

**For Code-Based Diagrams:**
- **PlantUML**: Text-to-diagram
- **Mermaid**: Markdown diagrams
- **D2**: Modern diagram scripting

**For Architecture Diagrams:**
- **Structurizr**: C4 model diagrams
- **Cloudcraft**: Cloud architecture
- **Diagrams**: Python diagrams library

## 📖 Learning Resources

### Diagram Design
- [C4 Model](https://c4model.com/) - Architecture documentation
- [UML Basics](https://www.uml.org/) - Unified Modeling Language
- [Data Flow Diagrams](https://en.wikipedia.org/wiki/Data-flow_diagram) - DFD concepts

### Tools Tutorials
- [Matplotlib Tutorial](https://matplotlib.org/stable/tutorials/index.html)
- [draw.io Guide](https://www.diagrams.net/doc/)
- [PlantUML Guide](https://plantuml.com/guide)

### Best Practices
- [Diagram Design Principles](https://www.visual-paradigm.com/guide/diagram-design/)
- [Technical Documentation](https://www.writethedocs.org/)
- [Visual Communication](https://www.interaction-design.org/literature/topics/visual-communication)

## 🤝 Contributing Diagrams

### Contribution Guidelines
1. Follow existing color scheme
2. Use consistent font sizes
3. Include legends
4. Add descriptive labels
5. Test at different sizes
6. Update this README
7. Commit both script and output

### Review Checklist
- [ ] Diagram is accurate
- [ ] Colors are consistent
- [ ] Text is readable
- [ ] Layout is clear
- [ ] File size is reasonable
- [ ] Script is documented
- [ ] README is updated

---

**Last Updated**: January 2, 2026  
**Version**: 2.0  
**Maintainer**: Project Team  
**Status**: ✅ Production Ready  
**Total Diagrams**: 6  
**Format**: PNG (300 DPI)

