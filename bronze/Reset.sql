-- ============================================
-- RESET SCRIPT: Clean Up Database and Roles
-- ============================================
-- Purpose: Removes the COMPASSIQ database and all associated roles
-- Use Case: Complete teardown for fresh reinstall or cleanup
-- WARNING: This will permanently delete all data and configurations
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================
-- Set the base database name
SET database_name = 'db_ingest_pipeline';

-- Dynamically construct role names based on database name
SET role_admin = (SELECT $database_name || '_ADMIN');
SET role_readwrite = (SELECT $database_name || '_READWRITE');
SET role_readonly = (SELECT $database_name || '_READONLY');

-- ============================================
-- DATABASE CLEANUP
-- ============================================

-- Switch to SYSADMIN role (required for database operations)
USE ROLE SYSADMIN;

-- Drop the database and all its schemas, tables, stages, and objects
DROP DATABASE IF EXISTS IDENTIFIER($database_name);

-- ============================================
-- ROLE CLEANUP
-- ============================================

-- Switch to SECURITYADMIN role (required for role operations)
USE ROLE SECURITYADMIN;

-- Drop the admin role (full permissions)
DROP ROLE IF EXISTS IDENTIFIER($role_admin);

-- Drop the read/write role (data modification permissions)
DROP ROLE IF EXISTS IDENTIFIER($role_readwrite);

-- Drop the read-only role (query-only permissions)
DROP ROLE IF EXISTS IDENTIFIER($role_readonly);

