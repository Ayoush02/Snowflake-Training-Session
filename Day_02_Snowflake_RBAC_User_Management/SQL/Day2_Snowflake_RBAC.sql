-- Understanding inheritance with a concrete example:

-- Step 1: Create roles
CREATE ROLE READER_ROLE;   -- Can SELECT on reporting tables
CREATE ROLE ANALYST_ROLE;  -- Can also write to staging
CREATE ROLE SENIOR_ANALYST_ROLE; -- Can do everything ANALYST_ROLE does + more

SHOW ROLES; 

-- Step 2: Grant privileges to READER_ROLE
GRANT USAGE ON DATABASE SALES_DB TO ROLE READER_ROLE;
GRANT USAGE ON SCHEMA SALES_DB.REPORTING TO ROLE READER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA SALES_DB.REPORTING TO ROLE READER_ROLE;

-- Step 3: Grant READER_ROLE to ANALYST_ROLE (inheritance!)
GRANT ROLE READER_ROLE TO ROLE ANALYST_ROLE;
-- ANALYST_ROLE now has all READER_ROLE privileges PLUS any additional grants

-- Step 4: Grant ANALYST_ROLE to SENIOR_ANALYST_ROLE (chain!)
GRANT ROLE ANALYST_ROLE TO ROLE SENIOR_ANALYST_ROLE;
-- SENIOR_ANALYST_ROLE now inherits from ANALYST_ROLE AND READER_ROLE

-- Step 5: ALWAYS grant custom roles to SYSADMIN for visibility
GRANT ROLE READER_ROLE TO ROLE SYSADMIN;
GRANT ROLE ANALYST_ROLE TO ROLE SYSADMIN;
GRANT ROLE SENIOR_ANALYST_ROLE TO ROLE SYSADMIN;

SHOW GRANTS OF ROLE ANALYST_ROLE;
SHOW GRANTS OF ROLE SENIOR_ANALYST_ROLE;
SHOW GRANTS OF ROLE READER_ROLE;

-- Snowflake role inheritance is not magic. It’s just role-to-role grants.
-- If Role A is granted to Role B, B gets everything A has—plus its own privileges.

-- =============================================
-- USER MANAGEMENT COMPLETE REFERENCE
-- =============================================

-- Create a regular analyst user
CREATE USER priya_sharma
  PASSWORD              = 'Temp@2025!'
  LOGIN_NAME            = 'priya.sharma@company.com'
  DISPLAY_NAME          = 'Priya Sharma'
  FIRST_NAME            = 'Priya'
  LAST_NAME             = 'Sharma'
  EMAIL                 = 'priya.sharma@company.com'
  DEFAULT_ROLE          = ANALYTICS_READER
  DEFAULT_WAREHOUSE     = ANALYTICS_WH
  DEFAULT_NAMESPACE     = SALES_DB.REPORTING
  MUST_CHANGE_PASSWORD  = TRUE   -- Force password change on first login
  COMMENT               = 'Senior Data Analyst - Finance Team';


-- Modify an existing user
ALTER USER priya_sharma SET DEFAULT_ROLE = SENIOR_ANALYST_ROLE;
ALTER USER priya_sharma SET DEFAULT_WAREHOUSE = LARGE_ANALYTICS_WH;
ALTER USER priya_sharma SET EMAIL = 'priya.sharma.new@company.com';

-- Disable a user (e.g., employee on leave)
ALTER USER priya_sharma SET DISABLED = TRUE;

-- Re-enable
ALTER USER priya_sharma SET DISABLED = FALSE;

-- Reset a user's password
ALTER USER priya_sharma RESET PASSWORD;

-- Drop a user (off-boarding)
DROP USER priya_sharma;

-- Useful inspection queries
SHOW USERS;                                    -- All users in account
DESC USER priya_sharma;                        -- User details
SHOW GRANTS TO USER priya_sharma;             -- Roles granted to this user

-- In Snowflake, user management is the same for people and tools—but in real enterprises, we separate human users and service users. 

-- =============================================
-- ENTERPRISE RBAC DESIGN: RETAIL COMPANY
-- =============================================

USE ROLE SECURITYADMIN;

-- ─────────────────────────────────────────
-- TIER 2: DATA ACCESS ROLES (Granular)
-- ─────────────────────────────────────────

-- Database/Schema access roles
CREATE ROLE SALES_DB_READ       COMMENT = 'SELECT on SALES_DB reporting schema';
CREATE ROLE SALES_DB_WRITE      COMMENT = 'INSERT/UPDATE on SALES_DB staging schema';
CREATE ROLE HR_DB_READ          COMMENT = 'SELECT on HR_DB (masked PII)';
CREATE ROLE FINANCE_DB_READ     COMMENT = 'SELECT on FINANCE_DB reporting schema';
CREATE ROLE MARKETING_DB_READ   COMMENT = 'SELECT on MARKETING_DB reporting schema';
CREATE ROLE RAW_DATA_READ       COMMENT = 'SELECT on all RAW schemas — restricted';

-- Warehouse access roles
CREATE ROLE WH_XS_ACCESS        COMMENT = 'USAGE on DEV_WH (X-Small)';
CREATE ROLE WH_SMALL_ACCESS     COMMENT = 'USAGE on REPORTING_WH (Small)';
CREATE ROLE WH_MEDIUM_ACCESS    COMMENT = 'USAGE on ANALYTICS_WH (Medium)';
CREATE ROLE WH_LARGE_ACCESS     COMMENT = 'USAGE on ETL_WH (Large)';

-- ─────────────────────────────────────────
-- TIER 1: FUNCTIONAL ROLES (Assigned to Users)
-- ─────────────────────────────────────────

