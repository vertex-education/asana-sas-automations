-- =============================================================================
-- School Assignment Sync | admin/a3_github_integration.sql
-- RUN ONCE. Lets Snowflake READ the asana-sas-automations repository.
-- Requires ACCOUNTADMIN (or a role with CREATE INTEGRATION).
--
-- Token requirements (issued by IT):
--   * Fine-grained token owned by a NON-personal service account
--   * Repository access: asana-sas-automations only
--   * Permission: Contents = Read-only (nothing else)
--   * Record the expiry date in README > Credentials and set a reminder
-- The token value is typed here at run time. NEVER commit a real value.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA <PROD_DB>.<SCHEMA>;

-- 1. Read-only GitHub token
CREATE OR REPLACE SECRET GITHUB_READ_SECRET
  TYPE = PASSWORD
  USERNAME = '<GITHUB_SVC_USER>'
  PASSWORD = '<GITHUB_TOKEN>'
  COMMENT = 'Read-only GitHub token for asana-sas-automations. Owner: IT. Record expiry in README.';

-- 2. Allow Snowflake to reach the Vertex GitHub organization
CREATE OR REPLACE API INTEGRATION VERTEX_GITHUB_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/<GITHUB_ORG>/')
  ALLOWED_AUTHENTICATION_SECRETS = (<PROD_DB>.<SCHEMA>.GITHUB_READ_SECRET)
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION VERTEX_GITHUB_INTEGRATION TO ROLE <SYNC_ROLE>;
GRANT USAGE ON SECRET <PROD_DB>.<SCHEMA>.GITHUB_READ_SECRET TO ROLE <SYNC_ROLE>;

-- 3. Register the repository (as the service role, so it owns the object)
USE ROLE <SYNC_ROLE>;
USE SCHEMA <PROD_DB>.<SCHEMA>;
CREATE OR REPLACE GIT REPOSITORY PMO_SYNC_REPO
  API_INTEGRATION = VERTEX_GITHUB_INTEGRATION
  GIT_CREDENTIALS = GITHUB_READ_SECRET
  ORIGIN = 'https://github.com/<GITHUB_ORG>/asana-sas-automations.git'
  COMMENT = 'Read-only clone of asana-sas-automations. Deploy source for School Assignment Sync.';

-- 4. Verify
ALTER GIT REPOSITORY PMO_SYNC_REPO FETCH;
SHOW GIT BRANCHES IN PMO_SYNC_REPO;
LIST @PMO_SYNC_REPO/branches/main/sql/;      -- expect 01 through 07
