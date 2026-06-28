-- ============================================================
-- SNOWFLAKE DAY 3 TRAINING: COMPLETE SETUP 
-- ============================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- STEP 1: Create Training Database
CREATE DATABASE IF NOT EXISTS TRAINING_DB
    COMMENT = 'Day 3 SQL Training Database - Snowflake Enterprise Program';
 
-- STEP 2: Create Schemas (Logical separation of data domains)
CREATE SCHEMA IF NOT EXISTS TRAINING_DB.SALES_SCHEMA
    COMMENT = 'Schema for Sales and Customer data';
 
CREATE SCHEMA IF NOT EXISTS TRAINING_DB.HR_SCHEMA
    COMMENT = 'Schema for Employee and HR data';
 
CREATE SCHEMA IF NOT EXISTS TRAINING_DB.FINANCE_SCHEMA
    COMMENT = 'Schema for Finance and Order data';
 
-- STEP 3: Set Working Context
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;

 
-- STEP 4: Verify Setup
SHOW DATABASES LIKE 'TRAINING_DB';
SHOW SCHEMAS IN DATABASE TRAINING_DB;
 
-- ============================================================
-- CREATE TABLES: CUSTOMERS
-- ============================================================
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID     NUMBER(10)      NOT NULL PRIMARY KEY,
    FIRST_NAME      VARCHAR(100)    NOT NULL,
    LAST_NAME       VARCHAR(100)    NOT NULL,
    EMAIL           VARCHAR(200)    UNIQUE,
    PHONE           VARCHAR(20),
    CITY            VARCHAR(100),
    STATE           VARCHAR(50),
    COUNTRY         VARCHAR(50)     DEFAULT 'India',
    SIGNUP_DATE     DATE,
    IS_ACTIVE       BOOLEAN         DEFAULT TRUE,
    CUSTOMER_TIER   VARCHAR(20),
    ANNUAL_REVENUE  DECIMAL(15,2),
    CREATED_AT      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Master customer dimension table';


-- ============================================================
-- CREATE TABLES: PRODUCTS
-- ============================================================
CREATE OR REPLACE TABLE PRODUCTS (
    PRODUCT_ID      NUMBER(10)      NOT NULL PRIMARY KEY,
    PRODUCT_NAME    VARCHAR(200)    NOT NULL,
    CATEGORY        VARCHAR(100),
    SUB_CATEGORY    VARCHAR(100),
    BRAND           VARCHAR(100),
    UNIT_PRICE      DECIMAL(10,2)   NOT NULL,
    COST_PRICE      DECIMAL(10,2),
    STOCK_QTY       NUMBER(10)      DEFAULT 0,
    IS_ACTIVE       BOOLEAN         DEFAULT TRUE,
    LAUNCH_DATE     DATE
)
COMMENT = 'Product catalog table';
 
-- ============================================================
-- CREATE TABLES: ORDERS
-- ============================================================
CREATE OR REPLACE TABLE ORDERS (
    ORDER_ID        NUMBER(10)      NOT NULL PRIMARY KEY,
    CUSTOMER_ID     NUMBER(10)      REFERENCES CUSTOMERS(CUSTOMER_ID),
    ORDER_DATE      DATE            NOT NULL,
    SHIP_DATE       DATE,
    STATUS          VARCHAR(30)     DEFAULT 'PENDING',
    TOTAL_AMOUNT    DECIMAL(15,2),
    DISCOUNT_PCT    DECIMAL(5,2)    DEFAULT 0,
    PAYMENT_METHOD  VARCHAR(50),
    REGION          VARCHAR(50),
    SALES_REP_ID    NUMBER(10)
)
COMMENT = 'Sales orders fact table';
 
-- ============================================================
-- CREATE TABLES: ORDER_ITEMS
-- ============================================================
CREATE OR REPLACE TABLE ORDER_ITEMS (
    ITEM_ID         NUMBER(10)      NOT NULL PRIMARY KEY,
    ORDER_ID        NUMBER(10)      REFERENCES ORDERS(ORDER_ID),
    PRODUCT_ID      NUMBER(10)      REFERENCES PRODUCTS(PRODUCT_ID),
    QUANTITY        NUMBER(10)      NOT NULL,
    UNIT_PRICE      DECIMAL(10,2)   NOT NULL,
    DISCOUNT_AMOUNT DECIMAL(10,2)   DEFAULT 0,
    LINE_TOTAL      DECIMAL(15,2)
)
COMMENT = 'Order line items — one row per product per order';
 
-- ============================================================
-- CREATE TABLES: EMPLOYEES (HR Schema)
-- ============================================================
USE SCHEMA HR_SCHEMA;
 
CREATE OR REPLACE TABLE EMPLOYEES (
    EMP_ID          NUMBER(10)      NOT NULL PRIMARY KEY,
    FIRST_NAME      VARCHAR(100),
    LAST_NAME       VARCHAR(100),
    DEPARTMENT      VARCHAR(100),
    JOB_TITLE       VARCHAR(150),
    SALARY          DECIMAL(12,2),
    HIRE_DATE       DATE,
    MANAGER_ID      NUMBER(10),
    OFFICE_CITY     VARCHAR(100),
    PERFORMANCE_RATING VARCHAR(20),
    IS_ACTIVE       BOOLEAN         DEFAULT TRUE
)
COMMENT = 'Employee master data for HR analytics';

 
-- ============================================================
-- VERIFY TABLES
-- ============================================================
SHOW TABLES IN DATABASE TRAINING_DB;

-- ============================================================
-- FILE STAGING SETUP: Create File Format & Internal Stages
-- ============================================================
-- Snowflake supports loading data from local files using Internal Stages.
-- Workflow: CREATE FILE FORMAT → CREATE STAGE → PUT file → COPY INTO table
-- Reference: https://docs.snowflake.com/en/user-guide/data-load-local-file-system

-- STEP A: Create a reusable CSV File Format
CREATE OR REPLACE FILE FORMAT TRAINING_CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMMENT = 'Standard CSV format for Day 3 training data loads';

-- STEP B: Create Internal Named Stages (one per table for clarity)

CREATE OR REPLACE STAGE STG_CUSTOMERS
    FILE_FORMAT = TRAINING_CSV_FORMAT
    COMMENT = 'Internal stage for loading CUSTOMERS CSV data';

CREATE OR REPLACE STAGE STG_PRODUCTS
    FILE_FORMAT = TRAINING_CSV_FORMAT
    COMMENT = 'Internal stage for loading PRODUCTS CSV data';

CREATE OR REPLACE STAGE STG_ORDERS
    FILE_FORMAT = TRAINING_CSV_FORMAT
    COMMENT = 'Internal stage for loading ORDERS CSV data';

CREATE OR REPLACE STAGE STG_ORDER_ITEMS
    FILE_FORMAT = TRAINING_CSV_FORMAT
    COMMENT = 'Internal stage for loading ORDER_ITEMS CSV data';

-- ============================================================
-- LOAD DATA VIA STAGING: CUSTOMERS
-- ============================================================
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;

-- STEP 1: Upload local CSV file to the internal stage using PUT

-- Run this from SnowSQL CLI (PUT is not supported in Snowflake Web UI):
-- SnowSQL is a separate command-line application that you install on your local machine.
-- Install SnowSQL
-- Download from: https://www.snowflake.com/en/developers/downloads/snowsql/
-- After Download
-- After installation open Command promp in window and run => snowsql -v
-- Connect to Snowflake
-- Run: snowsql -a <account_identifier> -u <username>
-- Then enter your password.

-- Once connected:

-- USE DATABASE MY_DB;
-- USE SCHEMA PUBLIC;

-- Now run your PUT command:

-- PUT 'file:///path/to/your/csv_data/customers.csv'
-- @STG_PRODUCTS
-- AUTO_COMPRESS=TRUE;

-- To verify the staged file:
LIST @STG_CUSTOMERS;

-- STEP 2: Load data from stage into the table using COPY INTO

COPY INTO CUSTOMERS (
    CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE,
    CITY, STATE, COUNTRY, SIGNUP_DATE, IS_ACTIVE,
    CUSTOMER_TIER, ANNUAL_REVENUE, CREATED_AT
)
FROM @STG_CUSTOMERS/customers.csv
FILE_FORMAT = TRAINING_CSV_FORMAT
ON_ERROR = 'CONTINUE'
PURGE = FALSE;

-- Verify load results
SELECT 'CUSTOMERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM CUSTOMERS;
-- Expected: 5,500 rows

-- If you want to remove the dataset from the stage 
-- REMOVE @STG_CUSTOMERS/products.csv.gz;

-- ============================================================
-- LOAD DATA VIA STAGING: PRODUCTS
-- ============================================================

-- PUT file:///path/to/your/csv_data/products.csv @STG_PRODUCTS AUTO_COMPRESS=TRUE;

LIST @STG_PRODUCTS;

COPY INTO PRODUCTS (
    PRODUCT_ID, PRODUCT_NAME, CATEGORY, SUB_CATEGORY, BRAND,
    UNIT_PRICE, COST_PRICE, STOCK_QTY, IS_ACTIVE, LAUNCH_DATE
)
FROM @STG_PRODUCTS/products.csv
FILE_FORMAT = TRAINING_CSV_FORMAT
ON_ERROR = 'CONTINUE'
PURGE = FALSE;

SELECT 
    'PRODUCTS' AS TABLE_NAME,
    COUNT(*) AS ROW_COUNT 
FROM PRODUCTS;
-- Expected: 5,200 rows

-- ============================================================
-- LOAD DATA VIA STAGING: ORDERS
-- ============================================================

-- PUT file:///path/to/your/csv_data/orders.csv @STG_ORDERS AUTO_COMPRESS=TRUE;

LIST @STG_ORDERS;

COPY INTO ORDERS (
    ORDER_ID, CUSTOMER_ID, ORDER_DATE, SHIP_DATE, STATUS,
    TOTAL_AMOUNT, DISCOUNT_PCT, PAYMENT_METHOD, REGION, SALES_REP_ID
)
FROM @STG_ORDERS/orders.csv
FILE_FORMAT = TRAINING_CSV_FORMAT
ON_ERROR = 'CONTINUE'
PURGE = FALSE;

SELECT 
    'ORDERS' AS TABLE_NAME, 
    COUNT(*) AS ROW_COUNT 
FROM ORDERS;
-- Expected: 5,500 rows

