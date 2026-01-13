-- =================================================================
-- DATABASE RBAC COMPLETE SETUP SCRIPT
-- =================================================================
-- This consolidated script creates a 3-tier role hierarchy for
-- database access control and grants appropriate privileges
-- 
-- Role Hierarchy:
--   <DBNAME>_ADMIN (Full administrative access)
--       ↓ inherits
--   <DBNAME>_READWRITE (Read and write access)
--       ↓ inherits
--   <DBNAME>_READONLY (Read-only access)
-- 
-- Role Requirements:
--   - SECURITYADMIN or USERADMIN: For creating roles
--   - SYSADMIN: For creating database and granting privileges
-- =================================================================

-- =================================================================
-- CONFIGURATION - CHANGE THIS
-- =================================================================

SET database_name = 'db_ingest_pipeline';  -- CHANGE THIS TO YOUR DATABASE NAME
SET schema_name = 'BRONZE';  -- CHANGE THIS TO YOUR DATABASE NAME
-- =================================================================
-- SECTION 1: Create Role Hierarchy (Use SECURITYADMIN)
-- =================================================================

USE ROLE SECURITYADMIN;

-- Build role and schema names
SET role_admin = (SELECT $database_name || '_ADMIN');
SET role_readwrite = (SELECT $database_name || '_READWRITE');
SET role_readonly = (SELECT $database_name || '_READONLY');
SET schema_public = (SELECT $database_name || '.PUBLIC');

-- Create roles
SET sql_cmd = (SELECT 'CREATE ROLE IF NOT EXISTS ' || $role_admin);
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'CREATE ROLE IF NOT EXISTS ' || $role_readwrite);
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'CREATE ROLE IF NOT EXISTS ' || $role_readonly);
EXECUTE IMMEDIATE $sql_cmd;

-- Add comments to roles
SET sql_cmd = (SELECT 'ALTER ROLE ' || $role_admin || ' SET COMMENT = ''Administrator role for ' || $database_name || ' database''');
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'ALTER ROLE ' || $role_readwrite || ' SET COMMENT = ''Read-Write role for ' || $database_name || ' database''');
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'ALTER ROLE ' || $role_readonly || ' SET COMMENT = ''Read-Only role for ' || $database_name || ' database''');
EXECUTE IMMEDIATE $sql_cmd;

-- Establish role hierarchy
SET sql_cmd = (SELECT 'GRANT ROLE ' || $role_readonly || ' TO ROLE ' || $role_readwrite);
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'GRANT ROLE ' || $role_readwrite || ' TO ROLE ' || $role_admin);
EXECUTE IMMEDIATE $sql_cmd;

-- Grant Admin role to SYSADMIN for management
SET sql_cmd = (SELECT 'GRANT ROLE ' || $role_admin || ' TO ROLE SYSADMIN');
EXECUTE IMMEDIATE $sql_cmd;

-- Grant CREATE STREAMLIT privilege to ADMIN role (for Streamlit app deployment)
SET sql_cmd = (SELECT 'GRANT CREATE STREAMLIT ON SCHEMA ' || $database_name || '.PUBLIC TO ROLE ' || $role_admin);
EXECUTE IMMEDIATE $sql_cmd;

-- =================================================================
-- SECTION 2: Create Database and Schema (Use SYSADMIN)
-- =================================================================

USE ROLE SYSADMIN;

-- Create database
SET sql_cmd = (SELECT 'CREATE DATABASE IF NOT EXISTS ' || $database_name);
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'USE DATABASE ' || $database_name);
EXECUTE IMMEDIATE $sql_cmd;

USE DATABASE IDENTIFIER($database_name);

CREATE SCHEMA IF NOT EXISTS PUBLIC;

-- Grant database ownership to Admin role
SET sql_cmd = (SELECT 'GRANT OWNERSHIP ON DATABASE ' || $database_name || ' TO ROLE ' || $role_admin || ' COPY CURRENT GRANTS');
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'GRANT OWNERSHIP ON SCHEMA ' || $database_name || '.PUBLIC TO ROLE ' || $role_admin || ' COPY CURRENT GRANTS');
EXECUTE IMMEDIATE $sql_cmd;