CREATE ROLE JUNIOR_ANALYST_ROLE  COMMENT = 'Junior Analyst — read-only sales reporting';
CREATE ROLE SENIOR_ANALYST_ROLE  COMMENT = 'Senior Analyst — read sales + finance';
CREATE ROLE BI_DEVELOPER_ROLE    COMMENT = 'BI Dev — all reporting schemas read';
CREATE ROLE DATA_ENGINEER_ROLE   COMMENT = 'Data Engineer — write access + ETL';
CREATE ROLE DATA_SCIENTIST_ROLE  COMMENT = 'Data Scientist — analytics + raw read';
CREATE ROLE DBA_ADMIN_ROLE       COMMENT = 'DBA — full object management';

-- ─────────────────────────────────────────
-- WIRE FUNCTIONAL → DATA ACCESS ROLES
-- ─────────────────────────────────────────

-- Junior Analyst: sales read + XS warehouse
GRANT ROLE SALES_DB_READ    TO ROLE JUNIOR_ANALYST_ROLE;
GRANT ROLE WH_SMALL_ACCESS  TO ROLE JUNIOR_ANALYST_ROLE;

-- Senior Analyst: sales + finance read + medium warehouse
GRANT ROLE SALES_DB_READ    TO ROLE SENIOR_ANALYST_ROLE;
GRANT ROLE FINANCE_DB_READ  TO ROLE SENIOR_ANALYST_ROLE;
GRANT ROLE MARKETING_DB_READ TO ROLE SENIOR_ANALYST_ROLE;
GRANT ROLE WH_MEDIUM_ACCESS TO ROLE SENIOR_ANALYST_ROLE;

-- BI Developer: all reporting + small warehouse
GRANT ROLE SALES_DB_READ    TO ROLE BI_DEVELOPER_ROLE;
GRANT ROLE FINANCE_DB_READ  TO ROLE BI_DEVELOPER_ROLE;
GRANT ROLE HR_DB_READ       TO ROLE BI_DEVELOPER_ROLE;
GRANT ROLE MARKETING_DB_READ TO ROLE BI_DEVELOPER_ROLE;
GRANT ROLE WH_SMALL_ACCESS  TO ROLE BI_DEVELOPER_ROLE;

-- Data Engineer: write access + large warehouse
GRANT ROLE SALES_DB_READ    TO ROLE DATA_ENGINEER_ROLE;
GRANT ROLE SALES_DB_WRITE   TO ROLE DATA_ENGINEER_ROLE;
GRANT ROLE WH_LARGE_ACCESS  TO ROLE DATA_ENGINEER_ROLE;

-- Data Scientist: read everything including raw
GRANT ROLE SALES_DB_READ    TO ROLE DATA_SCIENTIST_ROLE;
GRANT ROLE RAW_DATA_READ    TO ROLE DATA_SCIENTIST_ROLE;
GRANT ROLE WH_MEDIUM_ACCESS TO ROLE DATA_SCIENTIST_ROLE;

-- ─────────────────────────────────────────
-- ALWAYS GRANT CUSTOM ROLES TO SYSADMIN
-- ─────────────────────────────────────────

GRANT ROLE SALES_DB_READ      TO ROLE SYSADMIN;
GRANT ROLE SALES_DB_WRITE     TO ROLE SYSADMIN;
GRANT ROLE HR_DB_READ         TO ROLE SYSADMIN;
GRANT ROLE FINANCE_DB_READ    TO ROLE SYSADMIN;
GRANT ROLE MARKETING_DB_READ  TO ROLE SYSADMIN;
GRANT ROLE RAW_DATA_READ      TO ROLE SYSADMIN;
GRANT ROLE WH_XS_ACCESS       TO ROLE SYSADMIN;
GRANT ROLE WH_SMALL_ACCESS    TO ROLE SYSADMIN;
GRANT ROLE WH_MEDIUM_ACCESS   TO ROLE SYSADMIN;
GRANT ROLE WH_LARGE_ACCESS    TO ROLE SYSADMIN;
GRANT ROLE JUNIOR_ANALYST_ROLE  TO ROLE SYSADMIN;
GRANT ROLE SENIOR_ANALYST_ROLE  TO ROLE SYSADMIN;
GRANT ROLE BI_DEVELOPER_ROLE    TO ROLE SYSADMIN;
GRANT ROLE DATA_ENGINEER_ROLE   TO ROLE SYSADMIN;
GRANT ROLE DATA_SCIENTIST_ROLE  TO ROLE SYSADMIN;
GRANT ROLE DBA_ADMIN_ROLE       TO ROLE SYSADMIN;

SHOW ROLES;
SHOW GRANTS OF ROLE JUNIOR_ANALYST_ROLE; -- Functional role does NOT hold privileges directly—it inherits them from data + warehouse roles.
SHOW GRANTS OF ROLE SENIOR_ANALYST_ROLE;

SHOW GRANTS TO ROLE SYSADMIN;
-- You will see EVERYTHING assigned to SYSADMIN:
-- All data access roles
-- All functional roles
-- All warehouse roles
-- SYSADMIN acts as visibility role in Snowflake governance—this is why we grant all custom roles to it.

SHOW GRANTS; -- To show full inheritance chain across enterprise

USE ROLE DATA_ENGINEER_ROLE;
SHOW WAREHOUSES;
USE WAREHOUSE COMPUTE_WH;
-- Even though we didn’t grant warehouse directly to user, it works through role inheritance.

-- We have built a 3-layer RBAC model:
-- Functional roles (who you are)
-- Data access roles (what you can access)
-- Warehouse roles (compute access)
-- Functional roles are just containers that inherit everything.

-- =============================================
-- PRIVILEGE GRANT PATTERNS — COMPLETE GUIDE
-- =============================================

USE ROLE SYSADMIN;

-- PATTERN 1: Grant full database access to a role
GRANT USAGE ON DATABASE SALES_DB TO ROLE SALES_DB_READ;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SALES_DB TO ROLE SALES_DB_READ;
GRANT SELECT ON ALL TABLES IN DATABASE SALES_DB TO ROLE SALES_DB_READ;
GRANT SELECT ON ALL VIEWS IN DATABASE SALES_DB TO ROLE SALES_DB_READ;