-- ============================================================
-- LOAD DATA VIA STAGING: ORDER_ITEMS
-- ============================================================

-- PUT file:///path/to/your/csv_data/order_items.csv @STG_ORDER_ITEMS AUTO_COMPRESS=TRUE;

LIST @STG_ORDER_ITEMS;

COPY INTO ORDER_ITEMS (
    ITEM_ID, ORDER_ID, PRODUCT_ID, QUANTITY,
    UNIT_PRICE, DISCOUNT_AMOUNT, LINE_TOTAL
)
FROM @STG_ORDER_ITEMS/order_items.csv
FILE_FORMAT = TRAINING_CSV_FORMAT
ON_ERROR = 'CONTINUE'
PURGE = FALSE;

SELECT 
    'ORDER_ITEMS' AS TABLE_NAME, 
    COUNT(*) AS ROW_COUNT 
FROM ORDER_ITEMS;
-- Expected: 6,000 rows

-- ============================================================
-- LOAD DATA VIA STAGING: EMPLOYEES (HR Schema)
-- ============================================================
USE SCHEMA HR_SCHEMA;

-- Create internal stage for HR data
CREATE OR REPLACE STAGE STG_EMPLOYEES
    FILE_FORMAT = TRAINING_CSV_FORMAT
    COMMENT = 'Internal stage for loading EMPLOYEES CSV data';
    
-- Here before running the PUT command change schema first to HR_SCHEMA
-- USE SCHEMA HR_SCHEMA;
-- PUT file:///path/to/your/csv_data/employees.csv @STG_EMPLOYEES AUTO_COMPRESS=TRUE;

LIST @STG_EMPLOYEES;

COPY INTO EMPLOYEES (
    EMP_ID, FIRST_NAME, LAST_NAME, DEPARTMENT, JOB_TITLE,
    SALARY, HIRE_DATE, MANAGER_ID, OFFICE_CITY,
    PERFORMANCE_RATING, IS_ACTIVE
)
FROM @STG_EMPLOYEES/employees.csv
FILE_FORMAT = TRAINING_CSV_FORMAT
ON_ERROR = 'CONTINUE'
PURGE = FALSE;

SELECT 
    'EMPLOYEES' AS TABLE_NAME,
    COUNT(*) AS ROW_COUNT 
FROM EMPLOYEES;
-- Expected: 5,000 rows

-- Verify all staged data loads
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
SELECT 'CUSTOMERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM CUSTOMERS
UNION ALL SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS
UNION ALL SELECT 'ORDERS', COUNT(*) FROM ORDERS
UNION ALL SELECT 'ORDER_ITEMS', COUNT(*) FROM ORDER_ITEMS;

-- Check stage files (should show uploaded .csv.gz files)
LIST @STG_CUSTOMERS;
LIST @STG_PRODUCTS;
LIST @STG_ORDERS;
LIST @STG_ORDER_ITEMS;

-- View COPY INTO load history for troubleshooting
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'CUSTOMERS',
    START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;

-- ALTER & DROP Commands

-- ALTER TABLE: Add a new column
ALTER TABLE CUSTOMERS 
ADD COLUMN LOYALTY_POINTS NUMBER(10) DEFAULT 0;
 
-- ALTER TABLE: Rename a column
ALTER TABLE CUSTOMERS 
RENAME COLUMN LOYALTY_POINTS TO REWARD_POINTS;
 
-- ALTER TABLE: Change data type (VARCHAR size)
ALTER TABLE CUSTOMERS 
ALTER COLUMN EMAIL SET DATA TYPE VARCHAR(300);
 
-- ALTER TABLE: Set NOT NULL constraint
ALTER TABLE CUSTOMERS 
ALTER COLUMN FIRST_NAME SET NOT NULL;
 
-- DROP a column
ALTER TABLE CUSTOMERS 
DROP COLUMN REWARD_POINTS;
 
-- DROP TABLE (be careful!)
-- DROP TABLE IF EXISTS TEMP_TABLE;
 
-- UNDROP TABLE (Snowflake-specific — recover dropped table within retention period)
-- UNDROP TABLE TEMP_TABLE;

-- ============================================================
-- SELECT FUNDAMENTALS
-- ============================================================
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
 
-- 1. Basic SELECT
SELECT * FROM CUSTOMERS;
 
-- 2. SELECT specific columns with Aliases
SELECT
    CUSTOMER_ID AS CUST_ID,
    FIRST_NAME || ' ' || LAST_NAME AS FULL_NAME,
    CITY,
    CUSTOMER_TIER AS TIER,
    ANNUAL_REVENUE
FROM CUSTOMERS;
 
-- 3. WHERE clause — filtering rows
SELECT CUSTOMER_ID, FIRST_NAME, CITY, CUSTOMER_TIER
FROM CUSTOMERS
WHERE CUSTOMER_TIER = 'GOLD'
AND IS_ACTIVE = TRUE;
 
-- 4. WHERE with multiple conditions
SELECT ORDER_ID, CUSTOMER_ID, ORDER_DATE, TOTAL_AMOUNT, STATUS
FROM ORDERS
WHERE TOTAL_AMOUNT > 50000
  AND STATUS = 'DELIVERED'
  AND ORDER_DATE >= '2024-01-01';
 
-- 5. WHERE with IN operator
SELECT FIRST_NAME, LAST_NAME, CITY, CUSTOMER_TIER
FROM CUSTOMERS
WHERE CUSTOMER_TIER IN ('GOLD','PLATINUM');
 
-- 6. WHERE with BETWEEN
SELECT ORDER_ID, ORDER_DATE, TOTAL_AMOUNT
FROM ORDERS
WHERE TOTAL_AMOUNT BETWEEN 10000 AND 150000
ORDER BY TOTAL_AMOUNT DESC;
 
-- 7. WHERE with LIKE (pattern matching)
SELECT FIRST_NAME, LAST_NAME, EMAIL
FROM CUSTOMERS
WHERE EMAIL LIKE '%@email.com'
AND FIRST_NAME LIKE 'P%';
 
-- 8. ORDER BY — ascending and descending
SELECT PRODUCT_NAME, CATEGORY, UNIT_PRICE
FROM PRODUCTS
ORDER BY CATEGORY ASC, UNIT_PRICE DESC;
 
-- 9. DISTINCT — unique values
SELECT DISTINCT CUSTOMER_TIER
FROM CUSTOMERS;
 
SELECT DISTINCT REGION, STATUS
FROM ORDERS;
 
-- 10. LIMIT — restrict rows
SELECT PRODUCT_NAME, UNIT_PRICE
FROM PRODUCTS
ORDER BY UNIT_PRICE DESC
LIMIT 5;    -- Top 5 most expensive products
 
-- ============================================================
-- GROUP BY and HAVING
-- ============================================================
 
-- 11. Basic GROUP BY — aggregate by tier
SELECT
    CUSTOMER_TIER,
    COUNT(*)                    AS TOTAL_CUSTOMERS,
    AVG(ANNUAL_REVENUE)         AS AVG_REVENUE,
    MAX(ANNUAL_REVENUE)         AS MAX_REVENUE,
    MIN(ANNUAL_REVENUE)         AS MIN_REVENUE,
    SUM(ANNUAL_REVENUE)         AS TOTAL_REVENUE
FROM CUSTOMERS
GROUP BY CUSTOMER_TIER
ORDER BY TOTAL_REVENUE DESC;
 
-- 12. GROUP BY with HAVING (filter on aggregate)
SELECT
    CUSTOMER_ID,
    COUNT(ORDER_ID) AS ORDER_COUNT,
    SUM(TOTAL_AMOUNT) AS TOTAL_SPENT
FROM ORDERS
WHERE STATUS != 'CANCELLED'
GROUP BY CUSTOMER_ID
HAVING COUNT(ORDER_ID) >= 2
ORDER BY TOTAL_SPENT DESC;
 
-- 13. GROUP BY multiple columns
SELECT
    REGION,
    STATUS,
    COUNT(*) AS ORDER_COUNT,
    ROUND(AVG(TOTAL_AMOUNT), 2) AS AVG_ORDER_VALUE
FROM ORDERS
GROUP BY REGION, STATUS
ORDER BY REGION, ORDER_COUNT DESC;

-- ============================================================
-- CASE STATEMENTS
-- ============================================================
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
 
-- 1. Simple CASE (exact match)
SELECT
    ORDER_ID,
    STATUS,
    CASE STATUS
        WHEN 'DELIVERED'  THEN 'Completed'
        WHEN 'SHIPPED'    THEN 'In Transit'
        WHEN 'PENDING'    THEN 'Awaiting Processing'
        WHEN 'CANCELLED'  THEN 'Order Cancelled'
        ELSE 'Unknown Status'
    END AS STATUS_LABEL
FROM ORDERS;
 
-- 2. Searched CASE (range conditions)
SELECT
    CUSTOMER_ID,
    FIRST_NAME,
    ANNUAL_REVENUE,
    CASE
        WHEN ANNUAL_REVENUE >= 2000000  THEN 'Enterprise'
        WHEN ANNUAL_REVENUE >= 500000   THEN 'Mid-Market'
        WHEN ANNUAL_REVENUE >= 100000   THEN 'SMB'
        ELSE 'Micro'
    END AS SEGMENT,
    CASE
        WHEN CUSTOMER_TIER = 'PLATINUM' AND IS_ACTIVE = TRUE THEN 'VIP Active'
        WHEN CUSTOMER_TIER = 'GOLD' AND IS_ACTIVE = TRUE     THEN 'Priority Active'
        WHEN IS_ACTIVE = FALSE                                THEN 'Inactive'
        ELSE 'Standard'
    END AS ACCOUNT_STATUS
FROM CUSTOMERS;
 
-- 3. CASE in GROUP BY for custom buckets
SELECT
    CASE
        WHEN TOTAL_AMOUNT >= 100000 THEN 'High Value (100K+)'
        WHEN TOTAL_AMOUNT >= 50000  THEN 'Mid Value (50K-100K)'
        WHEN TOTAL_AMOUNT >= 10000  THEN 'Low Value (10K-50K)'
        ELSE 'Micro (<10K)'
    END AS ORDER_BUCKET,
    COUNT(*)        AS ORDER_COUNT,
    SUM(TOTAL_AMOUNT) AS BUCKET_REVENUE
FROM ORDERS
GROUP BY 1   -- GROUP BY the CASE expression (positional reference)
ORDER BY BUCKET_REVENUE DESC;

