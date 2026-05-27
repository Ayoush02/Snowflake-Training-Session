-- =========================================================
-- SNOWFLAKE ICEBERG TABLE 
-- =========================================================

-- CREATE DATABASE & SCHEMA


CREATE OR REPLACE DATABASE ORDERS_DB;
CREATE OR REPLACE SCHEMA ORDERS_DB.ORDERS_SCHEMA;

create or replace file format csv_format
                    type = csv
                    skip_header = 1
                    null_if = ('NULL', 'null')
                    empty_field_as_null = true;

--upload both files
create or replace stage orders_db.orders_schema.iceberg_load
file_format = orders_db.orders_schema.csv_format;
  
list @orders_db.orders_schema.iceberg_load;

-- tables just for testing
create or replace iceberg table customer_detail (
  CUST_NUM varchar,
  CUST_STAT varchar,
  CUST_BAL number(10,0),
  INV_NO varchar,
  INV_AMT number(10,2),
  CRID varchar,
  SSN varchar,
  phone number(10,0),
  Email varchar
)

create or replace table Accessory_Detail (
  CUST_NUM varchar,
  Accessory varchar,
  status varchar,
  amount number(10,0),
  renewal varchar
);

  

create external volume iceberg_int
  storage_locations =
  (
    (
    name = 'iceberg_bucket'
    storage_provider = 'S3'
    storage_base_url = 's3://icebergconfigbucket/'
    storage_aws_role_arn = 'arn:aws:iam::913267004595:role/icebergconfigrole'
    )
   );

   describe external volume iceberg_int;

{"NAME":"iceberg_bucket",
  "STORAGE_PROVIDER":"S3",
  "STORAGE_BASE_URL":"s3://icebergconfigbucket/",
  "STORAGE_ALLOWED_LOCATIONS"["s3://icebergconfigbucket/*"],
  "STORAGE_AWS_ROLE_ARN":"arn:aws:iam::913267004595:role/icebergconfigrole",
  "STORAGE_AWS_IAM_USER_ARN":"arn:aws:iam::940482405254:user/hzdt0000s",
  "STORAGE_AWS_EXTERNAL_ID":"RU48962_SFCRole=2_iMI2Dcus3iSF+ArSHAB83WJ8twQ=",
  "ENCRYPTION_TYPE":"NONE","ENCRYPTION_KMS_KEY_ID":""
};


create or replace iceberg table customer_detail (
CUST_NUM varchar,
CUST_STAT varchar ,
CUST_BAL number(10,0),
INV_NO varchar ,
INV_AMT number(10,2),
CRID varchar ,
SSN varchar,
phone number(10,0),
Email varchar
)
CATALOG = 'SNOWFLAKE'
external_volume='iceberg_int'
BASE_LOCATION = 'CUSTOMER_INFO';

show tables;

copy into customer_detail
from @orders_db.orders_schema.iceberg_load/Customer_Invoice.csv
on_error = CONTINUE;

select * from customer_detail;

-- Since Iceberg stores Parquet files in S3, you can inspect them using Parquet viewers.
-- https://www.tablab.app/parquet/view

create or replace table Accessory_Detail (
CUST_NUM varchar,
Accessory varchar ,
status varchar ,
amount number(10,0),
renewal varchar 
  
);

copy into Accessory_Detail
from @orders_db.orders_schema.iceberg_load/Accessory.csv
on_error = CONTINUE;

select * from Accessory_Detail;
select * from customer_detail;

select * from customer_detail c,accessory_detail a
where c.cust_num = a.cust_num;


CREATE MASKING POLICY mask_ssn_policy AS (val STRING) 
RETURNS STRING ->
CASE
    WHEN CURRENT_ROLE() IN ('OPS', 'SECURITY_ADMIN') THEN val
    ELSE 'XXX-XX-' || RIGHT(val, 4)
END;

ALTER ICEBERG TABLE customer_detail MODIFY COLUMN SSN SET MASKING POLICY mask_ssn_policy;