-- PATTERN 2: Grant schema-specific access
GRANT USAGE ON DATABASE SALES_DB TO ROLE SALES_DB_READ;
GRANT USAGE ON SCHEMA SALES_DB.REPORTING TO ROLE SALES_DB_READ;
GRANT SELECT ON ALL TABLES IN SCHEMA SALES_DB.REPORTING TO ROLE SALES_DB_READ;
GRANT SELECT ON ALL VIEWS  IN SCHEMA SALES_DB.REPORTING TO ROLE SALES_DB_READ;

-- PATTERN 3: Future grants (auto-apply to NEW objects created later)
GRANT SELECT ON FUTURE TABLES IN SCHEMA SALES_DB.REPORTING TO ROLE SALES_DB_READ;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA SALES_DB.REPORTING TO ROLE SALES_DB_READ;

-- PATTERN 4: Grant write access for data engineering
GRANT USAGE  ON DATABASE SALES_DB TO ROLE SALES_DB_WRITE;
GRANT USAGE  ON SCHEMA SALES_DB.STAGING TO ROLE SALES_DB_WRITE;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON ALL TABLES IN SCHEMA SALES_DB.STAGING TO ROLE SALES_DB_WRITE;
GRANT CREATE TABLE ON SCHEMA SALES_DB.STAGING TO ROLE SALES_DB_WRITE;

-- PATTERN 5: Warehouse access
GRANT USAGE   ON WAREHOUSE ANALYTICS_WH TO ROLE WH_MEDIUM_ACCESS;
GRANT MONITOR ON WAREHOUSE ANALYTICS_WH TO ROLE WH_MEDIUM_ACCESS;

-- PATTERN 6: Revoke a privilege
REVOKE SELECT ON ALL TABLES IN SCHEMA SALES_DB.REPORTING FROM ROLE JUNIOR_ANALYST_ROLE;

-- PATTERN 7: Transfer ownership
GRANT OWNERSHIP ON TABLE SALES_DB.REPORTING.SALES_FACT
  TO ROLE DATA_ENGINEER_ROLE COPY CURRENT GRANTS;

-- PATTERN 8: Check existing grants
SHOW GRANTS TO ROLE SENIOR_ANALYST_ROLE;
SHOW GRANTS ON DATABASE SALES_DB;
SHOW GRANTS ON TABLE SALES_DB.REPORTING.SALES_FACT;
SHOW FUTURE GRANTS IN SCHEMA SALES_DB.REPORTING;

-- Assigning Roles to Users — Complete Patterns
-- Assign functional roles to users
USE ROLE USERADMIN;

CREATE USER rahul_kumar
PASSWORD = 'Test@123'
DEFAULT_ROLE = JUNIOR_ANALYST_ROLE
MUST_CHANGE_PASSWORD = TRUE;

CREATE USER arun_thomas
PASSWORD = 'Test@123'
DEFAULT_ROLE = BI_DEVELOPER_ROLE
MUST_CHANGE_PASSWORD = TRUE;

CREATE USER meera_nair
PASSWORD = 'Test@123'
DEFAULT_ROLE = DATA_ENGINEER_ROLE
MUST_CHANGE_PASSWORD = TRUE;

CREATE USER vikram_iyer
PASSWORD = 'Test@123'
DEFAULT_ROLE = DATA_SCIENTIST_ROLE
MUST_CHANGE_PASSWORD = TRUE;

GRANT ROLE JUNIOR_ANALYST_ROLE  TO USER rahul_kumar;
GRANT ROLE SENIOR_ANALYST_ROLE  TO USER priya_sharma;
GRANT ROLE BI_DEVELOPER_ROLE    TO USER arun_thomas;
GRANT ROLE DATA_ENGINEER_ROLE   TO USER meera_nair;
GRANT ROLE DATA_SCIENTIST_ROLE  TO USER vikram_iyer;

-- A user can have multiple roles — they switch with USE ROLE
GRANT ROLE JUNIOR_ANALYST_ROLE  TO USER rahul_kumar;
GRANT ROLE BI_DEVELOPER_ROLE    TO USER rahul_kumar;  -- dual role

-- User switches role mid-session
USE ROLE JUNIOR_ANALYST_ROLE;   -- Limited access
USE ROLE BI_DEVELOPER_ROLE;     -- Broader access

-- Revoke a role from a user (off-boarding or role change)
REVOKE ROLE SENIOR_ANALYST_ROLE FROM USER priya_sharma;
GRANT  ROLE DATA_ENGINEER_ROLE  TO USER priya_sharma;  -- Promotion

SHOW USERS;
SHOW ROLES;
SHOW GRANTS TO USER rahul_kumar;

-- ==========================================
-- Authentication Overview
-- Method 1: Username & Password
-- ==========================================
USE ROLE SECURITYADMIN;
CREATE ROLE ANALYTICS_READER;

--Create user with password auth
CREATE USER analyst_user
  PASSWORD = 'SecurePass2025!'
  MUST_CHANGE_PASSWORD = TRUE
  DEFAULT_ROLE = ANALYTICS_READER;

USE ROLE ACCOUNTADMIN;
CREATE DATABASE SECURITY_DB;
USE DATABASE SECURITY_DB;
-- Create password policy
CREATE PASSWORD POLICY SECURITY_DB.PUBLIC.password_policy_prod
  PASSWORD_MIN_LENGTH = 12
  PASSWORD_MAX_LENGTH = 256
  PASSWORD_MIN_UPPER_CASE_CHARS = 1
  PASSWORD_MIN_LOWER_CASE_CHARS = 1
  PASSWORD_MIN_NUMERIC_CHARS = 1
  PASSWORD_MIN_SPECIAL_CHARS = 1
  PASSWORD_MAX_AGE_DAYS = 90
  PASSWORD_HISTORY = 10;

-- Apply policy to account
ALTER ACCOUNT SET PASSWORD POLICY password_policy_prod;

DESCRIBE PASSWORD POLICY password_policy_prod; -- show policy details

