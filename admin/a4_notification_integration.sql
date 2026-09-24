-- =============================================================================
-- School Assignment Sync | admin/a4_notification_integration.sql
-- RUN ONCE. Email channel used by ALERT_FANOUT_FAILURE (sql/07_alerts.sql).
-- Recipients must be Snowflake users with VERIFIED email addresses.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE NOTIFICATION INTEGRATION IF NOT EXISTS PMO_SYNC_EMAIL
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<ALERT_RECIPIENT_1>', '<ALERT_RECIPIENT_2>')
  COMMENT = 'School Assignment Sync failure alerts';

GRANT USAGE ON INTEGRATION PMO_SYNC_EMAIL TO ROLE <SYNC_ROLE>;

-- Verify delivery (run as the service role)
USE ROLE <SYNC_ROLE>;
CALL SYSTEM$SEND_EMAIL('PMO_SYNC_EMAIL', '<ALERT_RECIPIENT_1>',
  'School Assignment Sync: test alert', 'If you received this, failure alerts can reach you.');

-- To change recipients later:
--   ALTER NOTIFICATION INTEGRATION PMO_SYNC_EMAIL SET ALLOWED_RECIPIENTS = ('...', '...');
--   and update the recipient string in sql/07_alerts.sql, then redeploy it.