-- Grant database and schema usage to lower roles
GRANT USAGE ON DATABASE IDENTIFIER($database_name) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT USAGE ON DATABASE IDENTIFIER($database_name) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT USAGE ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT USAGE ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

-- =================================================================
-- SECTION 3: Grant ReadOnly Privileges
-- =================================================================

-- SELECT on all existing tables and views
GRANT SELECT ON ALL TABLES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT SELECT ON ALL VIEWS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

-- SELECT on all future tables and views
GRANT SELECT ON FUTURE TABLES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT SELECT ON FUTURE VIEWS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT SELECT ON FUTURE MATERIALIZED VIEWS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

-- USAGE on functions and procedures
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT USAGE ON ALL PROCEDURES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

-- READ on stages
GRANT READ ON ALL STAGES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT READ ON FUTURE STAGES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

-- USAGE on file formats
GRANT USAGE ON ALL FILE FORMATS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

-- MONITOR on tasks only (MONITOR is not valid for streams)
GRANT MONITOR ON ALL TASKS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT MONITOR ON FUTURE TASKS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

-- SELECT on streams (for reading stream data)
GRANT SELECT ON ALL STREAMS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

GRANT SELECT ON FUTURE STREAMS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readonly);

-- =================================================================
-- SECTION 4: Grant ReadWrite Privileges
-- =================================================================

-- DML on all existing and future tables
GRANT INSERT, UPDATE, DELETE, TRUNCATE 
    ON ALL TABLES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT INSERT, UPDATE, DELETE, TRUNCATE 
    ON FUTURE TABLES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

-- READ and WRITE on stages (must grant together or READ first)
GRANT READ, WRITE ON ALL STAGES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT READ, WRITE ON FUTURE STAGES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

-- CREATE privileges on schema
GRANT CREATE TABLE ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT CREATE VIEW ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT CREATE STAGE ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT CREATE FILE FORMAT ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT CREATE SEQUENCE ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT CREATE FUNCTION ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT CREATE PROCEDURE ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

-- OPERATE on tasks
GRANT OPERATE ON ALL TASKS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

GRANT OPERATE ON FUTURE TASKS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_readwrite);

-- =================================================================
-- SECTION 5: Grant Admin Privileges
-- =================================================================

-- CREATE SCHEMA privilege
GRANT CREATE SCHEMA ON DATABASE IDENTIFIER($database_name) 
    TO ROLE IDENTIFIER($role_admin);

-- ALL PRIVILEGES on schema
GRANT ALL PRIVILEGES ON SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

-- ALL PRIVILEGES on all existing objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON ALL VIEWS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON ALL MATERIALIZED VIEWS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON ALL STAGES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON ALL FILE FORMATS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON ALL STREAMS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON ALL TASKS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

-- ALL PRIVILEGES on all future objects
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON FUTURE VIEWS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON FUTURE MATERIALIZED VIEWS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON FUTURE STAGES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON FUTURE FILE FORMATS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON FUTURE SEQUENCES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON FUTURE FUNCTIONS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON FUTURE PROCEDURES IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON FUTURE STREAMS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

GRANT ALL PRIVILEGES ON FUTURE TASKS IN SCHEMA IDENTIFIER($schema_public) 
    TO ROLE IDENTIFIER($role_admin);

-- =================================================================
-- SECTION 6: Grant Role Management Privileges (Use SECURITYADMIN)
-- =================================================================

USE ROLE SECURITYADMIN;

-- Note: WITH ADMIN OPTION is not supported in GRANT ROLE syntax
-- The admin role can manage lower roles through the role hierarchy

-- Switch back to SYSADMIN for database management
USE ROLE SYSADMIN;

-- Database management privileges
GRANT MODIFY, MONITOR ON DATABASE IDENTIFIER($database_name) 
    TO ROLE IDENTIFIER($role_admin);