-- Username/password auth
-- Stored in Snowflake
-- Simple but risky
-- Not for production alone
-- This is baseline authentication, but Snowflake expects stronger controls like MFA or SSO in real systems.

-- MUST_CHANGE_PASSWORD
-- When user logs in first time it is forced password reset
-- This ensures credentials are never permanently shared.

-- Password Policy (VERY IMPORTANT SLIDE MOMENT)
-- Explain clearly:
-- Rule	                    Meaning
-- Min length 12	      Strong passwords
-- Upper + lower	      complexity
-- Numeric + special	  prevents weak passwords
-- Max age 90 days	      rotation policy
-- History 10	          prevents reuse

-- Account-level enforcement
ALTER ACCOUNT SET PASSWORD POLICY -- This applies globally — not just one user

-- ==========================================
-- Method 2: Multi-Factor Authentication (MFA)
-- ==========================================
-- Check MFA status
SELECT
    name,
    has_mfa,
    disabled
FROM snowflake.account_usage.users
ORDER BY has_mfa;

-- Snowflake MFA enforcement depends on organizational security architecture. In many enterprises, MFA is enforced through SSO providers like Okta, Azure AD, or PingFederate rather than directly in Snowflake.

SELECT *
FROM snowflake.account_usage.users; -- Shows Snowflake monitoring views

-- This is how most enterprises actually implement MFA.
-- User → SSO (Okta/Azure AD)
--           ↓
--        MFA happens here
--           ↓
--       Snowflake Access


-- =============================================
-- MEDIDATA ANALYTICS PLATFORM — RBAC LAB
-- =============================================

-- PHASE 1: SETUP AS ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- Create the database structure
CREATE DATABASE IF NOT EXISTS MEDIDATA_DB
  DATA_RETENTION_TIME_IN_DAYS = 7
  COMMENT = 'MediData Healthcare Analytics Platform';

CREATE SCHEMA MEDIDATA_DB.RAW
  COMMENT = 'Raw ingested data — PHI/PII present';
CREATE SCHEMA MEDIDATA_DB.STAGING
  COMMENT = 'Transformed data — PII masked';
CREATE SCHEMA MEDIDATA_DB.REPORTING
  COMMENT = 'Business-ready analytics — anonymized';
CREATE SCHEMA MEDIDATA_DB.COMPLIANCE
  COMMENT = 'Audit and compliance views — full data';

-- Create warehouses
CREATE WAREHOUSE IF NOT EXISTS MEDIDATA_ETL_WH
  WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 300 AUTO_RESUME = TRUE
  COMMENT = 'ETL and data loading warehouse';

CREATE WAREHOUSE IF NOT EXISTS MEDIDATA_ANALYTICS_WH
  WAREHOUSE_SIZE = 'SMALL' AUTO_SUSPEND = 180 AUTO_RESUME = TRUE
  COMMENT = 'Analytics and BI warehouse';

-- PHASE 2: CREATE ROLES AS SECURITYADMIN
USE ROLE SECURITYADMIN;

-- Data access roles (granular)
CREATE ROLE MEDIDATA_RAW_READ         COMMENT = 'SELECT on RAW schema — PHI access';
CREATE ROLE MEDIDATA_RAW_WRITE         COMMENT = 'INSERT/COPY on RAW schema';
CREATE ROLE MEDIDATA_STAGING_READ      COMMENT = 'SELECT on STAGING — masked data';
CREATE ROLE MEDIDATA_STAGING_WRITE     COMMENT = 'Write access to STAGING schema';
CREATE ROLE MEDIDATA_REPORTING_READ    COMMENT = 'SELECT on REPORTING — anonymized';
CREATE ROLE MEDIDATA_COMPLIANCE_READ   COMMENT = 'SELECT on COMPLIANCE schema';
CREATE ROLE MEDIDATA_ETL_WH_USAGE      COMMENT = 'USAGE on ETL warehouse';
CREATE ROLE MEDIDATA_ANALYTICS_WH_USAGE COMMENT = 'USAGE on Analytics warehouse';

-- Functional roles (job-title level)
CREATE ROLE CLINICAL_ANALYST_ROLE
  COMMENT = 'Clinical Analyst — anonymized reporting read';
CREATE ROLE DATA_ENGINEER_ROLE
  COMMENT = 'Data Engineer — staging write + ETL warehouse';
CREATE ROLE BI_DEVELOPER_ROLE
  COMMENT = 'BI Developer — reporting read + analytics warehouse';
CREATE ROLE COMPLIANCE_OFFICER_ROLE
  COMMENT = 'Compliance Officer — all schemas read including PHI';
CREATE ROLE ETL_SERVICE_ROLE
  COMMENT = 'Service account role — raw write only';

-- PHASE 3: GRANT OBJECT PRIVILEGES — AS SYSADMIN
USE ROLE SYSADMIN;

-- RAW schema access
GRANT USAGE ON DATABASE MEDIDATA_DB             TO ROLE MEDIDATA_RAW_READ;
GRANT USAGE ON SCHEMA MEDIDATA_DB.RAW           TO ROLE MEDIDATA_RAW_READ;
GRANT SELECT ON ALL TABLES IN SCHEMA MEDIDATA_DB.RAW TO ROLE MEDIDATA_RAW_READ;
GRANT SELECT ON FUTURE TABLES IN SCHEMA MEDIDATA_DB.RAW TO ROLE MEDIDATA_RAW_READ;

GRANT USAGE ON DATABASE MEDIDATA_DB             TO ROLE MEDIDATA_RAW_WRITE;
GRANT USAGE ON SCHEMA MEDIDATA_DB.RAW           TO ROLE MEDIDATA_RAW_WRITE;
GRANT INSERT ON ALL TABLES IN SCHEMA MEDIDATA_DB.RAW TO ROLE MEDIDATA_RAW_WRITE;
GRANT CREATE TABLE ON SCHEMA MEDIDATA_DB.RAW    TO ROLE MEDIDATA_RAW_WRITE;

