# Application Screenshots

This folder contains screenshots of the Snowflake File Processing Pipeline Streamlit applications.

## Bronze Ingestion Pipeline

### Processing Status Dashboard
![Bronze Processing Status](bronze_processing_status.png)

**Features shown:**
- Total files processed: 5
- Success rate: 100%
- Total rows ingested: 5,095
- Detailed file-level status with timestamps
- Filter by status and file type
- Real-time metrics and statistics

### File Upload Interface
![Bronze Upload Files](bronze_upload_files.png)

**Features shown:**
- Drag-and-drop file upload
- Support for CSV and Excel files
- "Process Files" checkbox for automatic discovery
- Configuration display
- Connection status

## Silver Transformation Manager

### Data Viewer
![Silver Data Viewer](silver_data_viewer.png)

**Features shown:**
- CLAIMS table with 3,142 records
- 27 columns including standard metadata
- Data from 3 unique source files
- Sample data display with pagination
- Download as CSV option
- Filter and search capabilities

### Field Mapper
![Silver Field Mapper](silver_field_mapper.png)

**Features shown:**
- Source data availability (5,095 rows)
- Three mapping methods: Manual, ML, LLM
- View existing mappings
- Mapping status indicators (Pending/Approved/Duplicate)
- Approval workflow
- Confidence scores

## Screenshot Details

| Screenshot | Application | Tab/Section | Date Captured |
|------------|-------------|-------------|---------------|
| `bronze_processing_status.png` | Bronze Ingestion Pipeline | Processing Status | 2026-01-05 |
| `bronze_upload_files.png` | Bronze Ingestion Pipeline | Upload Files | 2026-01-05 |
| `silver_data_viewer.png` | Silver Transformation Manager | Data Viewer | 2026-01-05 |
| `silver_field_mapper.png` | Silver Transformation Manager | Field Mapper | 2026-01-05 |

## Usage in Documentation

These screenshots are referenced in:
- [Main README](../../README.md) - Application Screenshots section
- [Complete User Guide](../USER_GUIDE.md) - Throughout the guide
- [Bronze README](../../bronze/README.md) - Bronze layer documentation
- [Silver README](../../silver/README.md) - Silver layer documentation

## Updating Screenshots

To update screenshots:

1. **Access the Applications:**
   - Bronze: Snowsight → Streamlit → `BRONZE_INGESTION_PIPELINE`
   - Silver: Snowsight → Streamlit → `SILVER_TRANSFORMATION_MANAGER`

2. **Capture Screenshots:**
   - Use browser screenshot tools or Chrome DevTools
   - Ensure full viewport is visible
   - Use PNG format for best quality
   - Capture at standard resolution (1920x1080 recommended)

3. **Save Files:**
   - Use descriptive names (e.g., `bronze_processing_status.png`)
   - Save to this directory
   - Update this README with new screenshots

4. **Update Documentation:**
   - Update references in relevant documentation
   - Update the table above with new details
   - Commit changes with clear message

## Screenshot Guidelines

### What to Include
- ✅ Clear, readable text
- ✅ Representative data (sample or test data)
- ✅ Key features and functionality
- ✅ Typical use cases
- ✅ Success states (not error states)

### What to Avoid
- ❌ Personal or sensitive information
- ❌ Production data
- ❌ Error states (unless for troubleshooting docs)
- ❌ Blurry or low-resolution images
- ❌ Cropped or incomplete views

## Technical Details

**Format:** PNG  
**Resolution:** 1920x1080 (or similar)  
**Color Depth:** 24-bit  
**Compression:** Standard PNG compression  
**File Size:** Typically 100-500 KB per screenshot  

## Accessibility

All screenshots should have:
- Descriptive alt text in markdown
- Clear captions explaining what is shown
- Context provided in surrounding documentation
- Text descriptions of key features

---

**Last Updated:** January 5, 2026  
**Total Screenshots:** 4  
**Applications Covered:** Bronze Ingestion Pipeline, Silver Transformation Manager  
**Status:** ✅ Current and Representative




