-- ============================================================
-- END-TO-END DATA QUALITY PIPELINE
-- ============================================================
-- RUN ORDER:
--   STEP 0  → as ACCOUNTADMIN  (integrations + role grants)
--   STEP 1+ → as DATA_ENGINEER_ROLE
-- ============================================================

-- ============================================================
-- STEP 0: Storage Integration + Email Integration + Role
-- Run as: ACCOUNTADMIN
-- ============================================================
USE ROLE ACCOUNTADMIN;

-- S3 Storage Integration
CREATE STORAGE INTEGRATION IF NOT EXISTS S3_STORAGE_INTEGRATION
    TYPE                      = EXTERNAL_STAGE
    STORAGE_PROVIDER          = 'S3'
    ENABLED                   = TRUE
    STORAGE_AWS_ROLE_ARN      = 'arn:aws:iam::668461484967:role/dq-pipeline-role'
    STORAGE_ALLOWED_LOCATIONS = ('s3://snowflake-dq-pipeline-bucket/transactions/');

-- IMPORTANT: Run this and copy the output values into your AWS IAM Trust Policy
DESC INTEGRATION S3_STORAGE_INTEGRATION;
-- Copy: STORAGE_AWS_IAM_USER_ARN  →  paste into AWS IAM Role → Trust Relationships → Principal AWS
-- Copy: STORAGE_AWS_EXTERNAL_ID   →  paste into Condition sts:ExternalId

-- Email Notification Integration (Enterprise / Business Critical edition required)
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS EMAIL_NOTIFICATION_INTEGRATION
    TYPE    = EMAIL
    ENABLED = TRUE;

-- Role and grants
CREATE ROLE IF NOT EXISTS DATA_ENGINEER_ROLE;
GRANT ROLE DATA_ENGINEER_ROLE TO USER ANALYTICSWITHANAND;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE DATA_ENGINEER_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DATA_ENGINEER_ROLE;

GRANT USAGE ON INTEGRATION S3_STORAGE_INTEGRATION
    TO ROLE DATA_ENGINEER_ROLE;
    
GRANT USAGE ON INTEGRATION EMAIL_NOTIFICATION_INTEGRATION
    TO ROLE DATA_ENGINEER_ROLE;

-- ============================================================
-- STEP 1: Set Execution Context
-- ============================================================
USE ROLE      DATA_ENGINEER_ROLE;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================
-- STEP 2: Databases and Schemas
-- ============================================================
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB;
CREATE SCHEMA  IF NOT EXISTS ANALYTICS_DB.RAW;
CREATE SCHEMA  IF NOT EXISTS ANALYTICS_DB.DIM;
CREATE SCHEMA  IF NOT EXISTS ANALYTICS_DB.DQ_MONITORING;

-- ============================================================
-- STEP 3: File Formats
-- ============================================================
USE SCHEMA ANALYTICS_DB.RAW;

-- Main format (used for data loading — skips header row)
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE                       = 'CSV'
    FIELD_DELIMITER            = ','
    RECORD_DELIMITER           = '\n'       
    SKIP_HEADER                = 1
    NULL_IF                    = ('', 'NULL', 'null', 'N/A', 'NA')
    EMPTY_FIELD_AS_NULL        = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE                 = TRUE
    DATE_FORMAT                = 'YYYY-MM-DD'
    TIMESTAMP_FORMAT           = 'YYYY-MM-DD HH24:MI:SS';

-- Header-reading format (used by column count check — reads row 0 = header)
CREATE OR REPLACE FILE FORMAT CSV_FORMAT_NO_SKIP
    TYPE                       = 'CSV'
    FIELD_DELIMITER            = ','
    RECORD_DELIMITER           = '\n'        
    SKIP_HEADER                = 0
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE                 = TRUE
    NULL_IF                    = ('NULL', 'null', '');

-- ============================================================
-- STEP 4: External Stages (incoming / processed / quarantine)
-- ============================================================
CREATE OR REPLACE STAGE S3_TRANSACTION_STAGE
    STORAGE_INTEGRATION = S3_STORAGE_INTEGRATION
    URL                 = 's3://snowflake-dq-pipeline-bucket/transactions/incoming/'
    FILE_FORMAT         = CSV_FORMAT
    COMMENT             = 'Landing zone — CSV files waiting for DQ check';