-- STAGING schema access
GRANT USAGE ON DATABASE MEDIDATA_DB             TO ROLE MEDIDATA_STAGING_READ;
GRANT USAGE ON SCHEMA MEDIDATA_DB.STAGING       TO ROLE MEDIDATA_STAGING_READ;
GRANT SELECT ON ALL TABLES IN SCHEMA MEDIDATA_DB.STAGING TO ROLE MEDIDATA_STAGING_READ;
GRANT SELECT ON FUTURE TABLES IN SCHEMA MEDIDATA_DB.STAGING TO ROLE MEDIDATA_STAGING_READ;

GRANT USAGE ON DATABASE MEDIDATA_DB             TO ROLE MEDIDATA_STAGING_WRITE;
GRANT USAGE ON SCHEMA MEDIDATA_DB.STAGING       TO ROLE MEDIDATA_STAGING_WRITE;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON ALL TABLES IN SCHEMA MEDIDATA_DB.STAGING   TO ROLE MEDIDATA_STAGING_WRITE;
GRANT CREATE TABLE ON SCHEMA MEDIDATA_DB.STAGING TO ROLE MEDIDATA_STAGING_WRITE;

-- REPORTING schema access
GRANT USAGE ON DATABASE MEDIDATA_DB             TO ROLE MEDIDATA_REPORTING_READ;
GRANT USAGE ON SCHEMA MEDIDATA_DB.REPORTING     TO ROLE MEDIDATA_REPORTING_READ;
GRANT SELECT ON ALL TABLES IN SCHEMA MEDIDATA_DB.REPORTING TO ROLE MEDIDATA_REPORTING_READ;
GRANT SELECT ON ALL VIEWS  IN SCHEMA MEDIDATA_DB.REPORTING TO ROLE MEDIDATA_REPORTING_READ;
GRANT SELECT ON FUTURE TABLES IN SCHEMA MEDIDATA_DB.REPORTING TO ROLE MEDIDATA_REPORTING_READ;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA MEDIDATA_DB.REPORTING TO ROLE MEDIDATA_REPORTING_READ;

-- Warehouse grants
GRANT USAGE ON WAREHOUSE MEDIDATA_ETL_WH        TO ROLE MEDIDATA_ETL_WH_USAGE;
GRANT USAGE ON WAREHOUSE MEDIDATA_ANALYTICS_WH  TO ROLE MEDIDATA_ANALYTICS_WH_USAGE;

-- PHASE 4: WIRE FUNCTIONAL ROLES TO DATA ACCESS ROLES
USE ROLE SECURITYADMIN;

-- Clinical Analyst: reporting read + analytics warehouse
GRANT ROLE MEDIDATA_REPORTING_READ      TO ROLE CLINICAL_ANALYST_ROLE;
GRANT ROLE MEDIDATA_ANALYTICS_WH_USAGE  TO ROLE CLINICAL_ANALYST_ROLE;

-- Data Engineer: staging read/write + ETL warehouse
GRANT ROLE MEDIDATA_STAGING_READ        TO ROLE DATA_ENGINEER_ROLE;
GRANT ROLE MEDIDATA_STAGING_WRITE       TO ROLE DATA_ENGINEER_ROLE;
GRANT ROLE MEDIDATA_ETL_WH_USAGE        TO ROLE DATA_ENGINEER_ROLE;

-- BI Developer: reporting read + analytics warehouse
GRANT ROLE MEDIDATA_REPORTING_READ      TO ROLE BI_DEVELOPER_ROLE;
GRANT ROLE MEDIDATA_ANALYTICS_WH_USAGE  TO ROLE BI_DEVELOPER_ROLE;

-- Compliance Officer: all schemas including RAW + analytics warehouse
GRANT ROLE MEDIDATA_RAW_READ            TO ROLE COMPLIANCE_OFFICER_ROLE;
GRANT ROLE MEDIDATA_STAGING_READ        TO ROLE COMPLIANCE_OFFICER_ROLE;
GRANT ROLE MEDIDATA_REPORTING_READ      TO ROLE COMPLIANCE_OFFICER_ROLE;
GRANT ROLE MEDIDATA_COMPLIANCE_READ     TO ROLE COMPLIANCE_OFFICER_ROLE;
GRANT ROLE MEDIDATA_ANALYTICS_WH_USAGE  TO ROLE COMPLIANCE_OFFICER_ROLE;

-- ETL Service Account: RAW write + ETL warehouse only
GRANT ROLE MEDIDATA_RAW_WRITE           TO ROLE ETL_SERVICE_ROLE;
GRANT ROLE MEDIDATA_ETL_WH_USAGE        TO ROLE ETL_SERVICE_ROLE;

-- ALWAYS grant to SYSADMIN
GRANT ROLE CLINICAL_ANALYST_ROLE        TO ROLE SYSADMIN;
GRANT ROLE DATA_ENGINEER_ROLE           TO ROLE SYSADMIN;
GRANT ROLE BI_DEVELOPER_ROLE            TO ROLE SYSADMIN;
GRANT ROLE COMPLIANCE_OFFICER_ROLE      TO ROLE SYSADMIN;
GRANT ROLE ETL_SERVICE_ROLE             TO ROLE SYSADMIN;

-- PHASE 5: CREATE USERS AND ASSIGN ROLES
USE ROLE SECURITYADMIN;

CREATE USER dr_priya_menon
  PASSWORD = 'MediData@2025!' MUST_CHANGE_PASSWORD = TRUE
  DEFAULT_ROLE = CLINICAL_ANALYST_ROLE
  DEFAULT_WAREHOUSE = MEDIDATA_ANALYTICS_WH
  EMAIL = 'priya.menon@medidata.com'
  COMMENT = 'Clinical Analyst — Oncology Department';
GRANT ROLE CLINICAL_ANALYST_ROLE TO USER dr_priya_menon;

CREATE USER rahul_de
  PASSWORD = 'MediData@2025!' MUST_CHANGE_PASSWORD = TRUE
  DEFAULT_ROLE = DATA_ENGINEER_ROLE
  DEFAULT_WAREHOUSE = MEDIDATA_ETL_WH
  EMAIL = 'rahul.de@medidata.com'
  COMMENT = 'Data Engineer — Clinical Data Platform';