CREATE OR REPLACE ROW ACCESS POLICY CRID_ACCESS_POLICY
AS (crid_column STRING) RETURNS BOOLEAN ->
    CASE 
        -- Example: Allow users with role 'CRID_ACCESS_ROLE' to see all rows
        WHEN CURRENT_ROLE() = 'CRID_ACCESS_ROLE' THEN TRUE 
        -- Restrict access for others based on CRID
        WHEN crid_column LIKE '2Z3%' THEN TRUE
        ELSE FALSE
    END;

ALTER iceberg TABLE customer_detail ADD ROW ACCESS POLICY CRID_ACCESS_POLICY ON (CRID);


select * from Filtered_Customer_Accessory;


CREATE OR REPLACE ICEBERG TABLE Customer_Accessory_iceberg (
    CUSTOMER_ID varchar,
    status varchar ,
    customer_bal number(10,0),
    Accessory varchar ,
    Accessory_Status varchar,
    amount number(10,0) 
)
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = 'iceberg_int'
    BASE_LOCATION = 'CUST_ACCESSORY';

    select * from Customer_Accessory_iceberg;


------------------------------------------------------- End-to-End Data Validation Pipeline --------------------------------------------------

-- ============================================================
-- STEP 0: Storage Integration + Email Integration
-- Run as: ACCOUNTADMIN
-- ============================================================
USE ROLE ACCOUNTADMIN;

-- Create S3 Storage Integration
CREATE STORAGE INTEGRATION S3_STORAGE_INTEGRATION
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789012:role/snowflake-s3-role'
    STORAGE_ALLOWED_LOCATIONS = ('s3://your-bucket/transactions/');

-- IMPORTANT: Run DESC to get IAM user & external ID for AWS Trust Policy
DESC INTEGRATION S3_STORAGE_INTEGRATION;
-- Copy: STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID
-- Paste these into your AWS IAM Role Trust Relationship

-- Create Email Notification Integration
CREATE NOTIFICATION INTEGRATION EMAIL_NOTIFICATION_INTEGRATION
    TYPE = EMAIL
    ENABLED = TRUE;

-- Grant integration usage to pipeline role
GRANT USAGE ON INTEGRATION S3_STORAGE_INTEGRATION
    TO ROLE DATA_ENGINEER_ROLE;
GRANT USAGE ON INTEGRATION EMAIL_NOTIFICATION_INTEGRATION
    TO ROLE DATA_ENGINEER_ROLE;

-- ============================================================
-- STEP 1: Set execution context
-- ============================================================
USE ROLE DATA_ENGINEER_ROLE;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================
-- STEP 2: Create databases and schemas
-- ============================================================
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB;

CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.RAW;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.DIM;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.DQ_MONITORING;

-- ============================================================
-- STEP 3: File Format for CSV ingestion
-- ============================================================
USE SCHEMA ANALYTICS_DB.RAW;

CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null', 'N/A', 'NA')
    EMPTY_FIELD_AS_NULL = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    DATE_FORMAT = 'YYYY-MM-DD'
    TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS';


-- ============================================================
-- STEP 4: External Stage pointing to S3 incoming folder
-- ============================================================
CREATE OR REPLACE STAGE S3_TRANSACTION_STAGE
    STORAGE_INTEGRATION = S3_STORAGE_INTEGRATION
    URL = 's3://your-bucket/transactions/incoming/'
    FILE_FORMAT = CSV_FORMAT
    COMMENT = 'Landing zone for TRANSACTION CSV files from AWS S3';

-- Verify stage connectivity (should list CSV files)
LIST @S3_TRANSACTION_STAGE;

 
-- ============================================================
-- STEP 5: Main target table in RAW schema
-- ============================================================
CREATE TABLE IF NOT EXISTS ANALYTICS_DB.RAW.TRANSACTION (
    TRANSACTION_ID       VARCHAR(36)       NOT NULL,
    CUSTOMER_ID          VARCHAR(36)       NOT NULL,
    PRODUCT_ID           VARCHAR(36)       NOT NULL,
    TRANSACTION_DATE     DATE              NOT NULL,
    AMOUNT               FLOAT             NOT NULL,
    QUANTITY             INT               NOT NULL,
    STATUS               VARCHAR(20)       NOT NULL,
    REGION               VARCHAR(50)       NOT NULL,
    CURRENCY             VARCHAR(3)        NOT NULL,
    CREATED_AT           TIMESTAMP_NTZ     DEFAULT CURRENT_TIMESTAMP(),
    -- Pipeline audit columns (added automatically on load)
    _DQ_PIPELINE_RUN_ID  VARCHAR(36),
    _SOURCE_FILE_NAME    VARCHAR(500),
    _LOADED_AT           TIMESTAMP_NTZ     DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_TRANSACTION PRIMARY KEY (TRANSACTION_ID)
);



