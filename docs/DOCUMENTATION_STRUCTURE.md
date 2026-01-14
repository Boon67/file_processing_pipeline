# Documentation Structure

This document describes the organization of all project documentation.

## 📁 Directory Structure

```
docs/
├── design/                          # All architecture and design documentation
│   ├── README.md                    # Design documentation overview
│   ├── ARCHITECTURE.md              # Complete architecture reference (visual + ASCII)
│   ├── SYSTEM_DESIGN.md             # High-level system design
│   ├── TECHNICAL_SPECIFICATION.md   # Detailed technical specifications
│   ├── DEPLOYMENT_GUIDE.md          # Operations and deployment manual
│   ├── generate_design_diagrams.py  # Script to generate diagrams
│   └── images/                      # All architecture diagrams
│       ├── architecture_overview.png
│       ├── data_flow_diagram.png
│       ├── security_rbac_diagram.png
│       ├── deployment_pipeline_diagram.png
│       ├── bronze_architecture.png
│       ├── silver_architecture.png
│       ├── overall_data_flow.png
│       └── project_structure.png
│
├── screenshots/                     # Application UI screenshots
│   ├── README.md
│   ├── bronze_processing_status.png
│   ├── bronze_upload_files.png
│   ├── silver_data_viewer.png
│   └── silver_field_mapper.png
│
├── testing/                         # Test plans and documentation
│   └── TEST_PLAN_BRONZE.md
│
└── USER_GUIDE.md                    # End-user documentation
```

## 🎯 Design Philosophy

### Consolidated Structure
All architecture and design documentation is now consolidated in `docs/design/` for:
- **Single Source of Truth**: One location for all design documents
- **Easy Navigation**: Clear hierarchy and relationships
- **Consistent Organization**: All diagrams in one images folder
- **Simplified Maintenance**: Fewer folders to manage

### Document Types

**Architecture Documents** (`docs/design/`):
- `ARCHITECTURE.md` - Complete reference with visual and ASCII diagrams
- `SYSTEM_DESIGN.md` - High-level overview for stakeholders
- `TECHNICAL_SPECIFICATION.md` - Detailed specs for developers
- `DEPLOYMENT_GUIDE.md` - Operations manual for DevOps

**User Documentation**:
- `docs/USER_GUIDE.md` - End-user instructions
- `bronze/README.md` - Bronze layer details
- `silver/README.md` - Silver layer details

**Visual Assets**:
- `docs/design/images/` - All architecture diagrams
- `docs/screenshots/` - Application UI screenshots

## 📊 Diagram Organization

All architecture diagrams are in `docs/design/images/`:

### Design Diagrams (Generated)
Created by `generate_design_diagrams.py`:
- `architecture_overview.png` - High-level system architecture
- `data_flow_diagram.png` - End-to-end data flow
- `security_rbac_diagram.png` - Security and RBAC model
- `deployment_pipeline_diagram.png` - CI/CD pipeline

### Layer Diagrams
- `bronze_architecture.png` - Bronze layer detailed view
- `silver_architecture.png` - Silver layer detailed view
- `overall_data_flow.png` - Complete data flow
- `project_structure.png` - Project file structure

## 🔄 Migration Notes

### Changes Made (January 14, 2026)

**Consolidated Folders**:
- ❌ `docs/architecture/` → ✅ `docs/design/ARCHITECTURE.md`
- ❌ `docs/diagrams/` → ✅ `docs/design/images/`

**Updated References**:
- `README.md` - Updated all architecture and diagram links
- `QUICK_START.md` - Updated architecture reference
- `DOCUMENTATION_INDEX.md` - Complete restructure
- `bronze/README.md` - Updated architecture link

**Benefits**:
- Single location for all design documentation
- Clear separation between design docs and user docs
- All diagrams in one organized folder
- Easier to find and maintain documentation

## 📖 Finding Documentation

### By Audience

**Architects & Decision Makers**:
→ Start with `docs/design/ARCHITECTURE.md` or `docs/design/SYSTEM_DESIGN.md`

**Developers & Engineers**:
→ Start with `docs/design/TECHNICAL_SPECIFICATION.md`

**DevOps & Administrators**:
→ Start with `docs/design/DEPLOYMENT_GUIDE.md`

**End Users**:
→ Start with `docs/USER_GUIDE.md`

### By Topic

**System Architecture**:
→ `docs/design/ARCHITECTURE.md` (complete reference)

**Visual Diagrams**:
→ `docs/design/images/` (all diagrams)

**Deployment**:
→ `docs/design/DEPLOYMENT_GUIDE.md`

**Usage Instructions**:
→ `docs/USER_GUIDE.md`

**Screenshots**:
→ `docs/screenshots/`

## 🛠️ Maintenance

### Updating Documentation

**When architecture changes**:
1. Update `docs/design/ARCHITECTURE.md`
2. Update `docs/design/SYSTEM_DESIGN.md` if needed
3. Regenerate diagrams: `cd docs/design && python3 generate_design_diagrams.py`
4. Update version and date in documents

**When adding new features**:
1. Update `docs/design/TECHNICAL_SPECIFICATION.md`
2. Update layer READMEs (`bronze/README.md`, `silver/README.md`)
3. Update `docs/USER_GUIDE.md` for user-facing features

**When changing deployment**:
1. Update `docs/design/DEPLOYMENT_GUIDE.md`
2. Update deployment scripts if needed
3. Update `DEPLOYMENT_CHECKLIST.md`

### Generating Diagrams

```bash
cd docs/design
python3 generate_design_diagrams.py
```

All diagrams are automatically saved to `docs/design/images/`.

## 📋 Document Standards

### File Naming
- Use UPPERCASE for major documents (e.g., `ARCHITECTURE.md`)
- Use snake_case for images (e.g., `data_flow_diagram.png`)
- Use descriptive names that indicate content

### Markdown Conventions
- Include table of contents for long documents
- Use relative links for internal references
- Include diagrams with descriptive alt text
- End with version, date, and status

### Version Control
- Update version number when making significant changes
- Update "Last Updated" date on every edit
- Document changes in version history section

## 🔗 Quick Links

- **[Documentation Index](../DOCUMENTATION_INDEX.md)** - Complete documentation guide
- **[Design Documentation](design/README.md)** - Design docs overview
- **[User Guide](USER_GUIDE.md)** - End-user documentation
- **[Main README](../README.md)** - Project overview

---

**Version**: 1.0  
**Last Updated**: January 14, 2026  
**Status**: ✅ Complete
