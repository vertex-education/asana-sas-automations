# Runbook: Operations

Always start with:

```sql
USE ROLE <SYNC_ROLE>;
USE WAREHOUSE <WAREHOUSE>;
USE SCHEMA <PROD_DB>.<SCHEMA>;
```

## Daily check

```sql
SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, RETURN_VALUE, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'TASK_RECONCILE_FANOUT', RESULT_LIMIT => 10))
ORDER BY SCHEDULED_TIME DESC;
```

`RETURN_VALUE` summarizes the run: mode, change count, per-project counts. Typical values:

| RETURN_VALUE starts with | Meaning |
|---|---|
| `In sync. 0 changes.` | Nothing to write |
| `SHADOW \|` | Changes computed and logged, nothing written |
| `LIVE \|` | Changes written; details in `FANOUT_RUN_LOG` |
| `PAUSED - no action taken.` | Kill switch is on |

A failure email from `ALERT_FANOUT_FAILURE` means a run failed, was cancelled, or no successful run happened in 24 hours.

## Common operations

| Need | Command |
|---|---|
| Run now (on demand) | `EXECUTE TASK TASK_RECONCILE_FANOUT;` |
| Stop all activity, keep the schedule | `UPDATE FANOUT_CONFIG SET VALUE = 'TRUE' WHERE SETTING = 'PAUSED';` (set `'FALSE'` to resume) |
| Stop the schedule itself | `ALTER TASK TASK_RECONCILE_FANOUT SUSPEND;` (`RESUME` to restart; the alert will email after 24 h) |
| Log-only mode | `UPDATE FANOUT_CONFIG SET VALUE = 'SHADOW' WHERE SETTING = 'MODE';` |
| Live mode (sponsor sign-off) | `UPDATE FANOUT_CONFIG SET VALUE = 'LIVE' WHERE SETTING = 'MODE';` |
| Preview pending changes | `SELECT * FROM V_FANOUT_PREVIEW;` |
| Run aborted over write cap | Inspect `V_FANOUT_PREVIEW` first. Raise only if intended: `UPDATE FANOUT_CONFIG SET VALUE = '<N>' WHERE SETTING = 'MAX_WRITES';` |
| Add or remove a project | `UPDATE FANOUT_SCOPE SET IS_ENABLED = TRUE/FALSE WHERE PROJECT_GID = '<GID>';` then preview in SHADOW |
| Test one client safely | `CALL RUN_FANOUT(TRUE, '<CLIENT>', 50);` (dry run, one client, capped; confirm parameters in the procedure header) |
| New rep not being assigned | `SELECT * FROM V_UNRESOLVED_REPS;` then `CALL LOAD_ASANA_USER_MAP();` |
| Undo a bad run | Pause, then `ROLLBACK_FANOUT` per its header in `sql/04`, scoped to the run. Confirm with the business owner first |

Log every config or scope change in `CHANGELOG.md`.

## Credential rotation

```sql
-- Asana service token
ALTER SECRET ASANA_PAT SET SECRET_STRING = '<NEW_TOKEN>';
CALL LOAD_ASANA_USER_MAP();                       -- proves the new token works

-- GitHub read-only token (rotate before the expiry recorded in README)
ALTER SECRET GITHUB_READ_SECRET SET PASSWORD = '<NEW_TOKEN>';
ALTER GIT REPOSITORY PMO_SYNC_REPO FETCH;          -- proves the new token works
```

Update the expiry dates in README > Credentials.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| No runs after a deploy | Task left suspended | `ALTER TASK TASK_RECONCILE_FANOUT RESUME;` Confirm `sql/06` ends with RESUME |
| RESUME fails: insufficient privileges | EXECUTE TASK not granted | Administrator: `GRANT EXECUTE TASK ON ACCOUNT TO ROLE <SYNC_ROLE>;` |
| MODE back to SHADOW or scope empty after deploy | A state table was recreated | Restore from records/`FANOUT_RUN_LOG`; fix `sql/02` to `IF NOT EXISTS` (the PR check should catch this) |
| `FETCH` or `LIST` auth error | GitHub token expired/revoked or lacks Contents: read | New token from IT; `ALTER SECRET GITHUB_READ_SECRET` |
| Asana 401/403 in run log | Asana token revoked or missing project access | Rotate `ASANA_PAT`; confirm token access to sheet and projects |
| Writes fail for specific schools | SFO Client on the sheet doesn't match the project's dropdown option (LLC/alias) | Fix the value with the business owner; rerun |
| Rep never assigned | No Asana user match for the email | `V_UNRESOLVED_REPS`; `CALL LOAD_ASANA_USER_MAP();` |
| Invalid identifier (e.g. `BCM`) | Display label used instead of column name | Check `INFORMATION_SCHEMA.COLUMNS` (e.g. `BCM_CONTACT`) |
| Run aborted, no writes | Delta exceeded `MAX_WRITES` | Inspect `V_FANOUT_PREVIEW` before raising the cap |
| No failure email when expected | Recipient unverified, or abort returned SUCCEEDED | Verify recipients in Snowflake; see open item in `sql/04` header |
| Users flooded with notifications | Monthly close rules set assignee when role fields change | Expected on first LIVE run; point users to the SOP section on reducing notifications |
| Object not found | Hardcoded sandbox name | `tools/verify_deployment.sql` section 5; fix, merge, redeploy |

## Escalation

Maintainer, then backup maintainer, then Snowflake administrator (grants, integrations) or IT/Asana admin (tokens). Contacts in README > Owners.
