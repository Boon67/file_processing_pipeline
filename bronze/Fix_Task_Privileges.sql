-- ============================================
-- FIX: Grant EXECUTE TASK Privilege
-- ============================================
-- Purpose: Grant the EXECUTE TASK privilege to the admin role
--          This is required to create and execute tasks
--
-- Error Fixed:
--   091089 (23001): Cannot execute task, EXECUTE TASK privilege 
--   must be granted to owner role
--
-- Prerequisites:
--   - Must be run as ACCOUNTADMIN (one-time setup)
--   - The database and role must already exist
--
-- Strategy:
--   1. Grant EXECUTE TASK to SYSADMIN with GRANT OPTION
--   2. SYSADMIN then grants to custom admin role
--   3. Future deployments can use SYSADMIN without needing ACCOUNTADMIN
-- ============================================

-- Configuration
SET database_name = 'db_ingest_pipeline';  -- CHANGE THIS TO YOUR DATABASE NAME

-- Build role name
SET role_admin = (SELECT $database_name || '_ADMIN');

-- Step 1: Grant EXECUTE TASK privilege to SYSADMIN (requires ACCOUNTADMIN)
-- WITH GRANT OPTION allows SYSADMIN to grant this privilege to other roles
USE ROLE ACCOUNTADMIN;

GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;

-- Step 2: SYSADMIN grants to custom admin role
USE ROLE SYSADMIN;

GRANT EXECUTE TASK ON ACCOUNT TO ROLE IDENTIFIER($role_admin);
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE IDENTIFIER($role_admin);

-- Verify the grants
SHOW GRANTS TO ROLE SYSADMIN;
SHOW GRANTS TO ROLE IDENTIFIER($role_admin);

SELECT 
    '✓ EXECUTE TASK privilege granted!' as status,
    'SYSADMIN can now grant EXECUTE TASK to other roles' as sysadmin_capability,
    $role_admin as custom_role,
    'You can now create and execute tasks with this role' as next_steps;
