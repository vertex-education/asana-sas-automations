# asana-sas-automations

Source of record for the **School Assignment Sync**, the Vertex Education PMO automation that keeps rep role fields (BCM Rep, AC Rep, AP Rep, Payroll) on Asana monthly close projects aligned with the **School Assignment Sheet**, the Asana project that is the master record of who supports each school.

Every night a Snowflake task compares intended state (the sheet) with actual state (the in-scope projects) and writes only the differences back to Asana.

> **Full setup and handoff guide:** [`docs/School_Assignment_Sync_Setup_Guide.pdf`](docs/School_Assignment_Sync_Setup_Guide.pdf)

---

## Status

| Item | State (as of 2026-09-24) |
|---|---|
| Runtime location | Sandbox schema `MART_DB.BA_MLARSEN` (maintainer's role, personal Asana token) |
| Scheduler | `TASK_RECONCILE_FANOUT` created 2026-09-15 in **SHADOW** mode. Resume and shadow results not yet confirmed |
| Production deployment | **Pending.** Follow [`runbooks/migration-from-sandbox.md`](runbooks/migration-from-sandbox.md) |
| Procedure source in this repo | **Pending export** from the sandbox (`sql/02` to `sql/05` contain `TODO-EXPORT` markers) |

Update this table when production go-live happens.

---

## How it works

```
Asana School Assignment Sheet (intended state)
        |  REFRESH_MASTER_STATE  (Asana API)
        v
Snowflake  ->  V_FANOUT_DELTA  <-  DISCOVER_TARGETS  (role fields on projects in FANOUT_SCOPE)
        |
        |  RUN_FANOUT  (SHADOW = log only, LIVE = write)
        v
Asana in-scope monthly close projects (role fields updated)
```

- **Reconciliation, not change detection.** Each run converges downstream projects to the sheet. Safe to re-run, heals after a failed run, corrects manual drift.
- **Orchestrator:** `RECONCILE_FANOUT()` reads `FANOUT_CONFIG`, then runs refresh, discovery, delta, and write steps.
- **Scheduler:** Snowflake task `TASK_RECONCILE_FANOUT`, nightly at 4:00 AM `America/Phoenix`.
- **Monitoring:** Snowflake alert `ALERT_FANOUT_FAILURE` emails maintainers when the nightly run fails or does not run.
- **Deployment:** Snowflake reads this repo through a read-only Git repository object (`PMO_SYNC_REPO`) and runs files with `EXECUTE IMMEDIATE FROM`. What runs is what was reviewed and merged.
- **Not used:** GitHub Actions does not schedule the sync. The only workflow in this repo is a pull-request check.

### Guardrails (in `FANOUT_CONFIG`, changed with SQL, not code)

| Setting | Values | Effect |
|---|---|---|
| `MODE` | `SHADOW` / `LIVE` | SHADOW computes and logs every change without writing. LIVE writes to Asana |
| `PAUSED` | `TRUE` / `FALSE` | Kill switch. TRUE skips the run entirely |
| `MAX_WRITES` | Integer, default `200` | Run aborts without writing if the delta exceeds the cap |

Only projects enabled in `FANOUT_SCOPE` are read or written.

---

## Repository layout

```
asana-sas-automations/
|-- README.md                     this file
|-- CHANGELOG.md                  dated record of deploys, mode switches, config changes
|-- .gitignore
|-- .github/
|   |-- CODEOWNERS                required reviewers (fill in handles)
|   |-- pull_request_template.md  review checklist
|   `-- workflows/repo-checks.yml PR check: no secrets, no sandbox names, no unfilled markers
|-- admin/                        run ONCE by a Snowflake administrator; templates with placeholders
|   |-- a1_role_and_grants.sql
|   |-- a2_asana_access.sql
|   |-- a3_github_integration.sql
|   |-- a4_notification_integration.sql
|   `-- a5_retire_sandbox.sql
|-- sql/                          deployed from the repo, in order, into the production schema
|   |-- 01_seed.sql               documentation only; not deployed
|   |-- 02_state_tables.sql       tables that hold data: CREATE TABLE IF NOT EXISTS only
|   |-- 03_read_asana.sql         LOAD_ASANA_USER_MAP, REFRESH_MASTER_STATE, DISCOVER_TARGETS
|   |-- 04_diff_write_rollback.sql views, RUN_FANOUT, ROLLBACK_FANOUT
|   |-- 05_orchestrator.sql       RECONCILE_FANOUT
|   |-- 06_schedule.sql           TASK_RECONCILE_FANOUT (ends with RESUME)
|   `-- 07_alerts.sql             ALERT_FANOUT_FAILURE (ends with RESUME)
|-- runbooks/
|   |-- migration-from-sandbox.md first-time production setup, start to finish
|   |-- deploy.md                 how every change is deployed
|   `-- operations.md             daily check, common operations, troubleshooting
|-- tools/
|   |-- export_sandbox_ddl.sql    pulls current object definitions out of the sandbox
|   |-- verify_deployment.sql     post-deploy verification queries
|   `-- check_repo.sh             the checks run by the PR workflow (run locally too)
|-- app/                          optional Streamlit console (not on the critical path)
`-- docs/
    `-- School_Assignment_Sync_Setup_Guide.pdf
```

---

## Configuration

Record decided values here. Placeholders in `<ANGLE_BRACKETS>` must be replaced before a file is run.

| Placeholder | Meaning | Used in | Decided value |
|---|---|---|---|
| `<PROD_DB>.<SCHEMA>` | Production home for all objects (recommended `PROD_DB.WS4`, pending BI) | `admin/`, runbooks | |
| `<SYNC_ROLE>` | Service role that owns objects, task, alert (recommended `PMO_SYNC_ROLE`) | `admin/`, runbooks | |
| `<WAREHOUSE>` | Warehouse for task and alert | `admin/a1`, `sql/06`, `sql/07` | |
| `<OPERATOR_1>`, `<OPERATOR_2>` | Snowflake users who operate the sync | `admin/a1` | |
| `<GITHUB_ORG>` | Vertex GitHub organization hosting this repo | `admin/a3` | |
| `<GITHUB_SVC_USER>` | Non-personal GitHub account owning the read-only token | `admin/a3` | |
| `<ALERT_RECIPIENTS>` | Failure alert emails, comma-separated in one string (verified Snowflake users) | `sql/07` | |
| `<ALERT_RECIPIENT_1>`, `<ALERT_RECIPIENT_2>` | Same addresses, listed individually for the integration allow-list | `admin/a4` | |
| `<SANDBOX_NETWORK_RULE>` | Existing sandbox network rule name (shown by `SHOW NETWORK RULES` in `admin/a2`) | `admin/a2` | |
| `<SANDBOX_OWNER_ROLE>` | Role that owns the sandbox task (e.g. `BA_SCHEMA_ADMIN`) | `admin/a5` | |
| Schedule | `0 4 * * * America/Phoenix` (confirm) | `sql/06` | |

`sql/` files must contain **no** placeholders when merged. The PR check fails if any remain.

`<ASANA_SERVICE_TOKEN>` and `<GITHUB_TOKEN>` in `admin/a2` and `admin/a3` are typed by the administrator at run time and are **never** replaced in the committed files.

### Credentials (values never go in this repo)

| Credential | Stored as | Owner | Expires | Rotation reminder set |
|---|---|---|---|---|
| Asana service token | Secret `ASANA_PAT` in `<PROD_DB>.<SCHEMA>` | Austin De Rossi / IT | | |
| GitHub read-only token | Secret `GITHUB_READ_SECRET` in `<PROD_DB>.<SCHEMA>` | IT | | |

---

## First-time setup

Follow [`runbooks/migration-from-sandbox.md`](runbooks/migration-from-sandbox.md). Order:

1. Export current definitions from the sandbox (`tools/export_sandbox_ddl.sql`) into `sql/02` to `sql/05`, merge via PR.
2. Administrator runs `admin/a1` to `admin/a4`.
3. First deploy of `sql/02` to `sql/05`, migrate scope and user map, validate in SHADOW.
4. Deploy `sql/06` and `sql/07`; run a shadow week.
5. Sponsor sign-off, switch to LIVE.
6. Administrator runs `admin/a5` to retire the sandbox.

## Making a change

1. Branch, edit, open a pull request. Never edit objects directly in a Snowsight worksheet: if it is not in `main`, it is not the record.
2. Second person reviews; PR check passes; merge.
3. Deploy per [`runbooks/deploy.md`](runbooks/deploy.md).
4. Add a line to `CHANGELOG.md`.

## Daily operation

See [`runbooks/operations.md`](runbooks/operations.md). Most common commands:

```sql
-- Last 10 runs
SELECT NAME, STATE, SCHEDULED_TIME, RETURN_VALUE, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'TASK_RECONCILE_FANOUT', RESULT_LIMIT => 10))
ORDER BY SCHEDULED_TIME DESC;