-- ============================================================
-- NULL HANDLING EXAMPLES
-- ============================================================
 
-- 1. Find customers with missing email
SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE
FROM CUSTOMERS
WHERE EMAIL IS NULL;
 
-- 2. Find customers with either email or phone missing
SELECT CUSTOMER_ID, FIRST_NAME, EMAIL, PHONE
FROM CUSTOMERS
WHERE EMAIL IS NULL OR PHONE IS NULL;
 
-- 3. COALESCE — use email, fallback to phone, fallback to 'No Contact'
SELECT
    CUSTOMER_ID,
    FIRST_NAME,
    COALESCE(EMAIL, PHONE, 'No Contact Info') AS CONTACT_METHOD
FROM CUSTOMERS;
 
-- 4. IFNULL / NVL — default value for NULL
SELECT
    ORDER_ID,
    CUSTOMER_ID,
    IFNULL(SHIP_DATE, '9999-12-31')                AS EFFECTIVE_SHIP_DATE,
    NVL(DISCOUNT_PCT, 0)                           AS DISCOUNT,
    TOTAL_AMOUNT * (1 - NVL(DISCOUNT_PCT,0)/100)   AS FINAL_AMOUNT
FROM ORDERS;
 
-- 5. NULLIF — convert 0 to NULL (avoid division by zero)
SELECT
    PRODUCT_ID,
    UNIT_PRICE,
    COST_PRICE,
    UNIT_PRICE / NULLIF(COST_PRICE, 0) AS PRICE_TO_COST_RATIO
FROM PRODUCTS;
 
-- 6. NULL in aggregates — NULL is IGNORED by aggregate functions
SELECT
    COUNT(*)        AS TOTAL_CUSTOMERS,         -- Counts all rows
    COUNT(EMAIL)    AS CUSTOMERS_WITH_EMAIL,    -- Ignores NULL emails
    COUNT(PHONE)    AS CUSTOMERS_WITH_PHONE     -- Ignores NULL phones
FROM CUSTOMERS;

-- ============================================================
-- DATE & TIME FUNCTIONS IN SNOWFLAKE
-- ============================================================
 
-- Current date/time functions
SELECT
    CURRENT_DATE()          AS TODAY,
    CURRENT_TIME()          AS NOW_TIME,
    CURRENT_TIMESTAMP()     AS NOW_TS,
    GETDATE()               AS NOW_GETDATE,      -- alias
    SYSDATE()               AS SYSDATE_VAL;
 
-- DATEADD and DATEDIFF
SELECT
    ORDER_ID,
    ORDER_DATE,
    SHIP_DATE,
    DATEDIFF('day', ORDER_DATE, COALESCE(SHIP_DATE, CURRENT_DATE())) AS DAYS_TO_SHIP,
    DATEADD('day', 30, ORDER_DATE)      AS PAYMENT_DUE_DATE,
    DATEADD('month', 1, ORDER_DATE)     AS ONE_MONTH_LATER
FROM ORDERS;
 
-- Date extraction functions
SELECT
    ORDER_ID,
    ORDER_DATE,
    YEAR(ORDER_DATE)        AS ORDER_YEAR,
    MONTH(ORDER_DATE)       AS ORDER_MONTH,
    DAY(ORDER_DATE)         AS ORDER_DAY,
    DAYOFWEEK(ORDER_DATE)   AS DAY_OF_WEEK,      -- 0=Sunday
    DAYNAME(ORDER_DATE)     AS DAY_NAME,
    MONTHNAME(ORDER_DATE)   AS MONTH_NAME,
    QUARTER(ORDER_DATE)     AS QUARTER,
    WEEKOFYEAR(ORDER_DATE)  AS WEEK_NUMBER,
    DATE_TRUNC('month', ORDER_DATE) AS MONTH_START
FROM ORDERS;
 
-- Practical: Orders grouped by month
SELECT
    DATE_TRUNC('month', ORDER_DATE)     AS SALES_MONTH,
    TO_CHAR(ORDER_DATE, 'Mon YYYY')     AS MONTH_LABEL,
    COUNT(*)                            AS ORDER_COUNT,
    ROUND(SUM(TOTAL_AMOUNT)/1000, 1)    AS REVENUE_IN_K
FROM ORDERS
WHERE STATUS != 'CANCELLED'
GROUP BY 1, 2
ORDER BY 1;

-- ============================================================
-- STRING FUNCTIONS IN SNOWFLAKE
-- ============================================================
 
/*
    String Functions Covered:
    1. LTRIM()
    2. RTRIM()
    3. TRIM()
    4. SPLIT()
    5. SPLIT_PART()
    6. CONCAT()
    7. CONCAT_WS()
*/

-- -----------------------------------------------------
-- Environment Setup
-- -----------------------------------------------------

-- Assign Role
USE ROLE ACCOUNTADMIN;
-- Assign Warehouse
USE WAREHOUSE COMPUTE_WH;

-- Create Database
CREATE DATABASE IF NOT EXISTS String_SQL;

-- Use Database
USE DATABASE String_SQL;

-- Create Schema
CREATE SCHEMA IF NOT EXISTS StringFunctionsSchema;

-- Use Schema
USE SCHEMA StringFunctionsSchema;

-- -----------------------------------------------------
-- Sequence Creation (Auto Increment)
-- -----------------------------------------------------

CREATE SEQUENCE AUTO_INCREMENT_SEQUENCE
START WITH 1
INCREMENT BY 1;

-- -----------------------------------------------------
-- Table Creation
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS SALES (
    SALE_ID           INT DEFAULT AUTO_INCREMENT_SEQUENCE.NEXTVAL PRIMARY KEY NOT NULL,
    ORDER_ID          VARCHAR(100) NOT NULL,
    CUSTOMER_NAME     VARCHAR(100) NOT NULL,
    PRODUCT_NAME      VARCHAR(150) NOT NULL,
    PRODUCT_CATEGORY  VARCHAR(50),
    ORDER_CITY        VARCHAR(50),
    ORDER_STATE       VARCHAR(50),
    ORDER_COUNTRY     VARCHAR(50),
    SALES_CHANNEL     VARCHAR(50),
    PAYMENT_METHOD    VARCHAR(50),
    FEEDBACK          VARCHAR(255),
    SALE_AMOUNT       DECIMAL(10, 2),
    DISCOUNT          DECIMAL(5, 2),
    ORDER_DATE        DATE,
    SHIPPING_DATE     DATE
);


-- -----------------------------------------------------
-- File Staging Setup for SALES Table
-- -----------------------------------------------------
CREATE OR REPLACE FILE FORMAT STRING_SQL_CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    TRIM_SPACE = FALSE  -- Keep spaces for LTRIM/RTRIM/TRIM demos
    COMMENT = 'CSV format for String Functions — preserves whitespace for demos';

CREATE OR REPLACE STAGE STG_SALES
    FILE_FORMAT = STRING_SQL_CSV_FORMAT
    COMMENT = 'Internal stage for SALES string functions data';

-- Before running go to cmd and type: 
-- USE DATABASE String_SQL;
-- USE SCHEMA StringFunctionsSchema;
-- After that: 
-- Upload the CSV from your local machine using SnowSQL:
-- PUT file:///path/to/your/csv_data/sales_string.csv @STG_SALES AUTO_COMPRESS=TRUE;

LIST @STG_SALES;

COPY INTO SALES (
    ORDER_ID, CUSTOMER_NAME, PRODUCT_NAME, PRODUCT_CATEGORY,
    ORDER_CITY, ORDER_STATE, ORDER_COUNTRY,
    SALES_CHANNEL, PAYMENT_METHOD, FEEDBACK,
    SALE_AMOUNT, DISCOUNT, ORDER_DATE, SHIPPING_DATE
)
FROM @STG_SALES/sales_string.csv
FILE_FORMAT = STRING_SQL_CSV_FORMAT
ON_ERROR = 'CONTINUE'
PURGE = FALSE;

SELECT COUNT(*) AS TOTAL_ROWS FROM SALES;
-- Expected: 5,100 rows
-- -----------------------------------------------------
-- Verify Data
-- -----------------------------------------------------
SELECT *
FROM SALES;

-- =====================================================
-- STRING FUNCTION QUESTIONS
-- =====================================================
-- -----------------------------------------------------
-- Question 1 : LTRIM()
-- -----------------------------------------------------
/*
    Remove unwanted leading spaces from CUSTOMER_NAME.
    Filter only state = 'CA'.
    Sort data by SALE_ID from highest to lowest.
*/

SELECT
    SALE_ID,
    CUSTOMER_NAME,
    LENGTH(CUSTOMER_NAME) AS ORIGINAL_LENGTH,
    LTRIM(CUSTOMER_NAME) AS CLEANED_CUSTOMER_NAME,
    LENGTH(LTRIM(CUSTOMER_NAME)) AS CLEANED_LENGTH,
    ORDER_STATE
FROM SALES
WHERE ORDER_STATE = 'CA'
ORDER BY SALE_ID DESC;


-- -----------------------------------------------------
-- Question 2 : RTRIM()
-- -----------------------------------------------------
/*
    Remove unwanted trailing spaces from PRODUCT_CATEGORY.
    Filter states: CA, TX, WA
    Payment Method must be Credit Card.
*/

SELECT
    SALE_ID,
    PRODUCT_CATEGORY,
    LENGTH(PRODUCT_CATEGORY) AS ORIGINAL_LENGTH,
    RTRIM(PRODUCT_CATEGORY) AS CLEANED_PRODUCT_CATEGORY,
    LENGTH(RTRIM(PRODUCT_CATEGORY)) AS CLEANED_LENGTH
FROM SALES
WHERE
    ORDER_STATE IN ('CA', 'TX', 'WA')
    AND PAYMENT_METHOD = 'Credit Card'
ORDER BY SALE_ID ASC;


-- -----------------------------------------------------
-- Question 3 : TRIM()
-- -----------------------------------------------------
/*
    Remove unwanted characters (#, -, *) from FEEDBACK.
*/

SELECT
    SALE_ID,
    CUSTOMER_NAME,
    FEEDBACK,
    TRIM(FEEDBACK, '#-*') AS CLEANED_FEEDBACK,
    TRIM(CUSTOMER_NAME) AS CLEANED_CUSTOMER_NAME
FROM SALES;

-- -----------------------------------------------------
-- Question 4 : SPLIT()
-- -----------------------------------------------------
/*
    Split CUSTOMER_NAME into First Name and Last Name.
*/

