# Documentation Index

Complete guide to all documentation in the Snowflake File Processing Pipeline project.

## 📚 Getting Started

| Document | Description | Audience |
|----------|-------------|----------|
| **[README.md](README.md)** | Main project overview, features, and architecture | Everyone |
| **[QUICK_START.md](QUICK_START.md)** | 10-minute quick start guide | New users |
| **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** | Step-by-step deployment verification | Deployers |

## 🏗️ Architecture & Design

| Document | Description | Audience |
|----------|-------------|----------|
| **[docs/design/README.md](docs/design/README.md)** | Design documentation overview and navigation | All |
| **[docs/design/ARCHITECTURE.md](docs/design/ARCHITECTURE.md)** | Complete architecture reference with visual and ASCII diagrams | All technical roles |
| **[docs/design/SYSTEM_DESIGN.md](docs/design/SYSTEM_DESIGN.md)** | Comprehensive system design document | Architects, Management |
| **[docs/design/TECHNICAL_SPECIFICATION.md](docs/design/TECHNICAL_SPECIFICATION.md)** | Detailed technical specifications | Developers, Engineers |
| **[docs/design/DEPLOYMENT_GUIDE.md](docs/design/DEPLOYMENT_GUIDE.md)** | Complete deployment guide | DevOps, Administrators |

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

## 📖 User Guides

| Document | Description | Audience |
|----------|-------------|----------|
| **[docs/USER_GUIDE.md](docs/USER_GUIDE.md)** | Comprehensive user guide for all features | End users |
| **[bronze/README.md](bronze/README.md)** | Bronze layer detailed documentation | Bronze users |
| **[silver/README.md](silver/README.md)** | Silver layer detailed documentation | Silver users |
| **[sample_data/README.md](sample_data/README.md)** | Sample data overview and quick start | New users |

## 🔧 Deployment & Operations

| Document | Description |
|----------|-------------|
| **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** | Complete deployment checklist |
| **[silver/DEPLOYMENT_VERIFICATION.md](silver/DEPLOYMENT_VERIFICATION.md)** | Post-deployment verification guide |
| **[silver/quick_deployment_check.sql](silver/quick_deployment_check.sql)** | Quick verification SQL script |
| **[silver/verify_silver_deployment.sql](silver/verify_silver_deployment.sql)** | Detailed verification SQL script |

## 🎨 Streamlit Applications

| Document | Description |
|----------|-------------|
| **[bronze/bronze_streamlit/README.md](bronze/bronze_streamlit/README.md)** | Bronze Streamlit app documentation |
| **[silver/silver_streamlit/README.md](silver/silver_streamlit/README.md)** | Silver Streamlit app documentation |

## 📊 Sample Data

| Document | Description |
|----------|-------------|
| **[sample_data/README.md](sample_data/README.md)** | Sample data overview, quick start, and structure |
| **[sample_data/claims_data/README.md](sample_data/claims_data/README.md)** | Claims data files documentation |
| **[sample_data/config/README.md](sample_data/config/README.md)** | Configuration files documentation |

## 🖼️ Screenshots & Visuals

| Document | Description |
|----------|-------------|
| **[docs/screenshots/README.md](docs/screenshots/README.md)** | Application screenshots overview |
| **[docs/screenshots/bronze_processing_status.png](docs/screenshots/bronze_processing_status.png)** | Bronze processing dashboard |
| **[docs/screenshots/bronze_upload_files.png](docs/screenshots/bronze_upload_files.png)** | Bronze file upload interface |
| **[docs/screenshots/silver_data_viewer.png](docs/screenshots/silver_data_viewer.png)** | Silver data viewer |
| **[docs/screenshots/silver_field_mapper.png](docs/screenshots/silver_field_mapper.png)** | Silver field mapper |

## 🧪 Testing

| Document | Description |
|----------|-------------|
| **[docs/testing/TEST_PLAN_BRONZE.md](docs/testing/TEST_PLAN_BRONZE.md)** | Bronze layer test plan |


## 🔍 Quick Reference

