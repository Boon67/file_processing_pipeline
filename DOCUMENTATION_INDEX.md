# Documentation Index

**Complete guide to all documentation in the Snowflake File Processing Pipeline project.**

**Last Updated**: January 15, 2026

---

## 🚀 Quick Start (New Users)

| Document | Description | Time |
|----------|-------------|------|
| **[README.md](README.md)** | Main project overview and features | 10 min |
| **[QUICK_START.md](QUICK_START.md)** | Get started in under 10 minutes | 10 min |
| **[Sample Data Quick Start](sample_data/README.md)** | Try with sample data | 5 min |

## 🤖 Application Generation

| Document | Description | Audience |
|----------|-------------|----------|
| **[APPLICATION_GENERATION_PROMPT.md](APPLICATION_GENERATION_PROMPT.md)** | **Complete prompt to regenerate entire application** | AI/Developers |
| **[PROMPT_USAGE_GUIDE.md](PROMPT_USAGE_GUIDE.md)** | Guide for using the generation prompt | AI/Developers |

---

## 📚 Core Documentation

### Essential Reading

| Document | Description | Audience |
|----------|-------------|----------|
| **[README.md](README.md)** | Complete project overview, features, and quick reference | Everyone |
| **[User Guide](docs/USER_GUIDE.md)** | Comprehensive usage guide with screenshots | End users |
| **[Architecture](docs/design/ARCHITECTURE.md)** | Complete architecture reference with diagrams | Technical roles |

### Deployment & Operations

| Document | Description | Audience |
|----------|-------------|----------|
| **[Quick Start](QUICK_START.md)** | 10-minute deployment guide | New deployers |
| **[Deployment & Operations](docs/DEPLOYMENT_AND_OPERATIONS.md)** | **Complete deployment, configuration, logging, and troubleshooting guide** | DevOps, Admins |

### Layer-Specific Documentation

| Document | Description | Audience |
|----------|-------------|----------|
| **[Bronze Layer README](bronze/README.md)** | Bronze layer detailed documentation | Bronze users |
| **[Silver Layer README](silver/README.md)** | Silver layer detailed documentation | Silver users |
| **[Bronze Streamlit App](bronze/bronze_streamlit/README.md)** | Bronze UI documentation | Bronze users |
| **[Silver Streamlit App](silver/silver_streamlit/README.md)** | Silver UI documentation | Silver users |

---

## 🏗️ Architecture & Design

### Design Documentation

All architecture and design documentation is in `docs/design/`:

| Document | Description | Audience |
|----------|-------------|----------|
| **[Design Overview](docs/design/README.md)** | Design documentation navigation | All |
| **[Architecture](docs/design/ARCHITECTURE.md)** | Complete architecture reference with visual and ASCII diagrams | All technical roles |
| **[System Design](docs/design/SYSTEM_DESIGN.md)** | High-level system design and patterns | Architects, Management |
| **[Technical Specification](docs/design/TECHNICAL_SPECIFICATION.md)** | Detailed technical specifications | Developers, Engineers |
| **[Deployment Guide](docs/design/DEPLOYMENT_GUIDE.md)** | Complete deployment guide | DevOps, Administrators |

### Architecture Diagrams

All diagrams are located in `docs/design/images/`:

| Diagram | Description |
|---------|-------------|
| **[architecture_overview.png](docs/design/images/architecture_overview.png)** | High-level system architecture |
| **[data_flow_diagram.png](docs/design/images/data_flow_diagram.png)** | End-to-end data flow |
| **[security_rbac_diagram.png](docs/design/images/security_rbac_diagram.png)** | Security and RBAC model |
| **[deployment_pipeline_diagram.png](docs/design/images/deployment_pipeline_diagram.png)** | CI/CD deployment pipeline |
| **[bronze_architecture.png](docs/design/images/bronze_architecture.png)** | Bronze layer detailed view |
| **[silver_architecture.png](docs/design/images/silver_architecture.png)** | Silver layer detailed view |
| **[overall_data_flow.png](docs/design/images/overall_data_flow.png)** | Complete data flow |
| **[project_structure.png](docs/design/images/project_structure.png)** | Project file structure |

---

## 📖 Specialized Guides

### TPA (Third Party Administrator)

| Document | Description |
|----------|-------------|
| **[TPA Complete Guide](docs/guides/TPA_COMPLETE_GUIDE.md)** | **Comprehensive TPA guide** - Architecture, naming, configuration, best practices |

### Performance & Optimization

| Document | Description |
|----------|-------------|
| **[Snowflake Performance Note](docs/guides/SNOWFLAKE_PERFORMANCE_NOTE.md)** | Performance optimization guide |