SELECT
    SALE_ID,
    ORDER_ID,
    CUSTOMER_NAME,
    SPLIT(LTRIM(CUSTOMER_NAME), ' ') AS FIRSTNAME_LASTNAME,
    ORDER_STATE,
    SALES_CHANNEL,
    PAYMENT_METHOD
FROM SALES;

-- -----------------------------------------------------
-- Question 5 : SPLIT_PART()
-- -----------------------------------------------------
/*
    Extract First Name and Last Name separately.
*/

SELECT
    SALE_ID,
    ORDER_ID,
    CUSTOMER_NAME,
    SPLIT_PART(LTRIM(CUSTOMER_NAME), ' ', 1) AS FIRST_NAME,
    SPLIT_PART(LTRIM(CUSTOMER_NAME), ' ', 2) AS LAST_NAME,
    ORDER_STATE,
    SALES_CHANNEL,
    PAYMENT_METHOD
FROM SALES;

-- -----------------------------------------------------
-- Question 6 : CONCAT()
-- -----------------------------------------------------
/*
    Combine ORDER_STATE and ORDER_COUNTRY.
*/

SELECT
    SALE_ID,
    ORDER_ID,
    ORDER_STATE,
    ORDER_COUNTRY,
    CONCAT(ORDER_STATE, ' - ', ORDER_COUNTRY) AS ORDER_STATE_COUNTRY
FROM SALES;


-- -----------------------------------------------------
-- Question 7 : CONCAT_WS()
-- -----------------------------------------------------
/*
    Combine ORDER_STATE, ORDER_CITY, ORDER_COUNTRY.
*/

SELECT
    SALE_ID,
    ORDER_ID,
    ORDER_STATE,
    ORDER_CITY,
    ORDER_COUNTRY,
    CONCAT_WS(' - ', ORDER_STATE, ORDER_CITY, ORDER_COUNTRY) AS ORDER_STATE_CITY_COUNTRY
FROM SALES;

-- -----------------------------------------------------
-- Data Cleaning Example (Product Category)
-- -----------------------------------------------------

SELECT
    ORDER_ID,
    PRODUCT_CATEGORY,
    CONCAT(
        SPLIT_PART(PRODUCT_CATEGORY, ' ', 1),
        SPLIT_PART(PRODUCT_CATEGORY, ' ', 2)
    ) AS CLEANED_PRODUCT_CATEGORY
FROM SALES
WHERE ORDER_ID = 'ORD-1034';

-- =====================================================
-- Session : Numeric Functions in SQL (Snowflake)
-- =====================================================

-- -------------------------
-- Environment Setup
-- -------------------------

-- Assign Role
USE ROLE ACCOUNTADMIN;

-- Assign Warehouse
USE WAREHOUSE COMPUTE_WH;

-- Create Database
CREATE DATABASE IF NOT EXISTS EndtoEndSQL;

-- Use Database
USE DATABASE EndtoEndSQL;

-- Create Schema
CREATE SCHEMA IF NOT EXISTS NumericFunctionsSchema;

-- Use Schema
USE SCHEMA NumericFunctionsSchema;


-- =====================================================
-- Table Creation
-- =====================================================

CREATE TABLE IF NOT EXISTS Sales_Transactions (
    Transaction_ID        INT PRIMARY KEY,
    Customer_ID           INT,
    Transaction_Date      DATE,
    Amount_Spent          DECIMAL(10, 2),
    Discount_Percentage   DECIMAL(5, 2),
    Quantity_Purchased    INT,
    Shipping_Cost         DECIMAL(10, 2),
    Delivery_Date         DATE,
    Return_Date           DATE
);


-- =====================================================
-- File Staging Setup for Sales_Transactions Table
-- =====================================================
CREATE OR REPLACE FILE FORMAT NUMERIC_CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    TRIM_SPACE = TRUE
    COMMENT = 'CSV format for Numeric Functions training data';

CREATE OR REPLACE STAGE STG_SALES_TRANSACTIONS
    FILE_FORMAT = NUMERIC_CSV_FORMAT
    COMMENT = 'Internal stage for Sales_Transactions numeric data';

-- Before using PUT change to 
-- Use Database
-- USE DATABASE EndtoEndSQL;
-- Use Schema
-- USE SCHEMA NumericFunctionsSchema;
-- THEN Upload via SnowSQL:
-- PUT file:///path/to/your/csv_data/sales_transactions.csv @STG_SALES_TRANSACTIONS AUTO_COMPRESS=TRUE;

LIST @STG_SALES_TRANSACTIONS;

COPY INTO Sales_Transactions (
    Transaction_ID, Customer_ID, Transaction_Date,
    Amount_Spent, Discount_Percentage, Quantity_Purchased,
    Shipping_Cost, Delivery_Date, Return_Date
)
FROM @STG_SALES_TRANSACTIONS/sales_transactions.csv
FILE_FORMAT = NUMERIC_CSV_FORMAT
ON_ERROR = 'CONTINUE'
PURGE = FALSE;

SELECT COUNT(*) AS TOTAL_ROWS FROM Sales_Transactions;
-- Expected: 5,000 rows
-- =====================================================
-- Verify Data
-- =====================================================

SELECT *
FROM Sales_Transactions;


-- =====================================================
-- NUMERIC FUNCTIONS 
-- =====================================================

-- Query 1 : ABS()
SELECT
    Customer_ID,
    Amount_Spent,
    ABS(Discount_Percentage) AS ABS_DISCOUNT
FROM Sales_Transactions
WHERE Discount_Percentage < 0
ORDER BY Amount_Spent DESC;


-- Query 2 : CEIL()
SELECT
    Transaction_ID,
    Amount_Spent,
    CEIL(Shipping_Cost) AS CEIL_SHIPPING_COST
FROM Sales_Transactions
WHERE Amount_Spent > 1000
ORDER BY Transaction_Date ASC;


-- Query 3 : FLOOR()
SELECT
    Customer_ID,
    Quantity_Purchased,
    FLOOR(Shipping_Cost) AS FLOOR_SHIPPING_COST
FROM Sales_Transactions
WHERE Amount_Spent > 500
ORDER BY Quantity_Purchased DESC;


-- Query 4 : MOD()
SELECT
    Customer_ID,
    Transaction_ID,
    MOD(Amount_Spent, 7) AS REMAINDER_VALUE
FROM Sales_Transactions
WHERE Amount_Spent > 300
ORDER BY Transaction_ID ASC;


-- Query 5 : ROUND()
SELECT
    Transaction_ID,
    Amount_Spent,
    ROUND(Discount_Percentage, 0) AS ROUNDED_DISCOUNT
FROM Sales_Transactions
WHERE Discount_Percentage > 5
ORDER BY Discount_Percentage DESC;


-- Query 6 : DIV0()
SELECT
    Customer_ID,
    Quantity_Purchased,
    DIV0(Amount_Spent, Quantity_Purchased) AS AMOUNT_PER_UNIT
FROM Sales_Transactions
WHERE Quantity_Purchased <> 0
ORDER BY Customer_ID ASC;


-- Query 7 : DIV0NULL()
SELECT
    Transaction_ID,
    Amount_Spent,
    DIV0NULL(Shipping_Cost, Quantity_Purchased) AS SHIPPING_PER_UNIT
FROM Sales_Transactions
WHERE Quantity_Purchased < 3
ORDER BY Shipping_Cost DESC;


-- Query 8 : SQRT()
SELECT
    Transaction_ID,
    Amount_Spent,
    SQRT(Amount_Spent) AS SQRT_AMOUNT
FROM Sales_Transactions
WHERE Amount_Spent > 1000
ORDER BY Amount_Spent ASC;


-- Query 9 : POWER()
SELECT
    Customer_ID,
    Quantity_Purchased,
    POWER(Discount_Percentage, 2) AS DISCOUNT_SQUARE
FROM Sales_Transactions
WHERE Discount_Percentage < 10
ORDER BY Discount_Percentage ASC;


-- Query 10 : BONUS (Multiple Numeric Functions)
SELECT
    Transaction_ID,
    Amount_Spent,
    Quantity_Purchased,
    ROUND(Quantity_Purchased * Amount_Spent, 2) AS TOTAL_AMOUNT,
    CEIL(SQRT(ROUND(Quantity_Purchased * Amount_Spent, 2))) AS CEIL_SQRT_TOTAL,
    FLOOR(MOD(Amount_Spent, 500)) AS FLOOR_REMAINDER
FROM Sales_Transactions
WHERE (Quantity_Purchased * Amount_Spent) > 1000
ORDER BY Amount_Spent ASC;

-- ============================================================
-- JOINS COMPLETE DEMO
-- ============================================================
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
 
-- 1. INNER JOIN — Only customers who have orders
SELECT
    C.CUSTOMER_ID,
    C.FIRST_NAME || ' ' || C.LAST_NAME  AS CUSTOMER_NAME,
    C.CUSTOMER_TIER,
    O.ORDER_ID,
    O.ORDER_DATE,
    O.TOTAL_AMOUNT,
    O.STATUS
FROM CUSTOMERS C
INNER JOIN ORDERS O ON C.CUSTOMER_ID = O.CUSTOMER_ID
ORDER BY O.ORDER_DATE;
 
-- 2. LEFT JOIN — ALL customers, orders if they exist
SELECT
    C.CUSTOMER_ID,
    C.FIRST_NAME || ' ' || C.LAST_NAME  AS CUSTOMER_NAME,
    C.CUSTOMER_TIER,
    COALESCE(CAST(O.ORDER_ID AS VARCHAR), 'No Orders') AS ORDER_INFO,
    O.TOTAL_AMOUNT
FROM CUSTOMERS C
LEFT JOIN ORDERS O ON C.CUSTOMER_ID = O.CUSTOMER_ID
ORDER BY C.CUSTOMER_ID;
 
-- 3. Find customers who have NEVER placed an order (anti-join pattern)
SELECT
    C.CUSTOMER_ID,
    C.FIRST_NAME || ' ' || C.LAST_NAME  AS CUSTOMER_NAME,
    C.SIGNUP_DATE
FROM CUSTOMERS C
LEFT JOIN ORDERS O ON C.CUSTOMER_ID = O.CUSTOMER_ID
WHERE O.ORDER_ID IS NULL;
 
-- 4. FULL OUTER JOIN — all customers and all orders (even orphaned ones)
SELECT
    C.CUSTOMER_ID,
    C.FIRST_NAME                         AS CUSTOMER_FIRST_NAME,
    O.ORDER_ID,
    O.TOTAL_AMOUNT
