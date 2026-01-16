# Application Generation Prompt - Usage Guide

**Purpose**: Guide for using the APPLICATION_GENERATION_PROMPT.md to regenerate the entire application.

**Date**: January 15, 2026

---

## Overview

The `APPLICATION_GENERATION_PROMPT.md` file contains a comprehensive, single-document prompt that can be used to regenerate the entire Snowflake File Processing Pipeline application from scratch, including:

- ✅ All code (SQL, Python, Bash)
- ✅ All documentation (22 documents)
- ✅ All architecture diagrams (8 diagrams)
- ✅ Complete system design
- ✅ Sample data and configurations
- ✅ Deployment scripts
- ✅ Testing plans

---

## Key Features of the Prompt

### 1. **Comprehensive Specifications**

The prompt includes detailed specifications for:
- Project architecture and design principles
- Bronze layer (5 stages, 3 tables, 7 procedures, 5 tasks)
- Silver layer (3 stages, 8 tables, 34 procedures, 5 tasks)
- RBAC security model (3-tier role hierarchy)
- Streamlit applications (2 full-featured UIs)
- Deployment system (scripts, logging, configuration)
- Documentation structure (22 documents)
- Architecture diagrams (8 diagrams)

### 2. **TPA-First Design**

The prompt emphasizes **TPA (Third Party Administrator) as a first-class dimension**:
- Every table, mapping, and rule has a TPA dimension
- Complete multi-tenant isolation
- Different schemas per TPA
- Different mappings per TPA
- Different rules per TPA
- TPA-specific target tables

### 3. **Production-Ready Requirements**

Includes specifications for:
- Error handling and logging
- Performance optimization
- Security and compliance
- Testing (unit, integration, UI, performance)
- Quality standards (code, SQL, Python, documentation)
- Platform support (macOS, Linux, Windows)

---

## How to Use the Prompt

### Option 1: Direct Copy-Paste to AI

1. Open `APPLICATION_GENERATION_PROMPT.md`
2. Copy the entire content (starting from "## Master Prompt")
3. Paste into your AI assistant (Claude, ChatGPT, etc.)
4. Ask: "Generate the complete application based on this specification"

### Option 2: Iterative Generation

Generate components in order:

**Phase 1: Foundation**
```
Generate the following from the APPLICATION_GENERATION_PROMPT:
1. Project structure and configuration files
2. Bronze layer SQL scripts (1-4)
3. RBAC setup script
```

**Phase 2: Bronze Layer**
```
Generate from the APPLICATION_GENERATION_PROMPT:
1. Bronze stored procedures (Python + SQL)
2. Bronze task definitions
3. Bronze Streamlit application
```

**Phase 3: Silver Layer**
```
Generate from the APPLICATION_GENERATION_PROMPT:
1. Silver schema setup and metadata tables
2. Silver stored procedures (all 34)
3. Silver task definitions
4. Silver Streamlit application
```

**Phase 4: Deployment**
```
Generate from the APPLICATION_GENERATION_PROMPT:
1. Deployment scripts (deploy.sh, deploy_bronze.sh, deploy_silver.sh)
2. Undeploy script
3. Configuration management
4. Logging system
```

**Phase 5: Documentation**
```
Generate from the APPLICATION_GENERATION_PROMPT:
1. Core documentation (README, QUICK_START, DOCUMENTATION_INDEX)
2. Comprehensive guides (USER_GUIDE, DEPLOYMENT_AND_OPERATIONS, TPA_COMPLETE_GUIDE)
3. Architecture documentation (ARCHITECTURE, SYSTEM_DESIGN, TECHNICAL_SPECIFICATION)
4. Layer-specific documentation
```

**Phase 6: Diagrams & Sample Data**
```
Generate from the APPLICATION_GENERATION_PROMPT:
1. Architecture diagrams (8 diagrams)
2. Sample data files (5 TPAs)
3. Configuration CSVs
```

### Option 3: Component-Specific Generation

Generate specific components:

**Example 1: Generate Bronze Layer Only**
```
From the APPLICATION_GENERATION_PROMPT, generate only the Bronze Layer:
- Section 3 (Bronze Layer specifications)
- Include all stages, tables, procedures, and tasks
- Include Bronze Streamlit application
- Include Bronze documentation
```

**Example 2: Generate Silver Layer Only**
```
From the APPLICATION_GENERATION_PROMPT, generate only the Silver Layer:
- Section 4 (Silver Layer specifications)
- Include all stages, tables, procedures, and tasks
- Include Silver Streamlit application
- Include Silver documentation
```

**Example 3: Generate Documentation Only**
```
From the APPLICATION_GENERATION_PROMPT, generate all documentation:
- Section 10 (Documentation Structure)
- Section 14 (Documentation Requirements)
- Create all 22 documents with proper cross-references
```

