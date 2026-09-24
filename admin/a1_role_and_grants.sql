-- =============================================================================
-- School Assignment Sync | admin/a1_role_and_grants.sql
-- RUN ONCE by a Snowflake administrator (SECURITYADMIN + ACCOUNTADMIN).
-- Replace every <PLACEHOLDER> before running. Record values in README > Configuration.
-- =============================================================================

USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS <SYNC_ROLE>
  COMMENT = 'Service role for School Assignment Sync (asana-sas-automations). Owns objects, task, alert.';
GRANT ROLE <SYNC_ROLE> TO ROLE SYSADMIN;          -- keep the role in the hierarchy
GRANT ROLE <SYNC_ROLE> TO USER <OPERATOR_1>;      -- maintainer
GRANT ROLE <SYNC_ROLE> TO USER <OPERATOR_2>;      -- backup maintainer

USE ROLE ACCOUNTADMIN;

-- Scheduler and alert execution
GRANT EXECUTE TASK  ON ACCOUNT TO ROLE <SYNC_ROLE>;
GRANT EXECUTE ALERT ON ACCOUNT TO ROLE <SYNC_ROLE>;

-- Compute
GRANT USAGE ON WAREHOUSE <WAREHOUSE> TO ROLE <SYNC_ROLE>;

-- Production home
GRANT USAGE ON DATABASE <PROD_DB> TO ROLE <SYNC_ROLE>;
GRANT USAGE,
      CREATE TABLE, CREATE VIEW, CREATE PROCEDURE,
      CREATE TASK, CREATE ALERT,
      CREATE SECRET, CREATE NETWORK RULE,
      CREATE GIT REPOSITORY, CREATE STREAMLIT
  ON SCHEMA <PROD_DB>.<SCHEMA> TO ROLE <SYNC_ROLE>;

-- Verify
SHOW GRANTS TO ROLE <SYNC_ROLE>;      -- expect EXECUTE TASK, EXECUTE ALERT, schema privileges