FROM CUSTOMERS C
FULL OUTER JOIN ORDERS O ON C.CUSTOMER_ID = O.CUSTOMER_ID;
 
-- 5. Three-table JOIN — Customer + Order + Product (via ORDER_ITEMS)
SELECT
    C.FIRST_NAME || ' ' || C.LAST_NAME  AS CUSTOMER_NAME,
    C.CUSTOMER_TIER,
    O.ORDER_DATE,
    O.STATUS,
    P.PRODUCT_NAME,
    P.CATEGORY,
    OI.QUANTITY,
    OI.UNIT_PRICE,
    OI.LINE_TOTAL
FROM CUSTOMERS C
INNER JOIN ORDERS O      ON C.CUSTOMER_ID = O.CUSTOMER_ID
INNER JOIN ORDER_ITEMS OI ON O.ORDER_ID   = OI.ORDER_ID
INNER JOIN PRODUCTS P    ON OI.PRODUCT_ID = P.PRODUCT_ID
ORDER BY O.ORDER_DATE DESC;
 
-- 6. CROSS JOIN — Generate all product-region combinations
SELECT
    P.PRODUCT_NAME,
    P.CATEGORY,
    REGIONS.REGION_NAME
FROM PRODUCTS P
CROSS JOIN (
    SELECT 'North' AS REGION_NAME UNION ALL
    SELECT 'South' UNION ALL
    SELECT 'East'  UNION ALL
    SELECT 'West'
) REGIONS
ORDER BY P.PRODUCT_NAME, REGIONS.REGION_NAME;
 
-- 7. SELF JOIN — Employee to Manager hierarchy
USE SCHEMA HR_SCHEMA;
SELECT
    E.EMP_ID,
    E.FIRST_NAME || ' ' || E.LAST_NAME   AS EMPLOYEE_NAME,
    E.JOB_TITLE,
    M.FIRST_NAME || ' ' || M.LAST_NAME   AS MANAGER_NAME,
    M.JOB_TITLE                           AS MANAGER_TITLE
FROM EMPLOYEES E
LEFT JOIN EMPLOYEES M ON E.MANAGER_ID = M.EMP_ID
ORDER BY E.DEPARTMENT, E.EMP_ID;

-- ============================================================
-- SET OPERATORS
-- ============================================================
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
 
-- 1. UNION ALL — combine all customers and all sales reps into one contact list
SELECT CUSTOMER_ID AS ID, FIRST_NAME, LAST_NAME, 'CUSTOMER' AS SOURCE
FROM CUSTOMERS
UNION ALL
SELECT EMP_ID, FIRST_NAME, LAST_NAME, 'EMPLOYEE'
FROM TRAINING_DB.HR_SCHEMA.EMPLOYEES;
 
-- 2. UNION — active customers from two different date ranges (removes dups if any)
SELECT CUSTOMER_ID FROM CUSTOMERS WHERE SIGNUP_DATE < '2022-01-01'
UNION
SELECT CUSTOMER_ID FROM CUSTOMERS WHERE ANNUAL_REVENUE > 500000;
 
-- 3. INTERSECT — customers who BOTH signed up before 2022 AND have high revenue
SELECT CUSTOMER_ID FROM CUSTOMERS WHERE SIGNUP_DATE < '2022-01-01'
INTERSECT
SELECT CUSTOMER_ID FROM CUSTOMERS WHERE ANNUAL_REVENUE > 500000;
 
-- 4. MINUS — customers who signed up before 2022 but do NOT have high revenue
SELECT CUSTOMER_ID FROM CUSTOMERS WHERE SIGNUP_DATE < '2022-01-01'
MINUS
SELECT CUSTOMER_ID FROM CUSTOMERS WHERE ANNUAL_REVENUE > 500000;

-- ============================================================
-- SUBQUERIES
-- ============================================================
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
 
-- 1. Subquery in WHERE (Scalar subquery — returns one value)
-- Find customers whose annual revenue is above average
SELECT CUSTOMER_ID, FIRST_NAME, ANNUAL_REVENUE
FROM CUSTOMERS
WHERE ANNUAL_REVENUE > (
    SELECT AVG(ANNUAL_REVENUE) FROM CUSTOMERS
)
ORDER BY ANNUAL_REVENUE DESC;
 
-- 2. Subquery with IN (Multi-row subquery)
-- Find customers who have placed at least one delivered order
SELECT CUSTOMER_ID, FIRST_NAME, CITY, CUSTOMER_TIER
FROM CUSTOMERS
WHERE CUSTOMER_ID IN (
    SELECT DISTINCT CUSTOMER_ID
    FROM ORDERS
    WHERE STATUS = 'DELIVERED'
);
 
-- 3. Subquery with NOT IN (Anti-join)
-- Customers who have NEVER placed a delivered order
SELECT CUSTOMER_ID, FIRST_NAME
FROM CUSTOMERS
WHERE CUSTOMER_ID NOT IN (
    SELECT DISTINCT CUSTOMER_ID FROM ORDERS WHERE STATUS = 'DELIVERED'
);
 
-- 4. Subquery in FROM (Derived table / inline view)
SELECT
    TIER_SUMMARY.CUSTOMER_TIER,
    TIER_SUMMARY.CUSTOMER_COUNT,
    TIER_SUMMARY.AVG_REVENUE,
    ROUND(TIER_SUMMARY.AVG_REVENUE / SUM(TIER_SUMMARY.AVG_REVENUE) OVER() * 100, 1) AS PCT_OF_TOTAL
FROM (
    SELECT
        CUSTOMER_TIER,
        COUNT(*) AS CUSTOMER_COUNT,
        AVG(ANNUAL_REVENUE) AS AVG_REVENUE
    FROM CUSTOMERS
    GROUP BY CUSTOMER_TIER
) AS TIER_SUMMARY
ORDER BY AVG_REVENUE DESC;
 
-- 5. Correlated Subquery — inner query references outer query
-- Find orders where TOTAL_AMOUNT > average order value for THAT customer
SELECT
    O.ORDER_ID,
    O.CUSTOMER_ID,
    O.TOTAL_AMOUNT,
    O.ORDER_DATE
FROM ORDERS O
WHERE O.TOTAL_AMOUNT > (
    SELECT AVG(O2.TOTAL_AMOUNT)
    FROM ORDERS O2
    WHERE O2.CUSTOMER_ID = O.CUSTOMER_ID   -- correlated reference
);

-- ============================================================
-- COMMON TABLE EXPRESSIONS (CTEs)
-- ============================================================
 
-- 1. Basic CTE — cleaner alternative to subquery
WITH HIGH_VALUE_CUSTOMERS AS (
    SELECT
        CUSTOMER_ID,
        FIRST_NAME || ' ' || LAST_NAME  AS CUSTOMER_NAME,
        CUSTOMER_TIER,
        ANNUAL_REVENUE
    FROM CUSTOMERS
    WHERE ANNUAL_REVENUE > 500000
      AND IS_ACTIVE = TRUE
)
SELECT
    HVC.CUSTOMER_NAME,
    HVC.CUSTOMER_TIER,
    COUNT(O.ORDER_ID)       AS ORDER_COUNT,
    SUM(O.TOTAL_AMOUNT)     AS LIFETIME_VALUE
FROM HIGH_VALUE_CUSTOMERS HVC
LEFT JOIN ORDERS O ON HVC.CUSTOMER_ID = O.CUSTOMER_ID
GROUP BY HVC.CUSTOMER_NAME, HVC.CUSTOMER_TIER
ORDER BY LIFETIME_VALUE DESC;
 
-- 2. Multiple CTEs (chained CTEs)
WITH
CUSTOMER_ORDERS AS (
    SELECT
        C.CUSTOMER_ID,
        C.FIRST_NAME || ' ' || C.LAST_NAME AS CUSTOMER_NAME,
        C.CUSTOMER_TIER,
        COUNT(O.ORDER_ID)        AS TOTAL_ORDERS,
        SUM(O.TOTAL_AMOUNT)      AS TOTAL_SPENT,
        MAX(O.ORDER_DATE)        AS LAST_ORDER_DATE
    FROM CUSTOMERS C
    LEFT JOIN ORDERS O ON C.CUSTOMER_ID = O.CUSTOMER_ID
    GROUP BY C.CUSTOMER_ID, C.FIRST_NAME, C.LAST_NAME, C.CUSTOMER_TIER
),
ORDER_SEGMENTS AS (
    SELECT
        *,
        CASE
            WHEN TOTAL_ORDERS >= 3  THEN 'Loyal'
            WHEN TOTAL_ORDERS = 2   THEN 'Repeat'
            WHEN TOTAL_ORDERS = 1   THEN 'One-Time'
            ELSE 'Prospect'
        END AS PURCHASE_SEGMENT
    FROM CUSTOMER_ORDERS
)
SELECT
    PURCHASE_SEGMENT,
    COUNT(*) AS CUSTOMERS,
    ROUND(AVG(TOTAL_SPENT), 0) AS AVG_SPEND,
    ROUND(AVG(TOTAL_ORDERS), 1) AS AVG_ORDERS
FROM ORDER_SEGMENTS
GROUP BY PURCHASE_SEGMENT
ORDER BY AVG_SPEND DESC;

-- ============================================================
-- TEMPORARY AND TRANSIENT TABLES
-- ============================================================
 
-- 1. Temporary Table — only exists in current session
CREATE TEMPORARY TABLE TEMP_ORDER_SUMMARY AS
SELECT
    O.CUSTOMER_ID,
    C.FIRST_NAME || ' ' || C.LAST_NAME  AS CUSTOMER_NAME,
    C.CUSTOMER_TIER,
    COUNT(O.ORDER_ID)       AS ORDER_COUNT,
    SUM(O.TOTAL_AMOUNT)     AS TOTAL_REVENUE,
    MIN(O.ORDER_DATE)       AS FIRST_ORDER,
    MAX(O.ORDER_DATE)       AS LAST_ORDER
FROM ORDERS O
JOIN CUSTOMERS C ON O.CUSTOMER_ID = C.CUSTOMER_ID
WHERE O.STATUS != 'CANCELLED'
GROUP BY O.CUSTOMER_ID, C.FIRST_NAME, C.LAST_NAME, C.CUSTOMER_TIER;
 
