-- =============================================================================
-- School Assignment Sync | 06_schedule.sql
-- Nightly scheduler. Deployed by runbooks/deploy.md.
--
-- Before first merge: replace the warehouse placeholder with the decided
-- warehouse (README > Configuration). The PR check fails until you do.
--
-- To stop activity WITHOUT a code change, use FANOUT_CONFIG (PAUSED / MODE)
-- or ALTER TASK ... SUSPEND. See runbooks/operations.md.
-- =============================================================================

CREATE OR REPLACE TASK TASK_RECONCILE_FANOUT
  WAREHOUSE = <WAREHOUSE>
  SCHEDULE  = 'USING CRON 0 4 * * * America/Phoenix'   -- 4:00 AM Phoenix (no DST). Confirm with business owner.
  COMMENT   = 'School Assignment Sync nightly reconcile. Source of record: GitHub asana-sas-automations, sql/06_schedule.sql'
AS
  CALL RECONCILE_FANOUT();

-- REQUIRED: CREATE OR REPLACE TASK always leaves the task suspended.
-- Without this line every redeploy silently stops the nightly run.
ALTER TASK TASK_RECONCILE_FANOUT RESUME;
