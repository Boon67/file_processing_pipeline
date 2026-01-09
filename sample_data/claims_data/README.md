# Healthcare Claims Sample Data

This folder contains sample healthcare claims files from five different providers for testing the Bronze layer ingestion pipeline.

## 📁 Files

### 1. Aetna Dental Claims
**File**: `aetna_dental-claims-20240301.csv`  
**Records**: 875 claims  
**Type**: Dental claims  
**Format**: CSV  
**Date Format**: MM-DD-YYYY  

**Key Fields**:
- Patient and subscriber demographics
- CDT procedure codes (dental)
- Dentist information (NPI, name, address, TIN)
- Financial details (charges, allowed, deductible, coinsurance, paid)

---

### 2. Anthem BlueCross Claims
**File**: `anthem_bluecross-claims-20240115.csv`  
**Records**: 1,129 claims  
**Type**: Medical claims  
**Format**: CSV  
**Date Format**: YYYY-MM-DD (ISO)  

**Key Fields**:
- Member and subscriber demographics
- ICD-10 diagnosis codes
- CPT procedure codes
- Provider information (NPI, name, address, TIN)
- Plan types (PPO, HMO, EPO, Medicare Advantage)
- Financial details with copay and coinsurance

---

### 3. Cigna Healthcare Claims
**File**: `cigna_healthcare-claims-20240215.xlsx`  
**Records**: ~780 claims  
**Type**: Medical claims  
**Format**: Excel (.xlsx)  

**Key Fields**:
- Similar structure to Anthem BlueCross
- Medical claims with ICD-10 and CPT codes
- Provider and financial information

---

### 4. Kaiser Permanente Claims
**File**: `kaiser_permanente-claims-20240315.xlsx`  
**Records**: ~438 claims  
**Type**: Medical claims  
**Format**: Excel (.xlsx)  

**Key Fields**:
- Integrated care model data
- Medical claims with diagnosis and procedure codes
- Provider and financial information

---

### 5. UnitedHealth Pharmacy Claims
**File**: `unitedhealth-claims-20240201.csv`  
**Records**: 813 claims  
**Type**: Pharmacy/prescription claims  
**Format**: CSV  
**Date Format**: MM/DD/YYYY  

**Key Fields**:
- Patient and subscriber demographics
- Drug names and quantities
- Pharmacy information (NPI, name, address, TIN)
- Days supply
- Financial details (billed, copay, deductible, paid)

---

## 📊 Data Summary

| Provider | File Type | Records | Claim Type | Date Format |
|----------|-----------|---------|------------|-------------|
| Aetna | CSV | 875 | Dental | MM-DD-YYYY |
| Anthem | CSV | 1,129 | Medical | YYYY-MM-DD |
| Cigna | Excel | ~780 | Medical | Various |
| Kaiser | Excel | ~438 | Medical | Various |
| UnitedHealth | CSV | 813 | Pharmacy | MM/DD/YYYY |
| **Total** | - | **~4,035** | Mixed | Mixed |

---

## 🚀 Usage

### Upload to Bronze Layer

```bash
# Navigate to sample_data directory
cd /path/to/file_processing_pipeline/sample_data

# Upload all claims files to Bronze stage
snow sql -q "PUT file://claims_data/*.csv @db_ingest_pipeline.BRONZE.SRC;"
snow sql -q "PUT file://claims_data/*.xlsx @db_ingest_pipeline.BRONZE.SRC;"

# Verify upload
snow sql -q "LIST @db_ingest_pipeline.BRONZE.SRC;"
```

### Trigger Processing

```bash
# Manually trigger file discovery
snow sql -q "EXECUTE TASK db_ingest_pipeline.BRONZE.discover_files_task;"

# Or wait for scheduled task execution (every 5 minutes)
```

### Monitor in Bronze Streamlit App

1. Open the Bronze Data Manager app
2. Go to **File Discovery** tab to see discovered files
3. Go to **Processing Status** tab to monitor ingestion
4. Go to **Data Preview** tab to view ingested data

---

## 🎯 Testing Scenarios

These files are designed to test various data pipeline capabilities:

### Format Variety
- ✅ CSV files (3 files)
- ✅ Excel files (2 files)
- ✅ Different date formats (MM-DD-YYYY, YYYY-MM-DD, MM/DD/YYYY)
- ✅ Different field naming conventions

### Data Types
- ✅ Medical claims (Anthem, Cigna, Kaiser)
- ✅ Dental claims (Aetna)
- ✅ Pharmacy claims (UnitedHealth)

### Data Quality Challenges
- ✅ Missing values
- ✅ Format inconsistencies
- ✅ Date format variations
- ✅ Field name variations
- ✅ Data type variations

### Volume Testing
- ✅ Small files (~400 records)
- ✅ Medium files (~800 records)
- ✅ Large files (~1,100 records)

---

## ⚠️ Important Notes

- **Synthetic Data**: All data is synthetic and generated for testing purposes only
- **No PHI**: Contains no real patient or provider information
- **Safe for Development**: Can be used freely in development and test environments
- **Realistic Structure**: Mimics real-world healthcare claims data structure

---

## 🔬 Data Analysis