SELECT * FROM TEMP_ORDER_SUMMARY ORDER BY TOTAL_REVENUE DESC;
 
-- 2. Transient Table — persists across sessions, no fail-safe
CREATE TRANSIENT TABLE IF NOT EXISTS STAGING_ORDERS (
    ORDER_ID        NUMBER,
    CUSTOMER_ID     NUMBER,
    ORDER_DATE      DATE,
    TOTAL_AMOUNT    DECIMAL(15,2),
    LOAD_TIMESTAMP  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================
-- VIEWS
-- ============================================================
 
-- 1. Standard View — no data storage, just a saved query
CREATE OR REPLACE VIEW VW_CUSTOMER_360 AS
SELECT
    C.CUSTOMER_ID,
    C.FIRST_NAME || ' ' || C.LAST_NAME  AS CUSTOMER_NAME,
    C.EMAIL,
    C.PHONE,
    C.CITY,
    C.STATE,
    C.CUSTOMER_TIER,
    C.IS_ACTIVE,
    C.ANNUAL_REVENUE,
    COALESCE(OS.ORDER_COUNT, 0)          AS LIFETIME_ORDERS,
    COALESCE(OS.TOTAL_SPENT, 0)          AS LIFETIME_SPENT,
    OS.LAST_ORDER_DATE
FROM CUSTOMERS C
LEFT JOIN (
    SELECT CUSTOMER_ID,
           COUNT(*) AS ORDER_COUNT,
           SUM(TOTAL_AMOUNT) AS TOTAL_SPENT,
           MAX(ORDER_DATE) AS LAST_ORDER_DATE
    FROM ORDERS
    WHERE STATUS != 'CANCELLED'
    GROUP BY CUSTOMER_ID
) OS ON C.CUSTOMER_ID = OS.CUSTOMER_ID;
 
-- Query the view like a table
SELECT * FROM VW_CUSTOMER_360 WHERE CUSTOMER_TIER = 'GOLD';
 
-- 2. Secure View (hides definition from non-owners)
CREATE OR REPLACE SECURE VIEW VW_CUSTOMER_SENSITIVE AS
SELECT
    CUSTOMER_ID,
    FIRST_NAME,
    CUSTOMER_TIER,
    IS_ACTIVE
    -- EMAIL and PHONE deliberately excluded
FROM CUSTOMERS;
 
-- 3. Materialized View basics (note: requires Enterprise edition)
-- Materialized views store pre-computed results for fast query performance
-- Syntax:
-- CREATE MATERIALIZED VIEW MVW_MONTHLY_SALES AS
-- SELECT DATE_TRUNC('month', ORDER_DATE) AS MONTH,
--        COUNT(*) AS ORDERS,
--        SUM(TOTAL_AMOUNT) AS REVENUE
-- FROM ORDERS
-- GROUP BY 1;
 
-- 4. Manage views
SHOW VIEWS IN SCHEMA SALES_SCHEMA;
DESCRIBE VIEW VW_CUSTOMER_360;
-- DROP VIEW VW_CUSTOMER_360;

-- =========================================================================================================

-- WINDOW FUNCTION SYNTAX:
-- function_name() OVER (
--     [PARTITION BY column(s)]   -- divide rows into groups (like GROUP BY for the window)
--     [ORDER BY column(s)]        -- sort within each partition
--     [ROWS/RANGE BETWEEN ...]    -- frame specification (optional)
-- )
 
-- Simple example to explain each part:
SELECT
    CUSTOMER_ID,
    ORDER_DATE,
    TOTAL_AMOUNT,
 
    -- No PARTITION, no ORDER: applies to entire result set
    SUM(TOTAL_AMOUNT) OVER () AS GRAND_TOTAL,
 
    -- PARTITION BY: subtotal per customer
    SUM(TOTAL_AMOUNT) OVER (PARTITION BY CUSTOMER_ID) AS CUSTOMER_TOTAL,
 
    -- PARTITION + ORDER: running total per customer (ordered by date)
    SUM(TOTAL_AMOUNT) OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY ORDER_DATE
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RUNNING_TOTAL,
 
    -- Percentage of grand total
    ROUND(TOTAL_AMOUNT / SUM(TOTAL_AMOUNT) OVER() * 100, 2) AS PCT_OF_TOTAL
 
FROM ORDERS
WHERE STATUS != 'CANCELLED'
ORDER BY CUSTOMER_ID, ORDER_DATE;

-- ============================================================
-- RANKING FUNCTIONS
-- ============================================================
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
 
-- 1. ROW_NUMBER, RANK, DENSE_RANK side by side
SELECT
    ORDER_ID,
    CUSTOMER_ID,
    TOTAL_AMOUNT,
 
    ROW_NUMBER()  OVER (ORDER BY TOTAL_AMOUNT DESC) AS ROW_NUM,
    -- Always unique 1,2,3,4,5... regardless of ties
 
    RANK()        OVER (ORDER BY TOTAL_AMOUNT DESC) AS RANK_NUM,
    -- 1,2,2,4 — skips rank 3 after two rows tied at rank 2
 
    DENSE_RANK()  OVER (ORDER BY TOTAL_AMOUNT DESC) AS DENSE_RANK_NUM
    -- 1,2,2,3 — no gaps, consecutive after ties
 
FROM ORDERS
WHERE STATUS != 'CANCELLED';
 
-- 2. RANK within each customer (PARTITION BY)
SELECT
    CUSTOMER_ID,
    ORDER_ID,
    ORDER_DATE,
    TOTAL_AMOUNT,
    RANK() OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY TOTAL_AMOUNT DESC
    ) AS RANK_WITHIN_CUSTOMER
FROM ORDERS;
 
-- 3. Use ROW_NUMBER for deduplication (Top-1 per group)
-- Find the most recent order per customer
WITH RANKED_ORDERS AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY CUSTOMER_ID
            ORDER BY ORDER_DATE DESC, ORDER_ID DESC
        ) AS RN
    FROM ORDERS
)
SELECT * FROM RANKED_ORDERS WHERE RN = 1;
 
-- 4. NTILE — divide rows into N equal buckets
SELECT
    CUSTOMER_ID,
    ANNUAL_REVENUE,
    NTILE(4) OVER (ORDER BY ANNUAL_REVENUE DESC) AS QUARTILE,
    CASE NTILE(4) OVER (ORDER BY ANNUAL_REVENUE DESC)
        WHEN 1 THEN 'Top 25%'
        WHEN 2 THEN 'Upper-Mid 25%'
        WHEN 3 THEN 'Lower-Mid 25%'
        WHEN 4 THEN 'Bottom 25%'
    END AS REVENUE_QUARTILE
FROM CUSTOMERS;

-- ============================================================
-- LEAD AND LAG FUNCTIONS
-- ============================================================
 
-- 1. LAG — compare each order to the previous order value
SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_DATE,
    TOTAL_AMOUNT,
    LAG(TOTAL_AMOUNT, 1, 0) OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY ORDER_DATE
    ) AS PREV_ORDER_AMOUNT,
    TOTAL_AMOUNT - LAG(TOTAL_AMOUNT, 1, 0) OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY ORDER_DATE
    ) AS AMOUNT_CHANGE
FROM ORDERS
ORDER BY CUSTOMER_ID, ORDER_DATE;
 
-- 2. LEAD — look at the next order date
SELECT
    CUSTOMER_ID,
    ORDER_ID,
    ORDER_DATE,
    LEAD(ORDER_DATE, 1) OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY ORDER_DATE
    ) AS NEXT_ORDER_DATE,
    DATEDIFF('day', ORDER_DATE,
        LEAD(ORDER_DATE, 1) OVER (
            PARTITION BY CUSTOMER_ID
            ORDER BY ORDER_DATE
        )
    ) AS DAYS_BETWEEN_ORDERS
FROM ORDERS
ORDER BY CUSTOMER_ID, ORDER_DATE;
 
-- 3. Monthly revenue with month-over-month growth
WITH MONTHLY_REVENUE AS (
    SELECT
        DATE_TRUNC('month', ORDER_DATE) AS SALES_MONTH,
        SUM(TOTAL_AMOUNT) AS MONTHLY_REVENUE
    FROM ORDERS
    WHERE STATUS != 'CANCELLED'
    GROUP BY 1
),
WITH_GROWTH AS (
    SELECT
        SALES_MONTH,
        MONTHLY_REVENUE,
        LAG(MONTHLY_REVENUE) OVER (ORDER BY SALES_MONTH) AS PREV_MONTH_REVENUE,
        ROUND(
            (MONTHLY_REVENUE - LAG(MONTHLY_REVENUE) OVER (ORDER BY SALES_MONTH))
            / NULLIF(LAG(MONTHLY_REVENUE) OVER (ORDER BY SALES_MONTH), 0) * 100,
            1
        ) AS MOM_GROWTH_PCT
    FROM MONTHLY_REVENUE
)
SELECT * FROM WITH_GROWTH ORDER BY SALES_MONTH;

-- ============================================================
-- FIRST_VALUE AND LAST_VALUE
-- ============================================================
 
-- 1. FIRST_VALUE — first order date per customer (in each partition)
SELECT
    CUSTOMER_ID,
    ORDER_ID,
    ORDER_DATE,
    TOTAL_AMOUNT,
    FIRST_VALUE(ORDER_DATE) OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY ORDER_DATE
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS FIRST_ORDER_DATE,
    FIRST_VALUE(TOTAL_AMOUNT) OVER (
        PARTITION BY CUSTOMER_ID
        ORDER BY TOTAL_AMOUNT DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS HIGHEST_ORDER_AMOUNT
FROM ORDERS
ORDER BY CUSTOMER_ID, ORDER_DATE;
 
-- 2. Running Total and Moving Average
SELECT
    DATE_TRUNC('month', ORDER_DATE)    AS MONTH,
    SUM(TOTAL_AMOUNT)                   AS MONTHLY_REVENUE,
    -- Running total (cumulative sum)
    SUM(SUM(TOTAL_AMOUNT)) OVER (
        ORDER BY DATE_TRUNC('month', ORDER_DATE)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS CUMULATIVE_REVENUE,
    -- 3-month moving average
    AVG(SUM(TOTAL_AMOUNT)) OVER (
        ORDER BY DATE_TRUNC('month', ORDER_DATE)
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS MOVING_AVG_3M
FROM ORDERS
WHERE STATUS != 'CANCELLED'
GROUP BY DATE_TRUNC('month', ORDER_DATE)
ORDER BY MONTH;
 
-- 3. PERCENTILE_CONT and PERCENTILE_DISC (ordered set functions)
SELECT
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY TOTAL_AMOUNT) AS MEDIAN_ORDER,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY TOTAL_AMOUNT) AS P75_ORDER,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY TOTAL_AMOUNT) AS P90_ORDER,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY TOTAL_AMOUNT) AS P95_ORDER
FROM ORDERS
WHERE STATUS != 'CANCELLED';

