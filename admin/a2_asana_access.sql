-- =============================================================================
-- School Assignment Sync | admin/a2_asana_access.sql
-- RUN ONCE. Stores the Asana SERVICE token in production and allows egress.
--
-- Why the names stay the same: the procedures reference
--   EXTERNAL_ACCESS_INTEGRATIONS = (ASANA_API_INTEGRATION)
--   SECRETS = ('cred' = ASANA_PAT)
-- Integrations are ACCOUNT-level, and ASANA_API_INTEGRATION already serves the
-- sandbox. We create the secret and network rule in the production schema and
-- EXTEND the existing integration, so no procedure code changes.
--
-- The token value is typed here at run time. NEVER commit a real value.
-- =============================================================================

-- Step 1: inspect what exists today (note the current rules and secrets)
USE ROLE ACCOUNTADMIN;
DESCRIBE EXTERNAL ACCESS INTEGRATION ASANA_API_INTEGRATION;
DESCRIBE SECRET MART_DB.BA_MLARSEN.ASANA_PAT;          -- expect TYPE = GENERIC_STRING
SHOW NETWORK RULES IN SCHEMA MART_DB.BA_MLARSEN;       -- note the sandbox rule name

-- Step 2: create production secret and network rule (as the service role, so it owns them)
USE ROLE <SYNC_ROLE>;
USE SCHEMA <PROD_DB>.<SCHEMA>;

CREATE OR REPLACE SECRET ASANA_PAT
  TYPE = GENERIC_STRING
  SECRET_STRING = '<ASANA_SERVICE_TOKEN>'
  COMMENT = 'Asana org service token for School Assignment Sync. Owner: IT / Austin De Rossi. Record expiry in README.';

CREATE OR REPLACE NETWORK RULE ASANA_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('app.asana.com');

-- Step 3: extend the existing integration to allow BOTH sandbox and production
-- until the sandbox is retired (admin/a5_retire_sandbox.sql removes the sandbox entries).
USE ROLE ACCOUNTADMIN;
ALTER EXTERNAL ACCESS INTEGRATION ASANA_API_INTEGRATION SET
  ALLOWED_NETWORK_RULES = (MART_DB.BA_MLARSEN.<SANDBOX_NETWORK_RULE>, <PROD_DB>.<SCHEMA>.ASANA_API_RULE)
  ALLOWED_AUTHENTICATION_SECRETS = (MART_DB.BA_MLARSEN.ASANA_PAT, <PROD_DB>.<SCHEMA>.ASANA_PAT);

GRANT USAGE ON INTEGRATION ASANA_API_INTEGRATION TO ROLE <SYNC_ROLE>;

-- Verify
DESCRIBE EXTERNAL ACCESS INTEGRATION ASANA_API_INTEGRATION;   -- both rules and both secrets listed
