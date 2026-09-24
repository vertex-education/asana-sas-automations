-- =============================================================================
-- School Assignment Sync | 07_alerts.sql
-- Emails maintainers if the nightly run FAILED, was CANCELLED, or DID NOT RUN
-- (no successful run in the last 24 hours, e.g. the task was left suspended).
-- Deployed by runbooks/deploy.md. Requires notification integration
-- PMO_SYNC_EMAIL (admin/a4_notification_integration.sql).
--
-- Before first merge: replace the warehouse and recipient placeholders
-- (README > Configuration). Recipients must be verified Snowflake users and
-- listed in the integration's ALLOWED_RECIPIENTS. Separate multiple
-- addresses with commas inside the single quoted string.
-- =============================================================================

CREATE OR REPLACE ALERT ALERT_FANOUT_FAILURE
  WAREHOUSE = <WAREHOUSE>
  SCHEDULE  = 'USING CRON 0 6 * * * America/Phoenix'   -- two hours after the nightly run
  IF (EXISTS (
      SELECT 1
      FROM (
          SELECT COUNT_IF(STATE IN ('FAILED', 'CANCELLED')) AS N_BAD,
                 COUNT_IF(STATE = 'SUCCEEDED')              AS N_OK
          FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
              TASK_NAME                  => 'TASK_RECONCILE_FANOUT',
              SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP())))
      )
      WHERE N_BAD > 0 OR N_OK = 0
      -- Open item: if RUN_FANOUT returns (not raises) an abort message when the
      -- delta exceeds MAX_WRITES, add a condition on RETURN_VALUE with the exact
      -- abort text, or change RUN_FANOUT to RAISE. See sql/04 header.
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'PMO_SYNC_EMAIL',
      '<ALERT_RECIPIENTS>',
      'School Assignment Sync: nightly run failed or did not run',
      'TASK_RECONCILE_FANOUT had a failed/cancelled run, or no successful run, in the last 24 hours. '
      || 'Check TASK_HISTORY and FANOUT_RUN_LOG. Runbook: asana-sas-automations/runbooks/operations.md');

-- REQUIRED: alerts are created suspended.
ALTER ALERT ALERT_FANOUT_FAILURE RESUME;