EXECUTE TASK TASK_RECONCILE_FANOUT;                                    -- run now
UPDATE FANOUT_CONFIG SET VALUE = 'TRUE'   WHERE SETTING = 'PAUSED';    -- kill switch
UPDATE FANOUT_CONFIG SET VALUE = 'SHADOW' WHERE SETTING = 'MODE';      -- back to log-only
```

---

## Rules

- **No secrets in this repo.** Tokens are entered directly into Snowflake secrets by an administrator.
- **Service identities only.** Production runs under `<SYNC_ROLE>` and the Asana service token, never a personal account.
- **State tables are never replaced.** `sql/02_state_tables.sql` uses `CREATE TABLE IF NOT EXISTS`. A `CREATE OR REPLACE TABLE` there would reset MODE, scope, and logs on every deploy.
- **Task files end with RESUME.** `CREATE OR REPLACE TASK` leaves a task suspended.
- **Never run sandbox and production in LIVE at the same time.**
- **Asana notifications:** the sync's field writes are silent, but monthly close rules react by setting assignees, which notifies. Expect a batch on the first LIVE run.

## Owners

| Role | Current | Receiving team |
|---|---|---|
| Business owner (sheet data, monthly close rules) | Cora | |
| PMO sponsor (priorities, LIVE sign-off) | Roger Cormier | |
| Maintainer (code, deploys, daily review) | Matt Larsen | |
| Snowflake administrator | Vinay | |
| GitHub org / Asana admin | IT / Austin De Rossi | |
| BI / data platform | BI team | |

## Known gaps

Tracked in Section 9 of the setup guide. Summary: production schema and service role not yet decided; Asana service token and GitHub org access pending; sandbox shadow results unconfirmed; `RUN_FANOUT` abort handling may not surface as a task failure; test project Academy of Alameda must be disabled before LIVE; on-demand trigger for business users (Asana external action) not built.