---

## 📝 Change Logs & Updates

### Recent Updates (2026)

| Document | Description |
|----------|-------------|
| **[2026-01-15 Features & Fixes](docs/changelogs/2026-01-15_features_and_fixes.md)** | **Silver Streamlit: LLM approval, TPA fixes, selectbox behavior, sidebar layout** |

---

## 📊 Sample Data

| Document | Description |
|----------|-------------|
| **[Sample Data Overview](sample_data/README.md)** | Sample data overview and quick start |
| **[Claims Data](sample_data/claims_data/README.md)** | Claims data files documentation |
| **[Config Files](sample_data/config/README.md)** | Configuration files documentation |

---

## 🖼️ Screenshots & Visuals

| Document | Description |
|----------|-------------|
| **[Screenshots Overview](docs/screenshots/README.md)** | Application screenshots overview |
| **[bronze_processing_status.png](docs/screenshots/bronze_processing_status.png)** | Bronze processing dashboard |
| **[bronze_upload_files.png](docs/screenshots/bronze_upload_files.png)** | Bronze file upload interface |
| **[silver_data_viewer.png](docs/screenshots/silver_data_viewer.png)** | Silver data viewer |
| **[silver_field_mapper.png](docs/screenshots/silver_field_mapper.png)** | Silver field mapper |

---

## 🧪 Testing

| Document | Description |
|----------|-------------|
| **[Bronze Test Plan](docs/testing/TEST_PLAN_BRONZE.md)** | Bronze layer test plan |

---

## 🔍 Quick Reference by Role

### New User / Evaluator
1. [README.md](README.md) - Overview
2. [QUICK_START.md](QUICK_START.md) - Get started
3. [Architecture](docs/design/ARCHITECTURE.md) - Visual architecture

### Deployer / Administrator
1. [Quick Start](QUICK_START.md) - Fast deployment
2. [Deployment & Operations](docs/DEPLOYMENT_AND_OPERATIONS.md) - Complete guide
3. [Silver Deployment Verification](silver/DEPLOYMENT_VERIFICATION.md) - Post-deployment checks

### Developer / Data Engineer
1. [Architecture](docs/design/ARCHITECTURE.md) - System architecture
2. [Technical Specification](docs/design/TECHNICAL_SPECIFICATION.md) - Technical details
3. [Bronze README](bronze/README.md) - Bronze implementation
4. [Silver README](silver/README.md) - Silver implementation

### End User / Analyst
1. [User Guide](docs/USER_GUIDE.md) - Complete usage guide
2. [Bronze Streamlit App](bronze/bronze_streamlit/README.md) - Bronze UI
3. [Silver Streamlit App](silver/silver_streamlit/README.md) - Silver UI

---

## 🔍 Quick Reference by Task

### Deploying the Pipeline
1. [Quick Start](QUICK_START.md)
2. [Deployment & Operations](docs/DEPLOYMENT_AND_OPERATIONS.md)
3. [Silver Deployment Verification](silver/DEPLOYMENT_VERIFICATION.md)