GRANT ROLE DATA_ENGINEER_ROLE TO USER rahul_de;

CREATE USER svc_snowpipe
  DEFAULT_ROLE = ETL_SERVICE_ROLE
  DEFAULT_WAREHOUSE = MEDIDATA_ETL_WH
  COMMENT = 'Service account: Snowpipe ingestion. Owner: Data Engineering.';
GRANT ROLE ETL_SERVICE_ROLE TO USER svc_snowpipe;

-- PHASE 6: AUDIT AND VERIFICATION
-- Verify role grants
SHOW GRANTS TO ROLE CLINICAL_ANALYST_ROLE;
SHOW GRANTS TO ROLE DATA_ENGINEER_ROLE;
SHOW GRANTS TO ROLE ETL_SERVICE_ROLE;

-- Verify user role assignments
SHOW GRANTS TO USER dr_priya_menon;
SHOW GRANTS TO USER rahul_de;

-- List all users
SHOW USERS;

-- Verify database grants
SHOW GRANTS ON DATABASE MEDIDATA_DB;
SHOW GRANTS ON SCHEMA MEDIDATA_DB.REPORTING;


-- =========================================================
-- MEDIDATA — DYNAMIC DATA MASKING DEMO
-- =========================================================

-- =========================================================
-- STEP 1 — USE ADMIN ROLE
-- =========================================================
USE ROLE ACCOUNTADMIN;

-- =========================================================
-- STEP 2 — CREATE DATABASE + SCHEMA
-- =========================================================
CREATE DATABASE IF NOT EXISTS MEDIDATA_DB;

CREATE SCHEMA IF NOT EXISTS MEDIDATA_DB.STAGING;

-- =========================================================
-- STEP 3 — CREATE ROLES
-- =========================================================
CREATE ROLE IF NOT EXISTS CLINICAL_ANALYST_ROLE;
CREATE ROLE IF NOT EXISTS COMPLIANCE_OFFICER_ROLE;

-- Grant roles to SYSADMIN so you can test easily
GRANT ROLE CLINICAL_ANALYST_ROLE TO ROLE SYSADMIN;
GRANT ROLE COMPLIANCE_OFFICER_ROLE TO ROLE SYSADMIN;

-- =========================================================
-- STEP 4 — CREATE SAMPLE TABLE
-- =========================================================
USE ROLE SYSADMIN;

USE DATABASE MEDIDATA_DB;
USE SCHEMA STAGING;

CREATE OR REPLACE TABLE PATIENTS (
    patient_id      INT,
    full_name       VARCHAR,
    dob             DATE,
    aadhaar_id      VARCHAR,
    diagnosis       VARCHAR
);

-- =========================================================
-- STEP 5 — INSERT SAMPLE DATA
-- =========================================================
INSERT INTO PATIENTS VALUES
(1, 'Rajesh Kumar', '1980-03-15', '2345-6789-0123', 'Diabetes'),

(2, 'Priya Menon', '1992-07-21', '8765-4321-9876', 'Hypertension');

-- =========================================================
-- STEP 6 — GRANT ACCESS TO CLINICAL ANALYST ROLE
-- =========================================================
GRANT USAGE ON DATABASE MEDIDATA_DB
TO ROLE CLINICAL_ANALYST_ROLE;

GRANT USAGE ON SCHEMA MEDIDATA_DB.STAGING
TO ROLE CLINICAL_ANALYST_ROLE;

GRANT SELECT ON TABLE MEDIDATA_DB.STAGING.PATIENTS
TO ROLE CLINICAL_ANALYST_ROLE;

-- =========================================================
-- STEP 7 — CREATE MASKING POLICIES
-- =========================================================
USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------
-- Policy 1 — Mask Patient Name
-- ---------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mask_patient_name
AS (val VARCHAR)
RETURNS VARCHAR ->
CASE
    WHEN CURRENT_ROLE() IN (
        'COMPLIANCE_OFFICER_ROLE',
        'ACCOUNTADMIN',
        'SYSADMIN'
    )
    THEN val

    ELSE REGEXP_REPLACE(val, '[A-Za-z]', 'X')
END;

-- ---------------------------------------------------------
-- Policy 2 — Mask DOB
-- ---------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mask_dob
AS (val DATE)
RETURNS DATE ->
CASE
    WHEN CURRENT_ROLE() IN (
        'COMPLIANCE_OFFICER_ROLE',
        'ACCOUNTADMIN',
        'SYSADMIN'
    )
    THEN val

    ELSE DATE_FROM_PARTS(YEAR(val),1,1)
END;

-- ---------------------------------------------------------
-- Policy 3 — Mask Aadhaar ID
-- ---------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mask_national_id
AS (val VARCHAR)
RETURNS VARCHAR ->
CASE
    WHEN CURRENT_ROLE() IN (
        'COMPLIANCE_OFFICER_ROLE',
        'ACCOUNTADMIN',
        'SYSADMIN'
    )
    THEN val

    ELSE '****-****-****'
END;

-- ---------------------------------------------------------
-- Policy 4 — Mask Diagnosis
-- ---------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mask_diagnosis
AS (val VARCHAR)
RETURNS VARCHAR ->
CASE
    WHEN CURRENT_ROLE() IN (
        'COMPLIANCE_OFFICER_ROLE',
        'ACCOUNTADMIN',
        'SYSADMIN'
    )
    THEN val

    ELSE '*** RESTRICTED ***'
END;

-- =========================================================
-- STEP 8 — APPLY MASKING POLICIES
-- =========================================================
ALTER TABLE MEDIDATA_DB.STAGING.PATIENTS
MODIFY COLUMN full_name
SET MASKING POLICY mask_patient_name;

ALTER TABLE MEDIDATA_DB.STAGING.PATIENTS
MODIFY COLUMN dob
SET MASKING POLICY mask_dob;

