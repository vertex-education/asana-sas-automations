# Changelog

Record every production deploy, MODE switch, MAX_WRITES change, scope change, and credential rotation.
Newest first. Format: `YYYY-MM-DD | who | what | PR or ticket`.

## Unreleased
- Production deployment pending. See `runbooks/migration-from-sandbox.md`.

## 2026-09-24
- Repository structure, runbooks, admin templates, and Setup & Handoff Guide v1.0 created.
- Procedure and table definitions pending export from sandbox (`TODO-EXPORT` markers in `sql/02` to `sql/05`).

## 2026-09-15
- Sandbox: `TASK_RECONCILE_FANOUT` created in `MART_DB.BA_MLARSEN`, MODE = SHADOW. Resume status and shadow results not confirmed at time of writing.
