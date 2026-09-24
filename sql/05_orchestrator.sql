-- =============================================================================
-- School Assignment Sync | 05_orchestrator.sql
-- RECONCILE_FANOUT(): the single entry point the nightly task calls.
-- Deployed by runbooks/deploy.md.
--
-- Behavior (as of the 2026-09-15 sandbox version):
--   1. PAUSED = 'TRUE'  -> returns 'PAUSED - no action taken.'
--   2. Reads MODE and MAX_WRITES from FANOUT_CONFIG
--   3. CALL REFRESH_MASTER_STATE(); CALL DISCOVER_TARGETS();
--   4. 0 rows in V_FANOUT_DELTA -> returns 'In sync. 0 changes. | ...'
--   5. MODE = 'LIVE' -> RUN_FANOUT(FALSE, NULL, max_writes)
--      otherwise     -> RUN_FANOUT(TRUE,  NULL, max_writes)   (dry run / SHADOW)
--   6. Returns 'MODE | run_fanout result | discover result'
--
-- Export the CURRENT sandbox definition rather than retyping this summary;
-- the export is the record of what actually runs.
-- =============================================================================

-- TODO-EXPORT: paste the row from tools/export_sandbox_ddl.sql where TARGET_FILE is 'sql/05_orchestrator.sql', then delete this line.