CREATE OR REPLACE STAGE S3_TRANSACTION_STAGE_PROCESSED
    STORAGE_INTEGRATION = S3_STORAGE_INTEGRATION
    URL                 = 's3://snowflake-dq-pipeline-bucket/transactions/processed/'
    FILE_FORMAT         = CSV_FORMAT
    COMMENT             = 'Files that PASSED all DQ checks';

CREATE OR REPLACE STAGE S3_TRANSACTION_STAGE_QUARANTINE
    STORAGE_INTEGRATION = S3_STORAGE_INTEGRATION
    URL                 = 's3://snowflake-dq-pipeline-bucket/transactions/quarantine/'
    FILE_FORMAT         = CSV_FORMAT
    COMMENT             = 'Files that FAILED one or more DQ checks';

-- Verify connectivity — should list your uploaded CSV files
LIST @S3_TRANSACTION_STAGE;

SHOW STAGES IN SCHEMA ANALYTICS_DB.RAW;

-- ============================================================
-- STEP 5: Target Table  RAW.TRANSACTION
-- ============================================================
CREATE TABLE IF NOT EXISTS ANALYTICS_DB.RAW.TRANSACTION (
    TRANSACTION_ID        VARCHAR(36)    NOT NULL,
    CUSTOMER_ID           VARCHAR(36)    NOT NULL,
    PRODUCT_ID            VARCHAR(36)    NOT NULL,
    TRANSACTION_DATE      DATE           NOT NULL,
    AMOUNT                FLOAT          NOT NULL,
    QUANTITY              INT            NOT NULL,
    STATUS                VARCHAR(20)    NOT NULL,
    REGION                VARCHAR(50)    NOT NULL,
    CURRENCY              VARCHAR(3)     NOT NULL,
    CREATED_AT            TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    -- Pipeline audit columns (added automatically by main.py)
    _DQ_PIPELINE_RUN_ID   VARCHAR(36),
    _SOURCE_FILE_NAME     VARCHAR(500),
    _LOADED_AT            TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_TRANSACTION PRIMARY KEY (TRANSACTION_ID)
);

-- ============================================================
-- STEP 6: Dimension Mock Tables + Correct Seeding
-- ============================================================
CREATE TABLE IF NOT EXISTS ANALYTICS_DB.DIM.CUSTOMERS (
    CUSTOMER_ID    VARCHAR(36)    NOT NULL PRIMARY KEY,
    CUSTOMER_NAME  VARCHAR(200),
    CREATED_AT     TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS ANALYTICS_DB.DIM.PRODUCTS (
    PRODUCT_ID    VARCHAR(36)    NOT NULL PRIMARY KEY,
    PRODUCT_NAME  VARCHAR(200),
    CREATED_AT    TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP()
);

-- Clear any previous seeds before re-seeding
DELETE FROM ANALYTICS_DB.DIM.CUSTOMERS;
DELETE FROM ANALYTICS_DB.DIM.PRODUCTS;

-- BUG FIX: ROW_NUMBER() generates 1,2,3... → CUST-0001 to CUST-0050
-- This now EXACTLY matches the CUST_IDS used in the CSV generator:
--   CUST_IDS = [f"CUST-{str(i).zfill(4)}" for i in range(1, 51)]
INSERT INTO ANALYTICS_DB.DIM.CUSTOMERS (CUSTOMER_ID, CUSTOMER_NAME)
SELECT
    'CUST-' || LPAD(RN::STRING, 4, '0'),
    'Customer '  || RN
FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS RN
    FROM TABLE(GENERATOR(ROWCOUNT => 50))
);

-- BUG FIX: ROW_NUMBER() → PROD-0001 to PROD-0030
-- Matches: PROD_IDS = [f"PROD-{str(i).zfill(4)}" for i in range(1, 31)]
INSERT INTO ANALYTICS_DB.DIM.PRODUCTS (PRODUCT_ID, PRODUCT_NAME)
SELECT
    'PROD-' || LPAD(RN::STRING, 4, '0'),
    'Product ' || RN
FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS RN
    FROM TABLE(GENERATOR(ROWCOUNT => 30))
);

-- Verify seeding — must show exactly 50 and 30
SELECT COUNT(*) AS CUSTOMER_COUNT FROM ANALYTICS_DB.DIM.CUSTOMERS;   -- expect 50
SELECT COUNT(*) AS PRODUCT_COUNT  FROM ANALYTICS_DB.DIM.PRODUCTS;    -- expect 30