**Example 4: Generate Diagrams Only**
```
From the APPLICATION_GENERATION_PROMPT, generate all architecture diagrams:
- Section 11 (Architecture Diagrams)
- Create all 8 diagrams using Python diagrams library
- Use professional color scheme and layout
```

---

## Prompt Sections Reference

| Section | Content | Use For |
|---------|---------|---------|
| 1 | Project Overview | Understanding goals and key innovations |
| 2 | Architecture Principles | Design philosophy and TPA-first approach |
| 3 | Bronze Layer | Raw ingestion implementation |
| 4 | Silver Layer | Transformation and quality implementation |
| 5 | RBAC Security | Security model and permissions |
| 6 | Streamlit Applications | UI implementation |
| 7 | Deployment System | Deployment scripts and configuration |
| 8 | TPA Implementation | TPA-specific details and data flow |
| 9 | Sample Data | Sample files and configurations |
| 10 | Documentation Structure | All documentation files |
| 11 | Architecture Diagrams | Diagram specifications |
| 12 | Code Structure | Project file organization |
| 13 | Implementation Requirements | Detailed requirements per component |
| 14 | Testing Requirements | Test plans and scenarios |
| 15 | Documentation Requirements | Documentation standards |
| 16 | Quality Standards | Code and documentation quality |
| 17 | Success Criteria | Completion checklist |
| 18 | Deliverables | What to produce |
| 19 | Technology Stack | Technologies and libraries |
| 20 | Special Notes | Critical implementation points |

---

## Example Prompts

### Complete Application Generation

```
I need you to generate a complete Snowflake File Processing Pipeline application 
based on the attached APPLICATION_GENERATION_PROMPT.md specification.

Please generate:
1. All SQL scripts (Bronze and Silver layers)
2. All Python code (Streamlit applications)
3. All deployment scripts (Bash)
4. All documentation (22 documents)
5. All architecture diagrams (8 diagrams)
6. Sample data files

Key requirement: TPA (Third Party Administrator) must be a first-class dimension 
throughout the entire application.

Start with the project structure and Bronze layer, then proceed to Silver layer, 
deployment system, and documentation.
```

### Bronze Layer Only

```
Generate the Bronze Layer of the Snowflake File Processing Pipeline based on 
Section 3 of the APPLICATION_GENERATION_PROMPT.md.

Include:
- 5 stages (SRC, COMPLETED, ERROR, ARCHIVE, STREAMLIT_STAGE)
- 3 tables (TPA_MASTER, RAW_DATA_TABLE, file_processing_queue)
- 7 stored procedures (CSV/Excel processing, discovery, movement, archival)
- 5 tasks with proper dependencies
- Bronze Streamlit application
- Bronze documentation

Ensure TPA is extracted from file path and stored in all records.
```

### Silver Layer Only

```
Generate the Silver Layer of the Snowflake File Processing Pipeline based on 
Section 4 of the APPLICATION_GENERATION_PROMPT.md.

Include:
- 3 stages (SILVER_STAGE, SILVER_CONFIG, SILVER_STREAMLIT)
- 8 metadata tables (all with TPA dimension)
- 34 stored procedures (target table management, field mapping, rules engine, transformation)
- 5 tasks with proper dependencies
- Silver Streamlit application with LLM mapping approval
- Silver documentation

Ensure TPA is a required dimension in all metadata tables.
```

### Documentation Only

```
Generate all documentation for the Snowflake File Processing Pipeline based on 
Section 10 of the APPLICATION_GENERATION_PROMPT.md.

Create 22 documents:
- Core: README, QUICK_START, DOCUMENTATION_INDEX
- Guides: USER_GUIDE, DEPLOYMENT_AND_OPERATIONS, TPA_COMPLETE_GUIDE
- Architecture: ARCHITECTURE, SYSTEM_DESIGN, TECHNICAL_SPECIFICATION, DEPLOYMENT_GUIDE
- Layer-specific: Bronze/Silver READMEs and Streamlit docs
- Specialized: TPA guides, performance notes, testing plans

Ensure all cross-references are correct and consistent.
```

### Diagrams Only

```
Generate all architecture diagrams for the Snowflake File Processing Pipeline 
based on Section 11 of the APPLICATION_GENERATION_PROMPT.md.

Create 8 diagrams using Python diagrams library:
1. architecture_overview.png - High-level system architecture
2. data_flow_diagram.png - End-to-end data flow with TPA dimension
3. security_rbac_diagram.png - Three-tier role hierarchy
4. deployment_pipeline_diagram.png - Deployment flow
5. bronze_architecture.png - Bronze layer details
6. silver_architecture.png - Silver layer details
7. overall_data_flow.png - Multi-TPA data flow
8. project_structure.png - Project file structure

Use professional color scheme (blues, greens, grays) and include TPA dimension 
where relevant.
```

---

## Validation Checklist

After generation, verify:

### Code Validation
- [ ] All SQL scripts are syntactically correct
- [ ] All Python code follows PEP 8
- [ ] All Bash scripts are executable
- [ ] TPA dimension is in all metadata tables
- [ ] Error handling is comprehensive
- [ ] Logging is implemented

