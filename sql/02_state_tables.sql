-- =============================================================================
-- School Assignment Sync | 02_state_tables.sql
-- Tables that hold data. Deployed by runbooks/deploy.md via EXECUTE IMMEDIATE FROM.
--
-- RULES
--   * CREATE TABLE IF NOT EXISTS only. Never use the "or replace" form for a
--     table here: every deploy would silently reset MODE to SHADOW, clear
--     scope, and wipe logs.
--   * Unqualified names only. The file runs in the session's current schema.
--   * Seed rows are guarded so they insert only into an empty table.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FANOUT_CONFIG: guardrails read by RECONCILE_FANOUT on every run
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS FANOUT_CONFIG (
    SETTING  VARCHAR(40),
    VALUE    VARCHAR(200),
    NOTES    VARCHAR(400)
);

INSERT INTO FANOUT_CONFIG (SETTING, VALUE, NOTES)
SELECT s, val, n FROM VALUES
    ('MODE',       'SHADOW', 'SHADOW = log only, no writes. LIVE = writes to Asana.'),
    ('MAX_WRITES', '200',    'Run aborts above this. Raise deliberately.'),
    ('PAUSED',     'FALSE',  'TRUE = skip everything. Kill switch.') AS v(s, val, n)
WHERE NOT EXISTS (SELECT 1 FROM FANOUT_CONFIG);

-- -----------------------------------------------------------------------------
-- Remaining state tables: exported from the sandbox
-- -----------------------------------------------------------------------------
-- Paste the rows produced by tools/export_sandbox_ddl.sql where TARGET_FILE is
-- 'sql/02_state_tables.sql' (the export already rewrites them to
-- CREATE TABLE IF NOT EXISTS and strips sandbox qualifiers). Expected objects:
--   FANOUT_SCOPE             in-scope projects (PROJECT_GID, PROJECT_NAME, IS_ENABLED, NOTES)
--   FANOUT_SCOPE_PORTFOLIO   portfolio-level scope, if present in the sandbox
--   FANOUT_RUN_LOG           per-run and per-write log, used for audit and rollback
--   ASANA_USER_MAP           rep email to Asana user ID
--   MASTER_STATE             intended state from the School Assignment Sheet
--   ACTUAL_STATE             actual role-field values on in-scope project tasks
-- Do NOT include FANOUT_CONFIG again, ASANA_USER_MAP_STG (transient, created
-- and dropped by LOAD_ASANA_USER_MAP), or test tables (ZZ_*).
--
-- TODO-EXPORT: paste exported CREATE TABLE IF NOT EXISTS statements below, then delete this line.

