-- =============================================================================
-- School Assignment Sync | tools/export_sandbox_ddl.sql
-- Pulls the CURRENT definitions of every sandbox object so the repo matches
-- what actually runs. Run in a Snowsight worksheet with the sandbox owner role.
--
-- Output: one row per object with TARGET_FILE, OBJECT_TYPE, OBJECT_NAME, DDL.
-- The DDL column is already transformed:
--   * tables:  CREATE OR REPLACE TABLE  ->  CREATE TABLE IF NOT EXISTS
--   * all:     MART_DB.BA_MLARSEN. qualifiers removed
-- Paste each DDL cell into its TARGET_FILE, in the order returned.
-- Full instructions: runbooks/migration-from-sandbox.md, Step 1.
-- =============================================================================

USE ROLE BA_SCHEMA_ADMIN;          -- sandbox owner role; change if different
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA MART_DB.BA_MLARSEN;

-- -----------------------------------------------------------------------------
-- Step A: inventory. Review before exporting. Anything unexpected?
-- -----------------------------------------------------------------------------
SELECT 'TABLE' AS OBJECT_TYPE, TABLE_NAME AS OBJECT_NAME, NULL AS ARGUMENT_SIGNATURE, LAST_ALTERED
FROM MART_DB.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'BA_MLARSEN' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'VIEW', TABLE_NAME, NULL, LAST_ALTERED
FROM MART_DB.INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'BA_MLARSEN'
UNION ALL
SELECT 'PROCEDURE', PROCEDURE_NAME, ARGUMENT_SIGNATURE, LAST_ALTERED
FROM MART_DB.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'BA_MLARSEN'
ORDER BY 1, 2;

-- -----------------------------------------------------------------------------
-- Step B: export DDL
-- -----------------------------------------------------------------------------
EXECUTE IMMEDIATE $$
DECLARE
  c_tables CURSOR FOR
    SELECT TABLE_NAME AS NM FROM MART_DB.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'BA_MLARSEN' AND TABLE_TYPE = 'BASE TABLE'
      AND TABLE_NAME NOT LIKE 'ZZ%' AND TABLE_NAME NOT IN ('ASANA_USER_MAP_STG', 'DDL_EXPORT');
  c_views CURSOR FOR
    SELECT TABLE_NAME AS NM FROM MART_DB.INFORMATION_SCHEMA.VIEWS
    WHERE TABLE_SCHEMA = 'BA_MLARSEN' AND TABLE_NAME NOT LIKE 'ZZ%';
  c_procs CURSOR FOR
    SELECT PROCEDURE_NAME AS NM,
           REGEXP_REPLACE(ARGUMENT_SIGNATURE, '(\\w+) (\\w+)', '\\2') AS ARGTYPES
    FROM MART_DB.INFORMATION_SCHEMA.PROCEDURES
    WHERE PROCEDURE_SCHEMA = 'BA_MLARSEN' AND PROCEDURE_NAME NOT LIKE 'ZZ%';
  stmt STRING;
  res RESULTSET;
