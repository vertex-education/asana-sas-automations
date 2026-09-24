# Runbook: Deploying a change

Every change to `sql/` reaches Snowflake this way. Snowflake reads the repo; nothing pushes from GitHub.

## Before you deploy

- [ ] The change is merged to `main` through a reviewed PR
- [ ] `repo-checks` passed on `main`
- [ ] You know the expected effect on runs (from the PR description)
- [ ] If the change affects what gets written, consider switching to SHADOW first:
      `UPDATE FANOUT_CONFIG SET VALUE = 'SHADOW' WHERE SETTING = 'MODE';`

## Deploy

Run all files every time. Files are safe to rerun: state tables are `IF NOT EXISTS`, and the task and alert re-resume themselves.

```sql
USE ROLE <SYNC_ROLE>;
USE WAREHOUSE <WAREHOUSE>;
USE SCHEMA <PROD_DB>.<SCHEMA>;

ALTER GIT REPOSITORY PMO_SYNC_REPO FETCH;                -- pull latest main

EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/02_state_tables.sql;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/03_read_asana.sql;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/04_diff_write_rollback.sql;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/05_orchestrator.sql;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/06_schedule.sql;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/07_alerts.sql;
```

`sql/01_seed.sql` is documentation only and is never deployed.

**Adding a column to a state table:** `CREATE TABLE IF NOT EXISTS` does not alter an existing table. Add an explicit, rerunnable `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...` statement to `sql/02` below the table definition.

## Verify

Run `tools/verify_deployment.sql`. At minimum:

- Task and alert show `started`
- `FANOUT_CONFIG` values unchanged by the deploy
- No object references `BA_MLARSEN`
- Optional: `EXECUTE TASK TASK_RECONCILE_FANOUT;` and read the RETURN_VALUE

Record the deploy in `CHANGELOG.md` (date, who, PR).

## Roll back a bad code deploy

1. Revert the PR in GitHub (creates a new commit on `main`), then run the deploy block again. Or deploy a known-good commit directly:
   ```sql
   ALTER GIT REPOSITORY PMO_SYNC_REPO FETCH;
   EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/commits/<COMMIT_SHA>/sql/04_diff_write_rollback.sql;   -- repeat per file
   ```
2. If bad writes already reached Asana, pause first (`PAUSED = 'TRUE'`), then use `ROLLBACK_FANOUT` scoped to the affected run (see its header in `sql/04`). Confirm with the business owner before rolling back.

## Optional: release tags

For a cleaner audit trail, tag releases in GitHub (`v1.0.0`) and deploy from the tag path: `@PMO_SYNC_REPO/tags/v1.0.0/sql/...`.