ALTER TABLE MEDIDATA_DB.STAGING.PATIENTS
MODIFY COLUMN aadhaar_id
SET MASKING POLICY mask_national_id;

ALTER TABLE MEDIDATA_DB.STAGING.PATIENTS
MODIFY COLUMN diagnosis
SET MASKING POLICY mask_diagnosis;

-- =========================================================
-- STEP 9 — TEST AS SYSADMIN (FULL DATA VISIBLE)
-- =========================================================
USE ROLE SYSADMIN;

SELECT CURRENT_ROLE();

SELECT *
FROM MEDIDATA_DB.STAGING.PATIENTS;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- Rajesh Kumar
-- 1980-03-15
-- 2345-6789-0123
-- Diabetes

-- =========================================================
-- STEP 10 — TEST AS CLINICAL_ANALYST_ROLE
-- =========================================================
USE ROLE CLINICAL_ANALYST_ROLE;

SELECT CURRENT_ROLE();

SELECT *
FROM MEDIDATA_DB.STAGING.PATIENTS;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- XXXXXX XXXXX
-- 1980-01-01
-- ****-****-****
-- *** RESTRICTED ***

-- =========================================================
-- ROW ACCESS POLICIES — REGIONAL DATA ISOLATION
-- =========================================================
-- Scenario:
-- APAC analysts → only APAC rows
-- EMEA analysts → only EMEA rows
-- GLOBAL analysts → all rows
-- ACCOUNTADMIN/SYSADMIN → all rows

-- =========================================================
-- STEP 1 — USE ADMIN ROLE
-- =========================================================
USE ROLE ACCOUNTADMIN;

-- =========================================================
-- STEP 2 — CREATE DATABASE + SCHEMA
-- =========================================================
CREATE DATABASE IF NOT EXISTS SALES_DB;

CREATE SCHEMA IF NOT EXISTS SALES_DB.REPORTING;

-- =========================================================
-- STEP 3 — CREATE ROLES
-- =========================================================
CREATE ROLE IF NOT EXISTS APAC_ANALYST_ROLE;
CREATE ROLE IF NOT EXISTS EMEA_ANALYST_ROLE;
CREATE ROLE IF NOT EXISTS AMERICAS_ANALYST_ROLE;
CREATE ROLE IF NOT EXISTS GLOBAL_ANALYST_ROLE;

-- Optional: grant to SYSADMIN for testing
GRANT ROLE APAC_ANALYST_ROLE TO ROLE SYSADMIN;
GRANT ROLE EMEA_ANALYST_ROLE TO ROLE SYSADMIN;
GRANT ROLE AMERICAS_ANALYST_ROLE TO ROLE SYSADMIN;
GRANT ROLE GLOBAL_ANALYST_ROLE TO ROLE SYSADMIN;

-- =========================================================
-- STEP 4 — CREATE SALES TABLE
-- =========================================================
USE ROLE ACCOUNTADMIN;

USE DATABASE SALES_DB;
USE SCHEMA REPORTING;

CREATE OR REPLACE TABLE SALES_FACT (
    sale_id         INT,
    customer_name   VARCHAR,
    region          VARCHAR,
    sales_amount    NUMBER(10,2)
);

-- =========================================================
-- STEP 5 — INSERT SAMPLE DATA
-- =========================================================
INSERT INTO SALES_FACT VALUES
(1, 'ABC Corp', 'APAC',      12000),
(2, 'XYZ Ltd',  'EMEA',      18000),
(3, 'Nova Inc', 'Americas',  25000),
(4, 'Zen Corp', 'APAC',      15000),
(5, 'Beta LLC', 'EMEA',      22000),
(6, 'Delta Co', 'Americas',  30000);

-- =========================================================
-- STEP 6 — CREATE ROLE-REGION MAPPING TABLE
-- =========================================================
CREATE OR REPLACE TABLE SALES_ROLE_REGION_MAP (
    role_name   VARCHAR(100),
    region      VARCHAR(50)
);

INSERT INTO SALES_ROLE_REGION_MAP VALUES
('APAC_ANALYST_ROLE',      'APAC'),
('EMEA_ANALYST_ROLE',      'EMEA'),
('AMERICAS_ANALYST_ROLE',  'Americas'),
('GLOBAL_ANALYST_ROLE',    'APAC'),
('GLOBAL_ANALYST_ROLE',    'EMEA'),
('GLOBAL_ANALYST_ROLE',    'Americas');

-- =========================================================
-- STEP 7 — GRANT ACCESS TO ROLES
-- =========================================================
GRANT USAGE ON DATABASE SALES_DB
TO ROLE APAC_ANALYST_ROLE;

GRANT USAGE ON SCHEMA SALES_DB.REPORTING
TO ROLE APAC_ANALYST_ROLE;

GRANT SELECT ON TABLE SALES_DB.REPORTING.SALES_FACT
TO ROLE APAC_ANALYST_ROLE;

-- ---------------------------------------------------------

GRANT USAGE ON DATABASE SALES_DB
TO ROLE EMEA_ANALYST_ROLE;

GRANT USAGE ON SCHEMA SALES_DB.REPORTING
TO ROLE EMEA_ANALYST_ROLE;

GRANT SELECT ON TABLE SALES_DB.REPORTING.SALES_FACT
TO ROLE EMEA_ANALYST_ROLE;

-- ---------------------------------------------------------

GRANT USAGE ON DATABASE SALES_DB
TO ROLE AMERICAS_ANALYST_ROLE;

GRANT USAGE ON SCHEMA SALES_DB.REPORTING
TO ROLE AMERICAS_ANALYST_ROLE;

GRANT SELECT ON TABLE SALES_DB.REPORTING.SALES_FACT
TO ROLE AMERICAS_ANALYST_ROLE;

-- ---------------------------------------------------------

GRANT USAGE ON DATABASE SALES_DB
TO ROLE GLOBAL_ANALYST_ROLE;

GRANT USAGE ON SCHEMA SALES_DB.REPORTING
TO ROLE GLOBAL_ANALYST_ROLE;