### Functionality Validation
- [ ] Bronze layer processes CSV and Excel files
- [ ] TPA is extracted from file path
- [ ] Silver layer creates dynamic tables
- [ ] Field mapping works (Manual/ML/LLM)
- [ ] Rules engine applies transformations
- [ ] Streamlit apps are functional

### Documentation Validation
- [ ] All 22 documents are created
- [ ] Cross-references are correct
- [ ] Code examples are accurate
- [ ] Screenshots are included
- [ ] No broken links

### Architecture Validation
- [ ] All 8 diagrams are generated
- [ ] Diagrams are professional quality
- [ ] TPA dimension is shown
- [ ] Data flow is clear
- [ ] Components are labeled

### Deployment Validation
- [ ] Deployment scripts work
- [ ] Configuration is flexible
- [ ] Logging is comprehensive
- [ ] Platform support is correct
- [ ] Error handling is graceful

---

## Tips for Best Results

### 1. **Be Specific About TPA**
Always emphasize that TPA must be a first-class dimension:
```
"Ensure TPA is a REQUIRED column in all metadata tables and part of unique constraints"
```

### 2. **Request Idempotent Scripts**
Ensure scripts can be run multiple times:
```
"Make all SQL scripts idempotent using CREATE IF NOT EXISTS and MERGE statements"
```

### 3. **Emphasize Error Handling**
Request comprehensive error handling:
```
"Include try-catch blocks in all Python procedures and detailed error logging"
```

### 4. **Request Complete Documentation**
Ask for thorough documentation:
```
"Include detailed comments in all code and comprehensive user documentation"
```

### 5. **Specify Platform Support**
Clarify platform requirements:
```
"Ensure deployment scripts work on macOS, Linux, and Windows (Git Bash)"
```

---

## Troubleshooting

### Issue: Generated code missing TPA dimension

**Solution**: Re-prompt with emphasis:
```
"Regenerate with TPA as a REQUIRED column in all metadata tables. 
TPA must be part of unique constraints in:
- target_schemas (table_name, column_name, tpa)
- field_mappings (source_field, target_table, target_column, tpa)
- transformation_rules (rule_id, tpa)
```

### Issue: Documentation cross-references broken

**Solution**: Request validation:
```
"Validate all cross-references in documentation and update any broken links. 
Use relative paths from project root."
```

### Issue: Diagrams not professional quality

**Solution**: Re-prompt with specific requirements:
```
"Regenerate diagrams with:
- Professional color scheme (blues: #1E88E5, greens: #43A047, grays: #616161)
- Clear component labels
- Arrows showing data flow direction
- Icons for components
- TPA dimension highlighted
```

### Issue: Deployment scripts fail on Windows

**Solution**: Request platform-specific handling:
```
"Add Windows-specific handling to deployment scripts:
- Detect Windows environment
- Convert Unicode characters to ASCII
- Handle Git Bash paths
- Provide clear error messages for unsupported shells
```

---

## Advanced Usage

### Customization

Modify the prompt for specific needs:

**Example: Add Gold Layer**
```
Extend the APPLICATION_GENERATION_PROMPT to add a Gold layer:
- Aggregation and business metrics
- Star schema design
- TPA-specific metrics
- Reporting views
- Gold Streamlit dashboard
```

**Example: Add Real-Time Processing**
```
Modify the APPLICATION_GENERATION_PROMPT to add real-time processing:
- Replace Tasks with Snowpipe
- Add Streams for CDC
- Implement micro-batch processing
- Add real-time monitoring
```

**Example: Add Data Governance**
```
Extend the APPLICATION_GENERATION_PROMPT to add data governance:
- Data lineage tracking
- Data quality scorecards
- Compliance reporting
- Audit trail enhancements
- Data catalog integration
```

---

## Success Metrics

The generated application is complete when:

✅ **Code**: All 100+ files generated and syntactically correct  
✅ **TPA**: TPA dimension implemented throughout  
✅ **Functionality**: All features work as specified  
✅ **Documentation**: All 22 documents complete and cross-referenced  
✅ **Diagrams**: All 8 diagrams generated professionally  
✅ **Deployment**: Scripts work on all platforms  
✅ **Testing**: All tests pass  
✅ **Quality**: Code meets quality standards  

---

## Support

For issues or questions:

1. **Review the prompt**: Check APPLICATION_GENERATION_PROMPT.md for specifications
2. **Check documentation**: Review DOCUMENTATION_INDEX.md for guidance
3. **Validate structure**: Run validate_structure.sh
4. **Test deployment**: Use deploy.sh with default.config

---

**Version**: 1.0  
**Date**: January 15, 2026  
**Status**: ✅ Complete

This guide provides everything needed to successfully use the APPLICATION_GENERATION_PROMPT.md to regenerate the entire Snowflake File Processing Pipeline application.