### Uploading Files
1. [User Guide - Bronze Layer](docs/USER_GUIDE.md#bronze-layer)
2. [Bronze README - File Upload](bronze/README.md#file-upload)
3. [Bronze Streamlit App](bronze/bronze_streamlit/README.md)

### Transforming Data
1. [User Guide - Silver Layer](docs/USER_GUIDE.md#silver-layer)
2. [Silver README - Transformation](silver/README.md#transformation)
3. [Silver Streamlit App](silver/silver_streamlit/README.md)

### Working with TPAs
1. [TPA Complete Guide](docs/guides/TPA_COMPLETE_GUIDE.md)
2. [Bronze TPA Upload Guide](bronze/TPA_UPLOAD_GUIDE.md)
3. [Silver TPA Mapping Guide](silver/TPA_MAPPING_GUIDE.md)

### Troubleshooting
1. [Deployment & Operations - Troubleshooting](docs/DEPLOYMENT_AND_OPERATIONS.md#troubleshooting)
2. [Silver Deployment Verification](silver/DEPLOYMENT_VERIFICATION.md#troubleshooting)
3. [User Guide - Troubleshooting](docs/USER_GUIDE.md#troubleshooting)

---

## 📝 Configuration Files

| File | Description |
|------|-------------|
| **[default.config](default.config)** | Default configuration settings |
| **[custom.config.example](custom.config.example)** | Example custom configuration |

---

## 🛠️ Scripts

| Script | Description |
|--------|-------------|
| **[deploy.sh](deploy.sh)** | Main deployment script (Bronze + Silver) |
| **[deploy_bronze.sh](deploy_bronze.sh)** | Bronze layer deployment |
| **[deploy_silver.sh](deploy_silver.sh)** | Silver layer deployment |
| **[redeploy_silver_streamlit.sh](redeploy_silver_streamlit.sh)** | Redeploy Silver Streamlit app |
| **[undeploy.sh](undeploy.sh)** | Complete cleanup/undeploy |
| **[validate_structure.sh](validate_structure.sh)** | Validate project structure |

---

## 📋 SQL Scripts

### Bronze Layer
- `bronze/1_Setup_Database_Roles.sql` - Database and role setup
- `bronze/2_Bronze_Schema_Tables.sql` - Schema and tables
- `bronze/3_Bronze_Setup_Logic.sql` - Processing procedures
- `bronze/4_Bronze_Tasks.sql` - Task definitions

### Silver Layer
- `silver/1_Silver_Schema_Setup.sql` - Schema and metadata tables
- `silver/2_Silver_Target_Schemas.sql` - Target table management
- `silver/3_Silver_Mapping_Procedures.sql` - Field mapping procedures
- `silver/4_Silver_Rules_Engine.sql` - Transformation rules engine
- `silver/5_Silver_Transformation_Logic.sql` - Main transformation logic
- `silver/6_Silver_Tasks.sql` - Task definitions
- `silver/7_Silver_Standard_Metadata_Columns.sql` - Standard metadata

---

## 🔗 External Links

- **Snowflake Documentation**: https://docs.snowflake.com/
- **Snowflake CLI**: https://docs.snowflake.com/en/developer-guide/snowflake-cli/index
- **Streamlit in Snowflake**: https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit

---

## 📄 Document Conventions

### Status Indicators
- ✓ - Success/Pass
- ✗ - Failure/Error
- ⚠ - Warning
- ○ - Info/Optional

### Code Blocks
- `inline code` - Commands, file names, small snippets
- ```sql - SQL queries
- ```bash - Shell commands
- ```python - Python code

### File Paths
- Relative paths from project root
- Example: `silver/README.md`

---

## 🆘 Getting Help

1. **Check relevant documentation** using this index
2. **Review troubleshooting sections** in deployment docs
3. **Run verification scripts** to identify issues
4. **Check Snowflake documentation** for platform-specific questions

---

## 📅 Documentation Changes

### January 15, 2026 - Major Consolidation

**Consolidated Documents:**

1. **TPA Documentation** → `docs/guides/TPA_COMPLETE_GUIDE.md`
   - Merged: `docs/TPA_ARCHITECTURE.md`, `docs/TPA_TABLE_NAMING_STRATEGY.md`, `docs/guides/TPA_DATABASE_QUICKSTART.md`
   - Result: Single comprehensive TPA guide

2. **Deployment & Operations** → `docs/DEPLOYMENT_AND_OPERATIONS.md`
   - Merged: `LOGGING_IMPLEMENTATION.md`, `bronze/TASK_PRIVILEGE_FIX.md`, deployment sections from README and QUICK_START
   - Result: Complete deployment, configuration, logging, and operations guide

3. **Features & Fixes** → `docs/changelogs/2026-01-15_features_and_fixes.md`
   - Merged: `LLM_MAPPING_APPROVAL_FEATURE.md`, `docs/changelogs/2026-01-15_streamlit_fixes.md`
   - Result: Consolidated changelog for all January 15, 2026 changes

**Files to Remove:**
- `LLM_MAPPING_APPROVAL_FEATURE.md` (consolidated)
- `LOGGING_IMPLEMENTATION.md` (consolidated)
- `bronze/TASK_PRIVILEGE_FIX.md` (consolidated)
- `docs/TPA_ARCHITECTURE.md` (consolidated)
- `docs/TPA_TABLE_NAMING_STRATEGY.md` (consolidated)
- `docs/guides/TPA_DATABASE_QUICKSTART.md` (consolidated)
- `docs/changelogs/2026-01-15_streamlit_fixes.md` (consolidated)
- `DOCUMENTATION_CLEANUP_2026-01-15.md` (obsolete)
- `docs/DOCUMENTATION_STRUCTURE.md` (redundant with this index)

**Benefits:**
- ✅ Reduced from 35+ docs to ~20 core docs
- ✅ Single source of truth for each topic
- ✅ Easier to find information
- ✅ Less duplication
- ✅ Better organization

---

**Last Updated**: January 15, 2026  
**Status**: ✅ Complete

For the most current information, always refer to the individual documentation files.
