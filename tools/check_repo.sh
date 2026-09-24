#!/usr/bin/env bash
# Repository safety checks. Run locally before opening a PR:  bash tools/check_repo.sh
# Also run automatically by .github/workflows/repo-checks.yml.
set -u
fail=0
err() { echo "FAIL: $1"; fail=1; }

# 1. No sandbox schema names in deployable SQL
if grep -rn "BA_MLARSEN" sql/; then
  err "sandbox schema name found in sql/. Use unqualified object names."
fi

# 2. No unfilled export markers in deployable SQL
if grep -rn "TODO-EXPORT" sql/; then
  err "TODO-EXPORT marker still present. Paste exported DDL (tools/export_sandbox_ddl.sql) and remove the marker."
fi

# 3. No unresolved <PLACEHOLDERS> in deployable SQL
if grep -rnE "<[A-Z][A-Z0-9_]*>" sql/; then
  err "unresolved placeholder in sql/. Replace with the decided value (see README Configuration)."
fi

# 4. State tables must never be replaced
if grep -niE "create[[:space:]]+or[[:space:]]+replace[[:space:]]+(transient[[:space:]]+)?table" sql/02_state_tables.sql \
     | grep -vE "^[0-9]+:[[:space:]]*--"; then
  err "sql/02_state_tables.sql uses CREATE OR REPLACE TABLE. Use CREATE TABLE IF NOT EXISTS."
fi

# 5. Task and alert files must resume what they create
grep -qiE "alter[[:space:]]+task[[:space:]]+task_reconcile_fanout[[:space:]]+resume" sql/06_schedule.sql \
  || err "sql/06_schedule.sql must end with ALTER TASK TASK_RECONCILE_FANOUT RESUME;"
grep -qiE "alter[[:space:]]+alert[[:space:]]+alert_fanout_failure[[:space:]]+resume" sql/07_alerts.sql \
  || err "sql/07_alerts.sql must end with ALTER ALERT ALERT_FANOUT_FAILURE RESUME;"

# 6. Likely secrets anywhere in the repo (placeholders in <ANGLE_BRACKETS> are allowed)
if grep -rnE "(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)" \
     --exclude=check_repo.sh --exclude-dir=.git .; then
  err "possible GitHub token or private key committed."
fi
if grep -rniE "(SECRET_STRING|PASSWORD)[[:space:]]*=[[:space:]]*'[^<']" \
     --include=*.sql --exclude-dir=.git .; then
  err "a secret value appears to be hardcoded. Secrets are entered directly in Snowflake, never committed."
fi

if [ "$fail" -eq 0 ]; then echo "All repository checks passed."; fi
exit "$fail"