BEGIN
  CREATE OR REPLACE TEMPORARY TABLE DDL_EXPORT (OBJECT_TYPE STRING, OBJECT_NAME STRING, DDL STRING);

  FOR t IN c_tables DO
    stmt := 'INSERT INTO DDL_EXPORT SELECT ''TABLE'', ''' || t.NM ||
            ''', GET_DDL(''TABLE'', ''MART_DB.BA_MLARSEN.' || t.NM || ''')';
    EXECUTE IMMEDIATE :stmt;
  END FOR;

  FOR v IN c_views DO
    stmt := 'INSERT INTO DDL_EXPORT SELECT ''VIEW'', ''' || v.NM ||
            ''', GET_DDL(''VIEW'', ''MART_DB.BA_MLARSEN.' || v.NM || ''')';
    EXECUTE IMMEDIATE :stmt;
  END FOR;

  FOR p IN c_procs DO
    stmt := 'INSERT INTO DDL_EXPORT SELECT ''PROCEDURE'', ''' || p.NM ||
            ''', GET_DDL(''PROCEDURE'', ''MART_DB.BA_MLARSEN.' || p.NM || p.ARGTYPES || ''')';
    EXECUTE IMMEDIATE :stmt;
  END FOR;

  res := (
    SELECT
      CASE
        WHEN OBJECT_TYPE = 'TABLE' AND OBJECT_NAME = 'FANOUT_CONFIG'
          THEN 'ALREADY IN sql/02 (compare only, do not paste)'
        WHEN OBJECT_TYPE = 'TABLE' AND OBJECT_NAME IN
             ('FANOUT_SCOPE', 'FANOUT_SCOPE_PORTFOLIO', 'FANOUT_RUN_LOG', 'ASANA_USER_MAP', 'MASTER_STATE', 'ACTUAL_STATE')
          THEN 'sql/02_state_tables.sql'
        WHEN OBJECT_TYPE = 'PROCEDURE' AND OBJECT_NAME IN ('LOAD_ASANA_USER_MAP', 'REFRESH_MASTER_STATE', 'DISCOVER_TARGETS')
          THEN 'sql/03_read_asana.sql'
        WHEN OBJECT_TYPE = 'VIEW' AND OBJECT_NAME IN ('V_FANOUT_DELTA', 'V_FANOUT_PREVIEW', 'V_UNRESOLVED_REPS')
          THEN 'sql/04_diff_write_rollback.sql'
        WHEN OBJECT_TYPE = 'PROCEDURE' AND OBJECT_NAME IN ('RUN_FANOUT', 'ROLLBACK_FANOUT')
          THEN 'sql/04_diff_write_rollback.sql'
        WHEN OBJECT_TYPE = 'PROCEDURE' AND OBJECT_NAME = 'RECONCILE_FANOUT'
          THEN 'sql/05_orchestrator.sql'
        ELSE 'REVIEW: not mapped (add to the right file, or leave in sandbox)'
      END AS TARGET_FILE,
      OBJECT_TYPE,
      OBJECT_NAME,
      REGEXP_REPLACE(
        CASE WHEN OBJECT_TYPE = 'TABLE'
             THEN REGEXP_REPLACE(DDL, '^\\s*create or replace (transient )?table', 'CREATE \\1TABLE IF NOT EXISTS', 1, 1, 'i')
             ELSE DDL END,
        '("?MART_DB"?\\.)?"?BA_MLARSEN"?\\.', '', 1, 0, 'i') AS DDL
    FROM DDL_EXPORT
    ORDER BY
      TARGET_FILE,
      CASE OBJECT_TYPE WHEN 'TABLE' THEN 1 WHEN 'VIEW' THEN 2 ELSE 3 END,
      CASE OBJECT_NAME
        WHEN 'LOAD_ASANA_USER_MAP' THEN 1 WHEN 'REFRESH_MASTER_STATE' THEN 2 WHEN 'DISCOVER_TARGETS' THEN 3
        WHEN 'V_FANOUT_DELTA' THEN 1 WHEN 'V_FANOUT_PREVIEW' THEN 2 WHEN 'V_UNRESOLVED_REPS' THEN 3
        WHEN 'RUN_FANOUT' THEN 1 WHEN 'ROLLBACK_FANOUT' THEN 2
        ELSE 9 END,
      OBJECT_NAME
  );
  RETURN TABLE(res);
END;
$$;

-- -----------------------------------------------------------------------------
-- After pasting
--   * Each statement must end with a semicolon.
--   * Search the pasted files for any remaining sandbox references
--     (bash tools/check_repo.sh does this) and for hardcoded GIDs that
--     should come from tables instead.
--   * Data is NOT exported here. Scope rows and the user map are copied
--     during first deploy (runbooks/migration-from-sandbox.md, Step 5).
-- -----------------------------------------------------------------------------
