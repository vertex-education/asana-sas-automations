-- =============================================================================
-- School Assignment Sync | admin/a5_retire_sandbox.sql
-- RUN AFTER production is LIVE and its first LIVE run is verified in Asana.
-- Goal: one scheduler, no personal credentials.
-- =============================================================================

-- 1. Stop the sandbox scheduler (never let sandbox and production both run LIVE)
USE ROLE <SANDBOX_OWNER_ROLE>;          -- the role that owns the sandbox task (e.g. BA_SCHEMA_ADMIN)
ALTER TASK MART_DB.BA_MLARSEN.TASK_RECONCILE_FANOUT SUSPEND;
SHOW TASKS LIKE 'TASK_RECONCILE_FANOUT' IN SCHEMA MART_DB.BA_MLARSEN;   -- expect state = suspended

-- 2. Remove sandbox entries from the shared Asana integration
USE ROLE ACCOUNTADMIN;
ALTER EXTERNAL ACCESS INTEGRATION ASANA_API_INTEGRATION SET
  ALLOWED_NETWORK_RULES = (<PROD_DB>.<SCHEMA>.ASANA_API_RULE)
  ALLOWED_AUTHENTICATION_SECRETS = (<PROD_DB>.<SCHEMA>.ASANA_PAT);
DESCRIBE EXTERNAL ACCESS INTEGRATION ASANA_API_INTEGRATION;             -- production entries only

-- 3. Manual follow-ups (not SQL)
--   * Revoke the maintainer's personal Asana PAT in Asana.
--   * Keep sandbox objects 30 days as a fallback, then drop with PMO sponsor approval:
--       DROP TASK MART_DB.BA_MLARSEN.TASK_RECONCILE_FANOUT;   (and the other sandbox objects)
--   * Update CHANGELOG.md and README > Status.
--   * Update the end-user SOP / help article to name the production owner.