-- Quick sanity: confirm ID range matches CSV
SELECT MIN(CUSTOMER_ID), MAX(CUSTOMER_ID) FROM ANALYTICS_DB.DIM.CUSTOMERS;
-- expect: CUST-0001  |  CUST-0050

SELECT MIN(PRODUCT_ID), MAX(PRODUCT_ID) FROM ANALYTICS_DB.DIM.PRODUCTS;
-- expect: PROD-0001  |  PROD-0030

-- ============================================================
-- STEP 7: Monitoring / Audit Tables
-- ============================================================
USE SCHEMA ANALYTICS_DB.DQ_MONITORING;

-- One row per file per pipeline run
CREATE TABLE IF NOT EXISTS FILE_PROCESSING_LOG (
    LOG_ID             INT AUTOINCREMENT PRIMARY KEY,
    PIPELINE_RUN_ID    VARCHAR(36),
    FILE_NAME          VARCHAR(500),
    FILE_SIZE_BYTES    BIGINT,
    ROW_COUNT          INT,
    COLUMN_COUNT       INT,
    PROCESSING_STATUS  VARCHAR(20),     -- PASSED / REJECTED / SKIPPED
    REJECTION_REASONS  VARCHAR(4000),
    ROWS_LOADED        INT,
    PROCESSED_AT       TIMESTAMP_NTZ    DEFAULT CURRENT_TIMESTAMP(),
    TEAM_NAME          VARCHAR(100)
);

-- One row per check per file (granular audit trail)
CREATE TABLE IF NOT EXISTS DQ_METRICS_LOG (
    METRIC_ID          INT AUTOINCREMENT PRIMARY KEY,
    LOG_ID             INT,
    PIPELINE_RUN_ID    VARCHAR(36),
    FILE_NAME          VARCHAR(500),
    CHECK_NUMBER       INT,
    CHECK_NAME         VARCHAR(100),
    CHECK_CATEGORY     VARCHAR(20),     -- GATE / THRESHOLD / ADVISORY
    CHECK_STATUS       VARCHAR(10),     -- PASS / FAIL / WARN / SKIP
    COLUMN_NAME        VARCHAR(100),
    THRESHOLD_VALUE    VARCHAR(200),
    ACTUAL_VALUE       VARCHAR(200),
    SEVERITY           VARCHAR(10),     -- CRITICAL / HIGH / MEDIUM / LOW
    NOTES              VARCHAR(2000),
    CHECKED_AT         TIMESTAMP_NTZ    DEFAULT CURRENT_TIMESTAMP()
);

-- Email recipients per team
CREATE TABLE IF NOT EXISTS EMAIL_RECIPIENT_LOG (
    RECIPIENT_ID       INT AUTOINCREMENT PRIMARY KEY,
    EMAIL_ADDRESS      VARCHAR(200)     NOT NULL,
    TEAM_NAME          VARCHAR(100),
    NOTIFICATION_TYPE  VARCHAR(20),     -- FAILURE / ALL / SUMMARY
    IS_ACTIVE          BOOLEAN          DEFAULT TRUE,
    ADDED_BY           VARCHAR(100),
    ADDED_AT           TIMESTAMP_NTZ    DEFAULT CURRENT_TIMESTAMP()
);

-- Seed email recipients (update addresses as needed)
DELETE FROM ANALYTICS_DB.DQ_MONITORING.EMAIL_RECIPIENT_LOG;

INSERT INTO ANALYTICS_DB.DQ_MONITORING.EMAIL_RECIPIENT_LOG
    (EMAIL_ADDRESS, TEAM_NAME, NOTIFICATION_TYPE, ADDED_BY)
VALUES
    ('analyticswithanand@gmail.com', 'DATA_ENGINEERING', 'FAILURE', 'SYSTEM'),
    ('analyticswithanand@gmail.com', 'DATA_ENGINEERING', 'ALL',     'SYSTEM'),
    ('analyticswithanand@gmail.com', 'DATA_ENGINEERING', 'SUMMARY', 'SYSTEM');

-- Verify
SELECT * FROM ANALYTICS_DB.DQ_MONITORING.EMAIL_RECIPIENT_LOG;