### By Role

**New User / Evaluator:**
1. [README.md](README.md) - Overview
2. [QUICK_START.md](QUICK_START.md) - Get started
3. [docs/design/ARCHITECTURE.md](docs/design/ARCHITECTURE.md) - Visual architecture

**Deployer / Administrator:**
1. [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Deployment steps
2. [docs/design/DEPLOYMENT_GUIDE.md](docs/design/DEPLOYMENT_GUIDE.md) - Deployment guide
3. [silver/DEPLOYMENT_VERIFICATION.md](silver/DEPLOYMENT_VERIFICATION.md) - Verification

**Developer / Data Engineer:**
1. [docs/design/ARCHITECTURE.md](docs/design/ARCHITECTURE.md) - Architecture
2. [docs/design/TECHNICAL_SPECIFICATION.md](docs/design/TECHNICAL_SPECIFICATION.md) - Technical specs
3. [bronze/README.md](bronze/README.md) - Bronze implementation
4. [silver/README.md](silver/README.md) - Silver implementation

**End User / Analyst:**
1. [docs/USER_GUIDE.md](docs/USER_GUIDE.md) - User guide
2. [bronze/bronze_streamlit/README.md](bronze/bronze_streamlit/README.md) - Bronze app
3. [silver/silver_streamlit/README.md](silver/silver_streamlit/README.md) - Silver app

### By Task

**Deploying the Pipeline:**
1. [QUICK_START.md](QUICK_START.md)
2. [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
3. [silver/DEPLOYMENT_VERIFICATION.md](silver/DEPLOYMENT_VERIFICATION.md)

**Uploading Files:**
1. [docs/USER_GUIDE.md](docs/USER_GUIDE.md#bronze-layer)
2. [bronze/README.md](bronze/README.md#file-upload)
3. [bronze/bronze_streamlit/README.md](bronze/bronze_streamlit/README.md)

**Transforming Data:**
1. [docs/USER_GUIDE.md](docs/USER_GUIDE.md#silver-layer)
2. [silver/README.md](silver/README.md#transformation)
3. [silver/silver_streamlit/README.md](silver/silver_streamlit/README.md)

**Troubleshooting:**
1. [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md#troubleshooting)
2. [silver/DEPLOYMENT_VERIFICATION.md](silver/DEPLOYMENT_VERIFICATION.md#troubleshooting)
3. [docs/USER_GUIDE.md](docs/USER_GUIDE.md#troubleshooting)

## 📝 Configuration Files

| File | Description |
|------|-------------|
| **[default.config](default.config)** | Default configuration settings |
| **[custom.config.example](custom.config.example)** | Example custom configuration |

## 🛠️ Scripts

| Script | Description |
|--------|-------------|
| **[deploy.sh](deploy.sh)** | Main deployment script (Bronze + Silver) |
| **[deploy_bronze.sh](deploy_bronze.sh)** | Bronze layer deployment |
| **[deploy_silver.sh](deploy_silver.sh)** | Silver layer deployment |
| **[redeploy_silver_streamlit.sh](redeploy_silver_streamlit.sh)** | Redeploy Silver Streamlit app |
| **[undeploy.sh](undeploy.sh)** | Complete cleanup/undeploy |
| **[validate_structure.sh](validate_structure.sh)** | Validate project structure |

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

## 🔗 External Links

- **Snowflake Documentation**: https://docs.snowflake.com/
- **Snowflake CLI**: https://docs.snowflake.com/en/developer-guide/snowflake-cli/index
- **Streamlit in Snowflake**: https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit

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

## 🆘 Getting Help

1. **Check relevant documentation** using this index
2. **Review troubleshooting sections** in deployment docs
3. **Run verification scripts** to identify issues
4. **Check Snowflake documentation** for platform-specific questions

## 📅 Last Updated

This documentation index was last updated: January 14, 2026

For the most current information, always refer to the individual documentation files.

---

**Note**: All architecture diagrams and design documentation have been consolidated into `docs/design/` for easier navigation.