GRANT SELECT ON TABLE SALES_DB.REPORTING.SALES_FACT
TO ROLE GLOBAL_ANALYST_ROLE;

-- =========================================================
-- STEP 8 — CREATE ROW ACCESS POLICY
-- =========================================================
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE ROW ACCESS POLICY regional_data_policy
AS (region VARCHAR)
RETURNS BOOLEAN ->

    CURRENT_ROLE() IN ('ACCOUNTADMIN','SYSADMIN')

    OR EXISTS (

        SELECT 1
        FROM SALES_DB.REPORTING.SALES_ROLE_REGION_MAP

        WHERE role_name = CURRENT_ROLE()

        AND SALES_ROLE_REGION_MAP.region = region
    );

-- =========================================================
-- STEP 9 — APPLY POLICY TO TABLE
-- =========================================================
ALTER TABLE SALES_DB.REPORTING.SALES_FACT
ADD ROW ACCESS POLICY regional_data_policy
ON (region);

-- =========================================================
-- STEP 10 — TEST AS SYSADMIN
-- =========================================================
USE ROLE SYSADMIN;

SELECT CURRENT_ROLE();

SELECT region, COUNT(*)
FROM SALES_DB.REPORTING.SALES_FACT
GROUP BY region;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- APAC       2
-- EMEA       2
-- Americas   2

-- =========================================================
-- STEP 11 — TEST AS APAC ANALYST
-- =========================================================
USE ROLE APAC_ANALYST_ROLE;

SELECT CURRENT_ROLE();

SELECT region, COUNT(*)
FROM SALES_DB.REPORTING.SALES_FACT
GROUP BY region;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- APAC       2

-- =========================================================
-- STEP 12 — TEST AS EMEA ANALYST
-- =========================================================
USE ROLE EMEA_ANALYST_ROLE;

SELECT CURRENT_ROLE();

SELECT region, COUNT(*)
FROM SALES_DB.REPORTING.SALES_FACT
GROUP BY region;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- EMEA       2

-- =========================================================
-- STEP 13 — TEST AS GLOBAL ANALYST
-- =========================================================
USE ROLE GLOBAL_ANALYST_ROLE;

SELECT CURRENT_ROLE();

SELECT region, COUNT(*)
FROM SALES_DB.REPORTING.SALES_FACT
GROUP BY region;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- APAC       2
-- EMEA       2
-- Americas   2


-- =========================================================
-- ACCESS HISTORY & AUDITING — LIVE DEMO
-- =========================================================

USE ROLE ACCOUNTADMIN;

-- =========================================================
-- QUERY 1 — QUERY HISTORY
-- Who accessed what in last 7 days?
-- =========================================================
SELECT
    start_time,
    user_name,
    role_name,
    database_name,
    schema_name,
    execution_status,
    query_text
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 50;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- QUERY_START_TIME
-- USER_NAME
-- ROLE_NAME
-- DATABASE_NAME
-- QUERY_TEXT
-- EXECUTION_STATUS

-- =========================================================
-- QUERY 2 — LOGIN HISTORY
-- Detect unusual login attempts
-- =========================================================
SELECT
    event_timestamp,
    user_name,
    client_ip,
    reported_client_type,
    is_success,
    error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- USER_NAME
-- CLIENT_IP
-- IS_SUCCESS
-- ERROR_MESSAGE

-- =========================================================
-- QUERY 3 — FAILED LOGIN ANALYSIS
-- Security investigation
-- =========================================================
SELECT
    user_name,
    client_ip,
    COUNT(*) AS failed_attempts
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE is_success = 'NO'
AND event_timestamp >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
GROUP BY user_name, client_ip
HAVING COUNT(*) > 3
ORDER BY failed_attempts DESC;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- USER_NAME
-- CLIENT_IP
-- FAILED_ATTEMPTS

-- =========================================================
-- QUERY 4 — ACCESS HISTORY
-- Who queried sensitive tables?
-- =========================================================
SELECT
    ah.query_start_time,
    ah.user_name,
    qh.role_name,
    ah.direct_objects_accessed
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah
JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
  ON ah.query_id = qh.query_id
WHERE ah.query_start_time >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
ORDER BY ah.query_start_time DESC
LIMIT 50;

-- =========================================================
-- IMPORTANT NOTE FOR TRAINING
-- =========================================================
-- ACCESS_HISTORY may have 45–90 minute latency.
-- Some trial accounts may not expose full access history.

-- =========================================================
-- QUERY 5 — ROLE GRANT AUDIT
-- Who granted which role?
-- =========================================================
SELECT
    created_on,
    role,
    grantee_name,
    granted_by
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
ORDER BY created_on DESC
LIMIT 50;

-- =========================================================
-- EXPECTED OUTPUT
-- =========================================================
-- CREATED_ON
-- ROLE
-- GRANTEE_NAME
-- GRANTED_BY

-- =========================================================
-- QUERY 6 — USERS WITHOUT MFA
-- Compliance monitoring
-- =========================================================
SELECT
    name,
    login_name,
    email,
    created_on,
    disabled
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE disabled = FALSE
AND name NOT ILIKE 'SVC_%'
ORDER BY created_on DESC;

-- =========================================================
-- NOTE:
-- has_mfa column may not exist in all Snowflake editions.
-- Some orgs enforce MFA externally through SSO/Okta/Azure AD.
-- =========================================================

-- =========================================================
-- BONUS QUERY — ACTIVE ROLES
-- =========================================================
SHOW ROLES;

-- =========================================================
-- BONUS QUERY — USER ROLE ASSIGNMENTS
-- =========================================================
SHOW GRANTS TO USER rahul_de;

-- =========================================================
-- BONUS QUERY — CURRENT SESSION CONTEXT
-- =========================================================
SELECT
    CURRENT_USER(),
    CURRENT_ROLE(),
    CURRENT_WAREHOUSE(),
    CURRENT_DATABASE(),
    CURRENT_SCHEMA();

    