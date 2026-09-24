# Runbook: First-time production setup (migration from sandbox)

Moves the School Assignment Sync from `MART_DB.BA_MLARSEN` (maintainer's sandbox, personal credentials) to a production schema owned by a service role, with this repository as the source of record.

Complete the steps in order. Each ends with a **Checkpoint**; do not continue until it passes. Detailed rationale is in `docs/School_Assignment_Sync_Setup_Guide.pdf`, Section 5.

| Step | Outcome | Run by |
|---|---|---|
| 0 | Decisions recorded | PMO sponsor, BI, IT |
| 1 | Current definitions exported into the repo | Maintainer |
| 2 | Placeholders filled, PR merged | Maintainer + reviewer |
| 3 | Role, grants, Asana access, GitHub connection, email channel | Snowflake administrator |
| 4 | First deploy of `sql/02` to `sql/05` | Maintainer |
| 5 | Scope and user map migrated | Maintainer |
| 6 | Manual SHADOW validation | Maintainer |
| 7 | Scheduler and alert deployed | Maintainer |
| 8 | Shadow week | Maintainer |
| 9 | Go-live | Maintainer + PMO sponsor |
| 10 | Sandbox retired | Administrator + maintainer |

---

## Step 0: Decisions

Fill in README > Configuration: production schema, service role name, warehouse, operators, GitHub org, service GitHub account, alert recipients, schedule. Confirm IT has issued the read-only GitHub token and Austin has issued the Asana service token.

**Checkpoint:** every row in README > Configuration has a decided value.

## Step 1: Export current definitions from the sandbox

1. Open `tools/export_sandbox_ddl.sql` in a Snowsight worksheet. Run **Step A** (inventory) and review: note anything unexpected.
2. Run **Step B**. It returns one row per object with `TARGET_FILE` and a transformed `DDL`.
3. For each row, copy the `DDL` cell into the named file below its `TODO-EXPORT` line, in the order returned. Make sure each statement ends with `;`.
4. Rows marked `ALREADY IN sql/02` are for comparison only. Confirm the sandbox `FANOUT_CONFIG` columns match `sql/02`.
5. Rows marked `REVIEW: not mapped` need a decision: add to the right file, or leave in the sandbox (for example `SCHOOL_REP_ASSIGNMENT_SEED`). Record decisions in the PR description.
6. Delete each `TODO-EXPORT` line once its file is filled.
7. Read the pasted procedures for hardcoded values that should not move as-is (workspace or project GIDs, a personal email, sandbox names in dynamic SQL strings).

**Checkpoint:** `bash tools/check_repo.sh` reports no `TODO-EXPORT` and no `BA_MLARSEN` findings.

## Step 2: Fill placeholders and merge

1. In `sql/06_schedule.sql` and `sql/07_alerts.sql`, replace the warehouse and alert-recipient placeholders with decided values.
2. Fill `.github/CODEOWNERS` with real handles and enable branch protection on `main` (require PR, 1 approval, code-owner review, `repo-checks` passing).
3. Open a PR. Reviewer confirms the checklist in the PR template. Merge.

**Checkpoint:** `repo-checks` is green on `main`; branch protection is on.

## Step 3: Administrator setup (run once, in order)

Replace placeholders at run time; do not commit real values.

1. `admin/a1_role_and_grants.sql`: service role, EXECUTE TASK/ALERT, warehouse, schema privileges.
2. `admin/a2_asana_access.sql`: production `ASANA_PAT` secret (service token), network rule, extend `ASANA_API_INTEGRATION`.
3. `admin/a3_github_integration.sql`: GitHub read secret, API integration, `PMO_SYNC_REPO`.
4. `admin/a4_notification_integration.sql`: `PMO_SYNC_EMAIL`, test email.

**Checkpoint:** `LIST @PMO_SYNC_REPO/branches/main/sql/;` returns 01 through 07, and the test email arrived.

## Step 4: First deploy (objects only, no schedule yet)

```sql
USE ROLE <SYNC_ROLE>;
USE WAREHOUSE <WAREHOUSE>;
USE SCHEMA <PROD_DB>.<SCHEMA>;

ALTER GIT REPOSITORY PMO_SYNC_REPO FETCH;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/02_state_tables.sql;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/03_read_asana.sql;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/04_diff_write_rollback.sql;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/05_orchestrator.sql;
```

**Checkpoint:** `SELECT * FROM FANOUT_CONFIG;` shows MODE = SHADOW, PAUSED = FALSE, MAX_WRITES = 200, and the procedures and views exist (`tools/verify_deployment.sql`, sections 2, 4, 5).

## Step 5: Migrate data

Do **not** copy `FANOUT_CONFIG`; production must start in SHADOW.

```sql
-- Compare column lists first:  DESCRIBE TABLE FANOUT_SCOPE;  DESCRIBE TABLE MART_DB.BA_MLARSEN.FANOUT_SCOPE;
INSERT INTO FANOUT_SCOPE SELECT * FROM MART_DB.BA_MLARSEN.FANOUT_SCOPE;
-- If present in the sandbox:
-- INSERT INTO FANOUT_SCOPE_PORTFOLIO SELECT * FROM MART_DB.BA_MLARSEN.FANOUT_SCOPE_PORTFOLIO;

-- User map: reload from Asana with the service token (preferred), or copy
CALL LOAD_ASANA_USER_MAP();
-- INSERT INTO ASANA_USER_MAP SELECT * FROM MART_DB.BA_MLARSEN.ASANA_USER_MAP;

-- Optional: keep run history for audit
-- INSERT INTO FANOUT_RUN_LOG SELECT * FROM MART_DB.BA_MLARSEN.FANOUT_RUN_LOG;

-- Disable test projects before any LIVE run
SELECT PROJECT_NAME, IS_ENABLED, NOTES FROM FANOUT_SCOPE ORDER BY PROJECT_NAME;
UPDATE FANOUT_SCOPE SET IS_ENABLED = FALSE WHERE PROJECT_NAME ILIKE '%Academy of Alameda%';
```

**Checkpoint:** scope row counts match the sandbox; every enabled project is intentional; `LOAD_ASANA_USER_MAP` succeeded (this also proves the Asana service token and integration work).

## Step 6: Manual SHADOW validation

```sql
CALL REFRESH_MASTER_STATE();          -- note schools missing an SFO Client
CALL DISCOVER_TARGETS();
SELECT * FROM V_UNRESOLVED_REPS;      -- reps with no Asana user match
SELECT * FROM V_FANOUT_PREVIEW;       -- what LIVE would change
CALL RECONCILE_FANOUT();              -- full run; RETURN must start with SHADOW
```

Run the same calls in the sandbox on the same day and compare counts.

**Checkpoint:** production and sandbox results agree within expectation; RETURN starts with `SHADOW`.

## Step 7: Deploy scheduler and alert

```sql
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/06_schedule.sql;
EXECUTE IMMEDIATE FROM @PMO_SYNC_REPO/branches/main/sql/07_alerts.sql;
SHOW TASKS  LIKE 'TASK_RECONCILE_FANOUT';   -- state = started
SHOW ALERTS LIKE 'ALERT_FANOUT_FAILURE';    -- state = started
```

Once the production task is running, suspend the sandbox task so only one job runs (both in SHADOW is harmless, but one scheduler is simpler to reason about):

```sql
ALTER TASK MART_DB.BA_MLARSEN.TASK_RECONCILE_FANOUT SUSPEND;
```

**Checkpoint:** both production objects `started`; sandbox task `suspended`.

## Step 8: Shadow week

- At least five consecutive nightly runs in SHADOW. Review each morning (`runbooks/operations.md`, Daily check).
- Look for failures, unexpected scope, and change counts that stay large night after night (a comparison bug that would mean thousands of unnecessary writes in LIVE).
- Resolve `V_UNRESOLVED_REPS` and SFO Client mismatches with the business owner.
- Brief the business owner: in LIVE, monthly close rules will set assignees and notify reps. The sync write is silent; the rule reacting to it is not.

**Checkpoint:** five or more clean runs reviewed; open data issues resolved or accepted.

## Step 9: Go-live

After PMO sponsor sign-off:

```sql
UPDATE FANOUT_CONFIG SET VALUE = 'LIVE' WHERE SETTING = 'MODE';
```

Verify the first LIVE run in Asana on several projects. Add the date to `CHANGELOG.md` and update README > Status.

**Checkpoint:** first LIVE run verified by eye in Asana; sign-off recorded.

## Step 10: Retire the sandbox

Administrator runs `admin/a5_retire_sandbox.sql`. Maintainer revokes the personal Asana PAT, updates the SOP, and schedules sandbox object removal after 30 days.

**Checkpoint:** no production object references the sandbox or a personal credential.
