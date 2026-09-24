-- =============================================================================
-- School Assignment Sync | tools/verify_deployment.sql
-- Run after every deploy (runbooks/deploy.md, Verify) as the service role.
-- Replace the role and schema placeholders with your decided values.
-- =============================================================================

USE ROLE <SYNC_ROLE>;
USE SCHEMA <PROD_DB>.<SCHEMA>;

-- 1. Scheduler and alert are running (state = started)
SHOW TASKS  LIKE 'TASK_RECONCILE_FANOUT';
SHOW ALERTS LIKE 'ALERT_FANOUT_FAILURE';

-- 2. Guardrails are what you expect (a deploy must never change these)
SELECT SETTING, VALUE FROM FANOUT_CONFIG ORDER BY SETTING;

-- 3. Scope: only intended projects enabled
SELECT IS_ENABLED, COUNT(*) AS PROJECTS FROM FANOUT_SCOPE GROUP BY IS_ENABLED;
SELECT PROJECT_NAME FROM FANOUT_SCOPE WHERE IS_ENABLED AND PROJECT_NAME ILIKE ANY ('%test%', '%zz%', '%alameda%');  -- expect 0 rows

-- 4. All expected objects exist
SHOW PROCEDURES LIKE '%FANOUT%';
SHOW PROCEDURES LIKE '%ASANA%';
SHOW PROCEDURES LIKE 'REFRESH_MASTER_STATE';
SHOW PROCEDURES LIKE 'DISCOVER_TARGETS';
SHOW VIEWS LIKE 'V\\_%';

-- 5. No object still points at the sandbox (expect 0 rows each)
SELECT PROCEDURE_NAME FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = CURRENT_SCHEMA() AND PROCEDURE_DEFINITION ILIKE '%BA_MLARSEN%';
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = CURRENT_SCHEMA() AND VIEW_DEFINITION ILIKE '%BA_MLARSEN%';

-- 6. Repo object is current
SHOW GIT BRANCHES IN PMO_SYNC_REPO;

-- 7. Recent runs
SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, RETURN_VALUE, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'TASK_RECONCILE_FANOUT', RESULT_LIMIT => 10))
ORDER BY SCHEDULED_TIME DESC;