-- ============================================================
-- QUALIFY CLAUSE (Snowflake-specific)
-- ============================================================
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
 
-- 1. QUALIFY: Keep only the latest order per customer (without a CTE!)
SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_DATE,
    TOTAL_AMOUNT,
    STATUS
FROM ORDERS
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CUSTOMER_ID
    ORDER BY ORDER_DATE DESC
) = 1;
-- This replaces the CTE + WHERE RN = 1 pattern — more efficient!
 
-- 2. QUALIFY: Top 2 orders per customer by amount
SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_DATE,
    TOTAL_AMOUNT
FROM ORDERS
QUALIFY RANK() OVER (
    PARTITION BY CUSTOMER_ID
    ORDER BY TOTAL_AMOUNT DESC
) <= 2;
 
-- 3. QUALIFY: Orders where amount is above customer's own average
SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_DATE,
    TOTAL_AMOUNT
FROM ORDERS
QUALIFY TOTAL_AMOUNT > AVG(TOTAL_AMOUNT) OVER (PARTITION BY CUSTOMER_ID);

-- ============================================================
-- PIVOT AND UNPIVOT
-- ============================================================
 
-- Setup: Monthly revenue by region (long format)
CREATE OR REPLACE TEMP TABLE MONTHLY_REGION_SALES AS
SELECT
    TO_CHAR(DATE_TRUNC('month', ORDER_DATE), 'MON') AS MONTH_NAME,
    REGION,
    SUM(TOTAL_AMOUNT) AS REVENUE
FROM ORDERS
WHERE STATUS != 'CANCELLED'
  AND REGION IS NOT NULL
GROUP BY 1, 2;
 
SELECT * FROM MONTHLY_REGION_SALES ORDER BY MONTH_NAME, REGION;
-- Output: rows like (JAN, North, 134999), (JAN, South, 12349)...
 
-- 1. PIVOT: Show each month as a column, regions as rows
SELECT *
FROM MONTHLY_REGION_SALES
PIVOT (
    SUM(REVENUE)
    FOR MONTH_NAME IN ('JAN','FEB','MAR','APR','MAY')
) AS PIVOTED
ORDER BY REGION;
-- Output: Each row = one REGION, columns = JAN through MAY revenue
 
-- 2. Dynamic PIVOT alternative using CASE statements
SELECT
    REGION,
    SUM(CASE WHEN MONTH_NAME = 'JAN' THEN REVENUE ELSE 0 END) AS JAN,
    SUM(CASE WHEN MONTH_NAME = 'FEB' THEN REVENUE ELSE 0 END) AS FEB,
    SUM(CASE WHEN MONTH_NAME = 'MAR' THEN REVENUE ELSE 0 END) AS MAR,
    SUM(CASE WHEN MONTH_NAME = 'APR' THEN REVENUE ELSE 0 END) AS APR,
    SUM(CASE WHEN MONTH_NAME = 'MAY' THEN REVENUE ELSE 0 END) AS MAY,
    SUM(REVENUE)                                               AS TOTAL
FROM MONTHLY_REGION_SALES
GROUP BY REGION
ORDER BY TOTAL DESC;
 
-- 3. UNPIVOT: Convert wide format back to long format
-- (useful when source data has months as columns)
CREATE OR REPLACE TEMP TABLE WIDE_SALES (
    REGION VARCHAR,
    JAN NUMBER, FEB NUMBER, MAR NUMBER, APR NUMBER, MAY NUMBER
);
-- Upload wide_sales data using staging
-- Note: For this small demo table, we still use staging for consistency
CREATE OR REPLACE STAGE STG_WIDE_SALES
    FILE_FORMAT = TRAINING_CSV_FORMAT
    COMMENT = 'Internal stage for WIDE_SALES pivot demo data';

-- Since WIDE_SALES is a small demo table derived from ORDERS data,
-- we create it using CTAS from the already-loaded MONTHLY_REGION_SALES:
INSERT INTO WIDE_SALES
SELECT
    REGION,
    SUM(CASE WHEN MONTH_NAME = 'JAN' THEN REVENUE ELSE 0 END) AS JAN,
    SUM(CASE WHEN MONTH_NAME = 'FEB' THEN REVENUE ELSE 0 END) AS FEB,
    SUM(CASE WHEN MONTH_NAME = 'MAR' THEN REVENUE ELSE 0 END) AS MAR,
    SUM(CASE WHEN MONTH_NAME = 'APR' THEN REVENUE ELSE 0 END) AS APR,
    SUM(CASE WHEN MONTH_NAME = 'MAY' THEN REVENUE ELSE 0 END) AS MAY
FROM MONTHLY_REGION_SALES
GROUP BY REGION;
 
SELECT REGION, MONTH_NAME, REVENUE
FROM WIDE_SALES
UNPIVOT (REVENUE FOR MONTH_NAME IN (JAN, FEB, MAR, APR, MAY))
ORDER BY REGION, MONTH_NAME;

-- ============================================================
-- DEDUPLICATION STRATEGIES
-- ============================================================
 
-- Setup: Simulate duplicate records
CREATE OR REPLACE TEMP TABLE DUPLICATE_ORDERS AS
SELECT * FROM ORDERS
UNION ALL
SELECT * FROM ORDERS WHERE ORDER_ID IN (5001, 5002, 5003); -- Add 3 duplicates
 
SELECT COUNT(*) AS TOTAL_ROWS FROM DUPLICATE_ORDERS;  
 
-- Strategy 1: DISTINCT (simple but limited)
SELECT DISTINCT * FROM DUPLICATE_ORDERS;  -- Works if ALL columns are identical
 
-- Strategy 2: ROW_NUMBER + QUALIFY (recommended — most flexible)
SELECT * FROM DUPLICATE_ORDERS
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY ORDER_ID  -- Define what makes a row "unique"
    ORDER BY ORDER_DATE    -- Keep the earliest (or change to DESC for latest)
) = 1;
 
-- Strategy 3: GROUP BY with aggregation (when some columns can vary)
SELECT
    ORDER_ID,
    CUSTOMER_ID,
    MIN(ORDER_DATE) AS FIRST_ORDER_DATE,
    MAX(TOTAL_AMOUNT) AS MAX_AMOUNT,
    COUNT(*) AS DUPLICATE_COUNT
FROM DUPLICATE_ORDERS
GROUP BY ORDER_ID, CUSTOMER_ID
HAVING COUNT(*) > 1;  -- Show only actual duplicates
 
-- Strategy 4: DELETE duplicates from a real table using CTE
-- (This is the enterprise pattern for data cleanup)
DELETE FROM DUPLICATE_ORDERS
WHERE ORDER_ID IN (
    SELECT ORDER_ID FROM (
        SELECT ORDER_ID,
               ROW_NUMBER() OVER (PARTITION BY ORDER_ID ORDER BY ORDER_DATE) AS RN
        FROM DUPLICATE_ORDERS
    ) WHERE RN > 1
);

-- ============================================================
-- TOP-N ANALYSIS
-- ============================================================
 
-- Top 3 customers by revenue per tier
SELECT *
FROM (
    SELECT
        C.CUSTOMER_ID,
        C.FIRST_NAME || ' ' || C.LAST_NAME AS CUSTOMER_NAME,
        C.CUSTOMER_TIER,
        SUM(O.TOTAL_AMOUNT) AS TOTAL_SPENT
    FROM CUSTOMERS C
    JOIN ORDERS O ON C.CUSTOMER_ID = O.CUSTOMER_ID
    GROUP BY C.CUSTOMER_ID, C.FIRST_NAME, C.LAST_NAME, C.CUSTOMER_TIER
)
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CUSTOMER_TIER
    ORDER BY TOTAL_SPENT DESC
) <= 3;
 
-- ============================================================
-- COHORT ANALYSIS (First Purchase Month)
-- ============================================================
WITH FIRST_PURCHASE AS (
    SELECT
        CUSTOMER_ID,
        DATE_TRUNC('month', MIN(ORDER_DATE)) AS COHORT_MONTH
    FROM ORDERS
    GROUP BY CUSTOMER_ID
),
CUSTOMER_ORDERS_MONTHLY AS (
    SELECT
        O.CUSTOMER_ID,
        FP.COHORT_MONTH,
        DATE_TRUNC('month', O.ORDER_DATE) AS ORDER_MONTH,
        DATEDIFF('month', FP.COHORT_MONTH, DATE_TRUNC('month', O.ORDER_DATE)) AS MONTHS_SINCE_FIRST
    FROM ORDERS O
    JOIN FIRST_PURCHASE FP ON O.CUSTOMER_ID = FP.CUSTOMER_ID
)
SELECT
    COHORT_MONTH,
    MONTHS_SINCE_FIRST,
    COUNT(DISTINCT CUSTOMER_ID) AS ACTIVE_CUSTOMERS
FROM CUSTOMER_ORDERS_MONTHLY
GROUP BY 1, 2
ORDER BY COHORT_MONTH, MONTHS_SINCE_FIRST;

-- ============================================================
-- TIME-SERIES ANALYTICS PATTERNS
-- ============================================================
 