-- =================================================================
-- SECTION 7: Verification
-- =================================================================

-- Show created roles
SET sql_cmd = (SELECT 'SHOW ROLES LIKE ''' || $database_name || '%''');
EXECUTE IMMEDIATE $sql_cmd;

-- Show role hierarchy
SELECT 
    $role_readonly as role_name,
    'Base Level - Read Only' as level,
    'SELECT on all objects' as privileges
UNION ALL
SELECT 
    $role_readwrite,
    'Middle Level - Read Write',
    'INSERT, UPDATE, DELETE, TRUNCATE + inherits ReadOnly'
UNION ALL
SELECT 
    $role_admin,
    'Top Level - Admin',
    'CREATE, DROP, ALTER, OWNERSHIP + inherits ReadWrite';

-- Show grants to each role
SET sql_cmd = (SELECT 'SHOW GRANTS TO ROLE ' || $role_readonly);
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'SHOW GRANTS TO ROLE ' || $role_readwrite);
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'SHOW GRANTS TO ROLE ' || $role_admin);
EXECUTE IMMEDIATE $sql_cmd;

-- Show database and schema details
SET sql_cmd = (SELECT 'SHOW DATABASES LIKE ''' || $database_name || '''');
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'SHOW GRANTS ON DATABASE ' || $database_name);
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'SHOW GRANTS ON SCHEMA ' || $database_name || '.PUBLIC');
EXECUTE IMMEDIATE $sql_cmd;

-- =================================================================
-- SECTION 8: User Assignment (Use SECURITYADMIN)
-- =================================================================

-- To grant roles to users, use SECURITYADMIN
-- Uncomment and modify as needed:

/*
USE ROLE SECURITYADMIN;

SET sql_cmd = (SELECT 'GRANT ROLE ' || $role_readonly || ' TO USER analyst_user');
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'GRANT ROLE ' || $role_readwrite || ' TO USER data_engineer');
EXECUTE IMMEDIATE $sql_cmd;

SET sql_cmd = (SELECT 'GRANT ROLE ' || $role_admin || ' TO USER database_admin');
EXECUTE IMMEDIATE $sql_cmd;
*/

-- =================================================================
-- SECTION 9: Testing (Optional - Uncomment to Test)
-- =================================================================

/*
-- Test ReadOnly access
SET sql_cmd = (SELECT 'USE ROLE ' || $role_readonly);
EXECUTE IMMEDIATE $sql_cmd;
USE DATABASE IDENTIFIER($database_name);
SELECT CURRENT_ROLE() as role, CURRENT_DATABASE() as database;
-- CREATE TABLE test (id INT);  -- Should fail

-- Test ReadWrite access
SET sql_cmd = (SELECT 'USE ROLE ' || $role_readwrite);
EXECUTE IMMEDIATE $sql_cmd;
CREATE TABLE test_table (id INT, name VARCHAR(100));
INSERT INTO test_table VALUES (1, 'Test');
SELECT * FROM test_table;
-- ALTER TABLE test_table ADD COLUMN email VARCHAR(255);  -- Should fail
DROP TABLE test_table;

-- Test Admin access
SET sql_cmd = (SELECT 'USE ROLE ' || $role_admin);
EXECUTE IMMEDIATE $sql_cmd;
CREATE TABLE admin_test (id INT);
ALTER TABLE admin_test ADD COLUMN name VARCHAR(100);
DROP TABLE admin_test;
CREATE SCHEMA test_schema;
DROP SCHEMA test_schema;
*/

-- =================================================================
-- SETUP COMPLETE
-- =================================================================

SELECT 
    '✓ RBAC Setup Complete!' as status,
    $database_name as database_name,
    $role_readonly as readonly_role,
    $role_readwrite as readwrite_role,
    $role_admin as admin_role,
    'Roles created by: SECURITYADMIN' as role_creation,
    'Database/Grants by: SYSADMIN' as database_creation;