-- ============================================================
-- STEP 6: Dimension Mock Tables for FK checks
-- ============================================================
CREATE TABLE IF NOT EXISTS ANALYTICS_DB.DIM.CUSTOMERS (
    CUSTOMER_ID    VARCHAR(36)   NOT NULL PRIMARY KEY,
    CUSTOMER_NAME  VARCHAR(200),
    CREATED_AT     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS ANALYTICS_DB.DIM.PRODUCTS (
    PRODUCT_ID    VARCHAR(36)   NOT NULL PRIMARY KEY,
    PRODUCT_NAME  VARCHAR(200),
    CREATED_AT    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Seed CUSTOMERS: CUST-0000 to CUST-0049 (matches test CSV)
INSERT INTO ANALYTICS_DB.DIM.CUSTOMERS (CUSTOMER_ID, CUSTOMER_NAME)
SELECT 'CUST-' || LPAD(SEQ4()::STRING, 4, '0'),
       'Customer ' || SEQ4()
FROM TABLE(GENERATOR(ROWCOUNT => 50));

-- Seed PRODUCTS: PROD-0000 to PROD-0029 (matches test CSV)
INSERT INTO ANALYTICS_DB.DIM.PRODUCTS (PRODUCT_ID, PRODUCT_NAME)
SELECT 'PROD-' || LPAD(SEQ4()::STRING, 4, '0'),
       'Product ' || SEQ4()
FROM TABLE(GENERATOR(ROWCOUNT => 30));

-- Verify seeding
SELECT COUNT(*) AS CUSTOMER_COUNT FROM ANALYTICS_DB.DIM.CUSTOMERS; -- Should be 50
SELECT COUNT(*) AS PRODUCT_COUNT  FROM ANALYTICS_DB.DIM.PRODUCTS;  -- Should be 30

-- ============================================================
-- STEP 7: Monitoring / Audit Tables in DQ_MONITORING schema
-- ============================================================
USE SCHEMA ANALYTICS_DB.DQ_MONITORING;

-- Table 1: One row per file processed
CREATE TABLE IF NOT EXISTS FILE_PROCESSING_LOG (
    LOG_ID              INT AUTOINCREMENT PRIMARY KEY,
    PIPELINE_RUN_ID     VARCHAR(36),
    FILE_NAME           VARCHAR(500),
    FILE_SIZE_BYTES     BIGINT,
    ROW_COUNT           INT,
    COLUMN_COUNT        INT,
    PROCESSING_STATUS   VARCHAR(20),    -- PASSED / REJECTED / SKIPPED
    REJECTION_REASONS   VARCHAR(4000),
    ROWS_LOADED         INT,
    PROCESSED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    TEAM_NAME           VARCHAR(100)
);

-- Table 2: One row per check per file (granular audit trail)
CREATE TABLE IF NOT EXISTS DQ_METRICS_LOG (
    METRIC_ID           INT AUTOINCREMENT PRIMARY KEY,
    LOG_ID              INT,
    PIPELINE_RUN_ID     VARCHAR(36),
    FILE_NAME           VARCHAR(500),
    CHECK_NUMBER        INT,
    CHECK_NAME          VARCHAR(100),
    CHECK_CATEGORY      VARCHAR(20),    -- GATE / THRESHOLD / ADVISORY
    CHECK_STATUS        VARCHAR(10),    -- PASS / FAIL / WARN / SKIP
    COLUMN_NAME         VARCHAR(100),
    THRESHOLD_VALUE     VARCHAR(200),
    ACTUAL_VALUE        VARCHAR(200),
    SEVERITY            VARCHAR(10),    -- CRITICAL / HIGH / MEDIUM / LOW
    NOTES               VARCHAR(2000),
    CHECKED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Table 3: Email notification recipients
CREATE TABLE IF NOT EXISTS EMAIL_RECIPIENT_LOG (
    RECIPIENT_ID        INT AUTOINCREMENT PRIMARY KEY,
    EMAIL_ADDRESS       VARCHAR(200)  NOT NULL,
    TEAM_NAME           VARCHAR(100),
    NOTIFICATION_TYPE   VARCHAR(20),   -- FAILURE / ALL / SUMMARY
    IS_ACTIVE           BOOLEAN DEFAULT TRUE,
    ADDED_BY            VARCHAR(100),
    ADDED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Seed email recipients (update with real addresses)
INSERT INTO EMAIL_RECIPIENT_LOG (EMAIL_ADDRESS, TEAM_NAME, NOTIFICATION_TYPE, ADDED_BY)
VALUES
    ('data-engineer@yourcompany.com', 'DATA_ENGINEERING', 'FAILURE', 'SYSTEM'),
    ('data-lead@yourcompany.com',     'DATA_ENGINEERING', 'ALL',     'SYSTEM'),
    ('dq-alerts@yourcompany.com',     'DATA_ENGINEERING', 'SUMMARY', 'SYSTEM');


------------------------------------ AFTER RUNNING MAIN.PY INSIDE THE WORKSHEET EXECUTE THE BELOW CODE IN SQL WORKSHEET----------------------------------------------
-- POST PIPELINE AUDIT QUERIES
-- Run these in a Snowflake SQL Worksheet AFTER main.py runs
-- ============================================================


-- Replace <YOUR_RUN_ID> with the RUN_ID from the Python Worksheet output

-- QUERY 1: Set your Run ID here once — used in all queries below
-- ============================================================
SET RUN_ID = '<YOUR_RUN_ID>'; -- SET RUN_ID = 'abc-1234-xxxx-xxxx';  -- paste your actual run id here

-- ============================================================
-- QUERY 2: Summary — All files, pass/fail status & rows loaded
-- ============================================================
SELECT
    FILE_NAME,
    FILE_SIZE_BYTES,
    ROW_COUNT,
    PROCESSING_STATUS,
    REJECTION_REASONS,
    ROWS_LOADED,
    PROCESSED_AT
FROM ANALYTICS_DB.DQ_MONITORING.FILE_PROCESSING_LOG
WHERE PIPELINE_RUN_ID = $RUN_ID
ORDER BY PROCESSED_AT;


-- ============================================================
-- QUERY 3: Detail — Every check result for every file
-- ============================================================
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


-- ============================================================
-- QUERY 4: Only FAILED checks — quick view of what went wrong
-- ============================================================
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


-- ============================================================
-- QUERY 5: Confirm clean data loaded into RAW.TRANSACTION
-- ============================================================
SELECT
    _SOURCE_FILE_NAME,
    COUNT(*) AS ROWS_LOADED
FROM ANALYTICS_DB.RAW.TRANSACTION
GROUP BY _SOURCE_FILE_NAME
ORDER BY _SOURCE_FILE_NAME;


-- ============================================================
-- QUERY 6: Preview the actual loaded rows
-- ============================================================
SELECT *
FROM ANALYTICS_DB.RAW.TRANSACTION
WHERE _DQ_PIPELINE_RUN_ID = $RUN_ID
LIMIT 20;


-- ============================================================
-- QUERY 7: Check failure rate per check — useful for tuning
-- ============================================================
SELECT
    CHECK_NUMBER,
    CHECK_NAME,
    CHECK_CATEGORY,
    COUNT(*)                                                      AS TOTAL_RUNS,
    SUM(CASE WHEN CHECK_STATUS IN ('FAIL', 'WARN') THEN 1 ELSE 0 END) AS FAILURES,
    ROUND(FAILURES / NULLIF(TOTAL_RUNS, 0) * 100, 1)            AS FAILURE_RATE_PCT
FROM ANALYTICS_DB.DQ_MONITORING.DQ_METRICS_LOG
GROUP BY 1, 2, 3
ORDER BY FAILURE_RATE_PCT DESC;


-- ============================================================
-- QUERY 8: All rejections in the last 7 days
-- ============================================================
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
