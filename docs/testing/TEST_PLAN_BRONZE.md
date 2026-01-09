# Bronze Layer Test Plan

Comprehensive testing strategy for the Bronze layer file ingestion pipeline.

## 🎯 Test Objectives

1. Validate all components deploy successfully
2. Verify file discovery and processing workflows
3. Test error handling and recovery
4. Validate task automation and dependencies
5. Ensure data quality and integrity
6. Test Streamlit UI functionality
7. Verify RBAC and security
8. Performance and scalability testing

## 📋 Test Categories

### 1. Deployment Tests
### 2. Component Tests
### 3. Integration Tests
### 4. End-to-End Tests
### 5. Error Handling Tests
### 6. Performance Tests
### 7. Security Tests
### 8. UI Tests

---

## 1. DEPLOYMENT TESTS

### Test 1.1: Fresh Deployment
**Objective**: Verify clean deployment on new environment

**Prerequisites**: None

**Steps**:
```bash
./deploy.sh
```

**Expected Results**:
- ✅ Database `db_ingest_pipeline` created
- ✅ Schema `BRONZE` created
- ✅ 3 roles created (`_ADMIN`, `_READWRITE`, `_READONLY`)
- ✅ 6 stages created
- ✅ 2 tables created
- ✅ 4 stored procedures created
- ✅ 5 tasks created (suspended state)
- ✅ Streamlit app deployed
- ✅ All permissions granted
- ✅ Exit code 0

**Validation SQL**:
```sql
-- Check database
SHOW DATABASES LIKE 'db_ingest_pipeline';

-- Check schema
SHOW SCHEMAS IN DATABASE db_ingest_pipeline;

-- Check roles
SHOW ROLES LIKE 'db_ingest_pipeline%';

-- Check stages
SELECT COUNT(*) FROM INFORMATION_SCHEMA.STAGES 
WHERE STAGE_SCHEMA = 'BRONZE';  -- Should be 6

-- Check tables
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'BRONZE';  -- Should be 2

-- Check procedures
SELECT COUNT(*) FROM INFORMATION_SCHEMA.PROCEDURES 
WHERE PROCEDURE_SCHEMA = 'BRONZE';  -- Should be 4

-- Check tasks
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TASKS 
WHERE TASK_SCHEMA = 'BRONZE';  -- Should be 5

-- Check Streamlit
SELECT COUNT(*) FROM INFORMATION_SCHEMA.STREAMLITS 
WHERE NAME = 'BRONZE_INGESTION_PIPELINE';  -- Should be 1
```

**Pass Criteria**: All counts match expected values, no errors

---

*[Content continues for all 28 tests...]*

---

**Bronze Layer Test Plan v1.0**
**Last Updated**: December 24, 2025