-- ============================================================
-- STEP 8: (OPTIONAL) Clean slate before each test run
-- Run this if you want to reset logs and the target table
-- ============================================================
/*
TRUNCATE TABLE ANALYTICS_DB.RAW.TRANSACTION;
TRUNCATE TABLE ANALYTICS_DB.DQ_MONITORING.FILE_PROCESSING_LOG;
TRUNCATE TABLE ANALYTICS_DB.DQ_MONITORING.DQ_METRICS_LOG;
*/

-- ============================================================
-- POST-RUN AUDIT QUERIES
-- Run these AFTER main.py has executed in the Python Worksheet
-- ============================================================

-- Set your run ID (copy from Python Worksheet output)
SET RUN_ID = '314acf7a-bfa0-4310-9d26-21b79118fcf6';

-- QUERY 1: Summary — all files, status, rows loaded
SELECT
    FILE_NAME,
    FILE_SIZE_BYTES,
    ROW_COUNT,
    COLUMN_COUNT,
    PROCESSING_STATUS,
    REJECTION_REASONS,
    ROWS_LOADED,
    PROCESSED_AT
FROM ANALYTICS_DB.DQ_MONITORING.FILE_PROCESSING_LOG
WHERE PIPELINE_RUN_ID = $RUN_ID
ORDER BY PROCESSED_AT;

-- QUERY 2: Every check result for every file
SELECT
    FILE_NAME,
    CHECK_NUMBER,
    CHECK_NAME,
    CHECK_CATEGORY,
    CHECK_STATUS,
    COLUMN_NAME,
    THRESHOLD_VALUE,
    ACTUAL_VALUE,
    SEVERITY,
    NOTES
FROM ANALYTICS_DB.DQ_MONITORING.DQ_METRICS_LOG
WHERE PIPELINE_RUN_ID = $RUN_ID
ORDER BY FILE_NAME, CHECK_NUMBER;

-- QUERY 3: Only FAILED / WARN checks
SELECT
    FILE_NAME,
    CHECK_NUMBER,
    CHECK_NAME,
    COLUMN_NAME,
    THRESHOLD_VALUE,
    ACTUAL_VALUE,
    SEVERITY,
    NOTES
FROM ANALYTICS_DB.DQ_MONITORING.DQ_METRICS_LOG
WHERE PIPELINE_RUN_ID = $RUN_ID
  AND CHECK_STATUS IN ('FAIL', 'WARN')
ORDER BY FILE_NAME, CHECK_NUMBER;

-- QUERY 4: Confirm clean data loaded into RAW.TRANSACTION
SELECT
    _SOURCE_FILE_NAME,
    COUNT(*) AS ROWS_LOADED
FROM ANALYTICS_DB.RAW.TRANSACTION
GROUP BY _SOURCE_FILE_NAME
ORDER BY _SOURCE_FILE_NAME;

-- QUERY 5: Preview loaded rows
SELECT *
FROM ANALYTICS_DB.RAW.TRANSACTION
WHERE _DQ_PIPELINE_RUN_ID = $RUN_ID
LIMIT 20;

-- QUERY 6: Check failure rate per check type
SELECT
    CHECK_NUMBER,
    CHECK_NAME,
    CHECK_CATEGORY,
    COUNT(*)                                                            AS TOTAL_RUNS,
    SUM(CASE WHEN CHECK_STATUS IN ('FAIL','WARN') THEN 1 ELSE 0 END)  AS FAILURES,
    ROUND(FAILURES / NULLIF(TOTAL_RUNS,0) * 100, 1)                   AS FAILURE_RATE_PCT
FROM ANALYTICS_DB.DQ_MONITORING.DQ_METRICS_LOG
GROUP BY 1, 2, 3
ORDER BY FAILURE_RATE_PCT DESC;

-- QUERY 7: All rejections in last 7 days
SELECT
    PIPELINE_RUN_ID,
    FILE_NAME,
    PROCESSING_STATUS,
    REJECTION_REASONS,
    PROCESSED_AT
FROM ANALYTICS_DB.DQ_MONITORING.FILE_PROCESSING_LOG
WHERE PROCESSING_STATUS = 'REJECTED'
  AND PROCESSED_AT >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY PROCESSED_AT DESC;

-- QUERY 8: Latest run ID (if you forgot to copy it from Python output)
SELECT DISTINCT PIPELINE_RUN_ID, MAX(PROCESSED_AT) AS RUN_TIME
FROM ANALYTICS_DB.DQ_MONITORING.FILE_PROCESSING_LOG
GROUP BY 1
ORDER BY RUN_TIME DESC
LIMIT 5;