-- 1. Daily revenue trend with 7-day moving average
SELECT
    ORDER_DATE,
    COUNT(*) AS DAILY_ORDERS,
    SUM(TOTAL_AMOUNT) AS DAILY_REVENUE,
    ROUND(
        AVG(SUM(TOTAL_AMOUNT)) OVER (
            ORDER BY ORDER_DATE
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2
    ) AS MOVING_AVG_7D
FROM ORDERS
WHERE STATUS != 'CANCELLED'
GROUP BY ORDER_DATE
ORDER BY ORDER_DATE;
 
-- 2. Year-over-Year comparison (with sample extended dataset)
-- Note: Our sample data is all 2024; concept shown below
SELECT
    YEAR(ORDER_DATE)                        AS ORDER_YEAR,
    MONTH(ORDER_DATE)                       AS ORDER_MONTH,
    MONTHNAME(ORDER_DATE)                   AS MONTH_NAME,
    SUM(TOTAL_AMOUNT)                       AS MONTHLY_REVENUE,
    LAG(SUM(TOTAL_AMOUNT)) OVER (
        PARTITION BY MONTH(ORDER_DATE)
        ORDER BY YEAR(ORDER_DATE)
    ) AS PREV_YEAR_REVENUE,
    ROUND(
        (SUM(TOTAL_AMOUNT) - LAG(SUM(TOTAL_AMOUNT)) OVER (
            PARTITION BY MONTH(ORDER_DATE)
            ORDER BY YEAR(ORDER_DATE)
        )) / NULLIF(
            LAG(SUM(TOTAL_AMOUNT)) OVER (
                PARTITION BY MONTH(ORDER_DATE)
                ORDER BY YEAR(ORDER_DATE)
            ), 0
        ) * 100, 1
    ) AS YOY_GROWTH_PCT
FROM ORDERS
WHERE STATUS != 'CANCELLED'
GROUP BY 1, 2, 3
ORDER BY 1, 2;
 
-- 3. Week-over-Week orders
SELECT
    WEEKOFYEAR(ORDER_DATE)      AS WEEK_NUM,
    MIN(ORDER_DATE)             AS WEEK_START,
    COUNT(*)                    AS WEEKLY_ORDERS,
    SUM(TOTAL_AMOUNT)           AS WEEKLY_REVENUE,
    LAG(COUNT(*)) OVER (ORDER BY WEEKOFYEAR(ORDER_DATE)) AS PREV_WEEK_ORDERS,
    COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY WEEKOFYEAR(ORDER_DATE)) AS WOW_CHANGE
FROM ORDERS
GROUP BY WEEKOFYEAR(ORDER_DATE)
ORDER BY WEEK_NUM;

-- ============================================================
-- BUSINESS REPORTING PATTERNS
-- ============================================================
 
-- 1. Executive Summary Dashboard Query
WITH SUMMARY_STATS AS (
    SELECT
        COUNT(DISTINCT O.ORDER_ID)                  AS TOTAL_ORDERS,
        COUNT(DISTINCT O.CUSTOMER_ID)               AS UNIQUE_CUSTOMERS,
        SUM(O.TOTAL_AMOUNT)                         AS GROSS_REVENUE,
        SUM(O.TOTAL_AMOUNT * (1 - NVL(O.DISCOUNT_PCT,0)/100)) AS NET_REVENUE,
        ROUND(AVG(O.TOTAL_AMOUNT), 2)               AS AVG_ORDER_VALUE,
        COUNT(CASE WHEN O.STATUS='CANCELLED' THEN 1 END)       AS CANCELLED_ORDERS,
        COUNT(CASE WHEN O.STATUS='DELIVERED' THEN 1 END)       AS DELIVERED_ORDERS
    FROM ORDERS O
    WHERE ORDER_DATE >= '2024-01-01'
)
SELECT
    *,
    ROUND(DELIVERED_ORDERS * 100.0 / TOTAL_ORDERS, 1) AS DELIVERY_RATE_PCT,
    ROUND(CANCELLED_ORDERS * 100.0 / TOTAL_ORDERS, 1) AS CANCELLATION_RATE_PCT
FROM SUMMARY_STATS;
 
-- 2. Sales Funnel Analysis
SELECT
    STATUS,
    COUNT(*) AS ORDER_COUNT,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS PCT_OF_TOTAL,
    ROUND(SUM(TOTAL_AMOUNT)/1000, 1) AS REVENUE_K
FROM ORDERS
GROUP BY STATUS
ORDER BY ORDER_COUNT DESC;
 
-- 3. RFM Analysis (Recency, Frequency, Monetary)
WITH RFM_BASE AS (
    SELECT
        CUSTOMER_ID,
        DATEDIFF('day', MAX(ORDER_DATE), CURRENT_DATE()) AS RECENCY_DAYS,
        COUNT(DISTINCT ORDER_ID) AS FREQUENCY,
        SUM(TOTAL_AMOUNT) AS MONETARY
    FROM ORDERS
    WHERE STATUS != 'CANCELLED'
    GROUP BY CUSTOMER_ID
),
RFM_SCORES AS (
    SELECT
        CUSTOMER_ID,
        RECENCY_DAYS,
        FREQUENCY,
        MONETARY,
        NTILE(5) OVER (ORDER BY RECENCY_DAYS ASC)   AS R_SCORE,  -- lower days = better
        NTILE(5) OVER (ORDER BY FREQUENCY DESC)      AS F_SCORE,
        NTILE(5) OVER (ORDER BY MONETARY DESC)       AS M_SCORE
    FROM RFM_BASE
)
SELECT
    CUSTOMER_ID,
    RECENCY_DAYS,
    FREQUENCY,
    ROUND(MONETARY, 0) AS MONETARY,
    R_SCORE, F_SCORE, M_SCORE,
    (R_SCORE + F_SCORE + M_SCORE) AS RFM_TOTAL,
    CASE
        WHEN R_SCORE >= 4 AND F_SCORE >= 4 THEN 'Champion'
        WHEN R_SCORE >= 3 AND F_SCORE >= 3 THEN 'Loyal Customer'
        WHEN R_SCORE >= 4 AND F_SCORE <= 2 THEN 'Recent Customer'
        WHEN R_SCORE <= 2 AND F_SCORE >= 3 THEN 'At Risk'
        ELSE 'Need Attention'
    END AS CUSTOMER_SEGMENT
FROM RFM_SCORES
ORDER BY RFM_TOTAL DESC;

-- ============================================================
-- QUERY OPTIMIZATION EXAMPLES
-- ============================================================
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
 
-- BAD: SELECT * brings unnecessary columns, more data scanned
SELECT * FROM ORDERS O JOIN CUSTOMERS C ON O.CUSTOMER_ID = C.CUSTOMER_ID;
 
-- GOOD: Select only needed columns
SELECT
    O.ORDER_ID,
    O.ORDER_DATE,
    O.TOTAL_AMOUNT,
    C.FIRST_NAME || ' ' || C.LAST_NAME AS CUSTOMER_NAME,
    C.CUSTOMER_TIER
FROM ORDERS O
JOIN CUSTOMERS C ON O.CUSTOMER_ID = C.CUSTOMER_ID
WHERE O.STATUS = 'DELIVERED'
  AND O.ORDER_DATE >= '2024-01-01';
 
-- BAD: Applying function on filtered column prevents pruning
SELECT * FROM ORDERS WHERE YEAR(ORDER_DATE) = 2024;
 
-- GOOD: Use range filter — enables micro-partition pruning
SELECT * FROM ORDERS
WHERE ORDER_DATE >= '2024-01-01' AND ORDER_DATE < '2025-01-01';
 
-- BAD: Correlated subquery runs once per outer row
SELECT ORDER_ID,
       (SELECT AVG(TOTAL_AMOUNT) FROM ORDERS) AS AVG_AMOUNT  -- OK for scalar
FROM ORDERS;
 
-- GOOD for complex correlated: Use CTE or window function instead
SELECT
    ORDER_ID,
    TOTAL_AMOUNT,
    AVG(TOTAL_AMOUNT) OVER() AS AVG_AMOUNT,  -- Window function — calculated once
    TOTAL_AMOUNT - AVG(TOTAL_AMOUNT) OVER() AS DIFF_FROM_AVG
FROM ORDERS;
 
-- Check if result cache was used (look for "Query Profile" in UI)
-- In Snowflake UI: Results > Query Profile > look for "Result reuse" node
 
-- EXPLAIN PLAN (analyze query plan)
EXPLAIN
SELECT C.FIRST_NAME, O.ORDER_DATE, O.TOTAL_AMOUNT
FROM CUSTOMERS C
JOIN ORDERS O ON C.CUSTOMER_ID = O.CUSTOMER_ID
WHERE O.TOTAL_AMOUNT > 100000;
 
-- Monitor query performance
SELECT
    QUERY_ID,
    QUERY_TEXT,
    EXECUTION_STATUS,
    ROUND(TOTAL_ELAPSED_TIME/1000, 2) AS ELAPSED_SECONDS,
    BYTES_SCANNED,
    ROWS_PRODUCED,
    COMPILATION_TIME,
    EXECUTION_TIME
FROM TABLE (INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 20
))
ORDER BY TOTAL_ELAPSED_TIME DESC;

-- ============================================================
-- CLEANUP SCRIPT — Run at end of session or when done practicing
-- ============================================================
 
-- Drop views
USE DATABASE TRAINING_DB;
USE SCHEMA SALES_SCHEMA;
DROP VIEW IF EXISTS VW_CUSTOMER_360;
DROP VIEW IF EXISTS VW_CUSTOMER_SENSITIVE;
 
-- Drop temp tables (auto-deleted when session ends, but good practice)
DROP TABLE IF EXISTS TEMP_ORDER_SUMMARY;
DROP TABLE IF EXISTS DUPLICATE_ORDERS;
DROP TABLE IF EXISTS STAGING_ORDERS;
DROP TABLE IF EXISTS MONTHLY_REGION_SALES;
DROP TABLE IF EXISTS WIDE_SALES;
 
-- Drop internal stages (clean up staged files)
DROP STAGE IF EXISTS STG_CUSTOMERS;
DROP STAGE IF EXISTS STG_PRODUCTS;
DROP STAGE IF EXISTS STG_ORDERS;
DROP STAGE IF EXISTS STG_ORDER_ITEMS;

USE SCHEMA HR_SCHEMA;
DROP STAGE IF EXISTS STG_EMPLOYEES;

USE SCHEMA SALES_SCHEMA;

-- Drop main tables
DROP TABLE IF EXISTS ORDER_ITEMS;
DROP TABLE IF EXISTS ORDERS;
DROP TABLE IF EXISTS PRODUCTS;
DROP TABLE IF EXISTS CUSTOMERS;
 
USE SCHEMA HR_SCHEMA;
DROP TABLE IF EXISTS EMPLOYEES;
 
-- Drop schemas
USE DATABASE TRAINING_DB;
DROP SCHEMA IF EXISTS SALES_SCHEMA;
DROP SCHEMA IF EXISTS HR_SCHEMA;
DROP SCHEMA IF EXISTS FINANCE_SCHEMA;
 
-- Drop database
DROP DATABASE IF EXISTS TRAINING_DB;
 
SELECT 'Cleanup Complete!' AS STATUS;