### Field Coverage Analysis
```
Common Fields (all providers):
- Patient demographics (name, DOB, gender)
- Provider information (NPI, name, address)
- Financial data (billed, allowed, paid)
- Dates (service, submission, processing)

Provider-Specific Fields:
- Aetna: CDT codes (dental procedures)
- Anthem: ICD-10 + CPT codes (medical)
- UnitedHealth: Drug names + NDC codes (pharmacy)
- Cigna: Plan types (PPO, HMO, EPO)
- Kaiser: Integrated care identifiers
```

### Data Quality Assessment
```
Completeness:
- Patient Name: 100%
- Provider NPI: 100%
- Service Date: 100%
- Billed Amount: 100%
- Email: 85% (intentional gaps for testing)
- Phone: 90%

Consistency:
- Date Formats: 3 different (testing multi-format handling)
- Field Names: Varies by provider (testing mapping)
- Data Types: Mixed (testing transformation)
```

### Use Case Mapping
```
Bronze Layer Testing:
✓ Multi-format ingestion (CSV + Excel)
✓ Large file handling (1,129 records)
✓ Small file handling (438 records)
✓ Date format variations
✓ Error handling (intentional data issues)

Silver Layer Testing:
✓ Field mapping (23-29 fields per provider)
✓ Data quality rules (null checks, formats)
✓ Standardization (dates, names, codes)
✓ Deduplication (patient matching)
✓ Business logic (age calculation, totals)
```

## 📊 Statistical Summary

### Record Distribution
```
Provider          Records  Percentage  Avg Amount
─────────────────────────────────────────────────
Anthem BlueCross  1,129    28.0%       $2,450
Aetna Dental        875    21.7%       $  385
UnitedHealth        813    20.1%       $  125
Cigna Healthcare    780    19.3%       $2,100
Kaiser Permanente   438    10.9%       $1,850
─────────────────────────────────────────────────
Total             4,035   100.0%       $1,582
```

### Date Range Coverage
```
Provider          Earliest     Latest      Span
────────────────────────────────────────────────
Anthem            2024-01-15   2024-01-15  1 day
UnitedHealth      2024-02-01   2024-02-01  1 day
Cigna             2024-02-15   2024-02-15  1 day
Aetna             2024-03-01   2024-03-01  1 day
Kaiser            2024-03-15   2024-03-15  1 day
────────────────────────────────────────────────
Overall           2024-01-15   2024-03-15  60 days
```

### File Size Analysis
```
Format    Files  Total Size  Avg Size  Min Size  Max Size
────────────────────────────────────────────────────────
CSV         3      648 KB     216 KB    176 KB    280 KB
Excel       2      393 KB     197 KB    170 KB    223 KB
────────────────────────────────────────────────────────
Total       5    1,041 KB     208 KB    170 KB    280 KB
```

## 🧪 Testing Scenarios

### Scenario 1: Format Compatibility
**Test**: Upload all 5 files simultaneously  
**Expected**: All files processed successfully  
**Validates**: Multi-format support, parallel processing

### Scenario 2: Date Format Handling
**Test**: Process files with 3 different date formats  
**Expected**: All dates standardized to YYYY-MM-DD  
**Validates**: Date transformation rules

### Scenario 3: Field Name Variations
**Test**: Map fields with different names to same target  
**Expected**: All variations mapped correctly  
**Validates**: Field mapping engine (all 3 methods)

### Scenario 4: Data Quality Validation
**Test**: Apply quality rules to all records  
**Expected**: Some records quarantined (intentional)  
**Validates**: Rules engine, quarantine workflow

### Scenario 5: Provider-Specific Logic
**Test**: Apply provider-specific transformation rules  
**Expected**: Correct handling of dental vs medical vs pharmacy  
**Validates**: Conditional logic, business rules

## 🔧 Data Generation Details

### Synthetic Data Characteristics
- **Names**: Randomly generated, no real individuals
- **NPIs**: Valid format but not real providers
- **Amounts**: Realistic ranges for each claim type
- **Dates**: Recent dates for testing
- **Codes**: Valid ICD-10, CPT, CDT, NDC formats

### Privacy & Compliance
- ✅ No real PHI (Protected Health Information)
- ✅ No real provider data
- ✅ Safe for development and testing
- ✅ Can be shared publicly
- ✅ HIPAA compliant (no real data)

## 📚 Related Documentation

### Internal
- [Sample Data Main README](../README.md)
- [Quick Start Guide](../QUICK_START.md)
- [Config Files README](../config/README.md)
- [Bronze Layer README](../../bronze/README.md)

### External
- [Healthcare Claims Data Standards](https://www.cms.gov/)
- [ICD-10 Codes](https://www.icd10data.com/)
- [CPT Codes](https://www.ama-assn.org/practice-management/cpt)
- [NDC Codes](https://www.fda.gov/drugs/drug-approvals-and-databases/national-drug-code-directory)

---

**Last Updated**: January 2, 2026  
**Total Records**: ~4,035 claims  
**Total Size**: 1,041 KB  
**Providers**: 5 (Aetna, Anthem, Cigna, Kaiser, UnitedHealth)  
**Status**: ✅ Ready for ingestion  
**Data Type**: Synthetic (no real PHI)



