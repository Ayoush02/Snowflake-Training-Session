-- ============================================================
--  SETUP: Run this ONCE before the training session begins
-- ============================================================
 
-- 1. Create a dedicated database and schema
CREATE DATABASE IF NOT EXISTS VIEWS_TRAINING_DB;
USE DATABASE VIEWS_TRAINING_DB;
CREATE SCHEMA IF NOT EXISTS TRAINING;
USE SCHEMA TRAINING;
 
-- 2. Use a warehouse (replace with your warehouse name)
USE WAREHOUSE COMPUTE_WH;
 
-- ============================================================
--  BASE TABLES - used throughout all demos
-- ============================================================
 
-- Employee table
CREATE OR REPLACE TABLE EMPLOYEES (
    EMP_ID        NUMBER AUTOINCREMENT PRIMARY KEY,
    FIRST_NAME    VARCHAR(50),
    LAST_NAME     VARCHAR(50),
    DEPARTMENT    VARCHAR(50),
    SALARY        NUMBER(10,2),
    EMAIL         VARCHAR(100),
    HIRE_DATE     DATE,
    IS_ACTIVE     BOOLEAN DEFAULT TRUE
);
 
-- Sales Orders table
CREATE OR REPLACE TABLE SALES_ORDERS (
    ORDER_ID      NUMBER AUTOINCREMENT PRIMARY KEY,
    EMP_ID        NUMBER,
    PRODUCT_NAME  VARCHAR(100),
    QUANTITY      NUMBER,
    UNIT_PRICE    NUMBER(10,2),
    ORDER_DATE    DATE,
    REGION        VARCHAR(50),
    STATUS        VARCHAR(20)
);
 
-- Insert sample employee data
INSERT INTO EMPLOYEES (FIRST_NAME, LAST_NAME, DEPARTMENT, SALARY, EMAIL, HIRE_DATE, IS_ACTIVE)
VALUES
  ('Alice',   'Johnson',  'Engineering', 95000, 'alice@company.com',   '2020-03-15', TRUE),
  ('Bob',     'Smith',    'Sales',       72000, 'bob@company.com',      '2019-07-01', TRUE),
  ('Carol',   'Williams', 'HR',          65000, 'carol@company.com',    '2021-01-20', TRUE),
  ('David',   'Brown',    'Engineering', 105000,'david@company.com',    '2018-11-05', TRUE),
  ('Eve',     'Davis',    'Sales',       80000, 'eve@company.com',      '2022-04-10', TRUE),
  ('Frank',   'Miller',   'Finance',     88000, 'frank@company.com',    '2017-09-30', TRUE),
  ('Grace',   'Wilson',   'HR',          60000, 'grace@company.com',    '2023-02-14', TRUE),
  ('Henry',   'Moore',    'Engineering', 110000,'henry@company.com',    '2016-06-22', FALSE),
  ('Iris',    'Taylor',   'Finance',     92000, 'iris@company.com',     '2019-12-01', TRUE),
  ('Jack',    'Anderson', 'Sales',       68000, 'jack@company.com',     '2020-08-17', TRUE);
 
-- Insert sample sales orders
INSERT INTO SALES_ORDERS (EMP_ID, PRODUCT_NAME, QUANTITY, UNIT_PRICE, ORDER_DATE, REGION, STATUS)
VALUES
  (2, 'Laptop Pro',    3, 1200.00, '2024-01-05', 'North', 'Completed'),
  (2, 'Mouse',        10,   25.00, '2024-01-10', 'North', 'Completed'),
  (5, 'Monitor',       5,  350.00, '2024-01-15', 'South', 'Completed'),
  (5, 'Keyboard',      8,   75.00, '2024-01-18', 'South', 'Pending'),
  (10,'Laptop Pro',    2, 1200.00, '2024-02-02', 'East',  'Completed'),
  (10,'Headphones',    4,  150.00, '2024-02-07', 'East',  'Completed'),
  (2, 'Webcam',        6,   90.00, '2024-02-12', 'North', 'Cancelled'),
  (5, 'USB Hub',      15,   40.00, '2024-02-20', 'South', 'Completed'),
  (10,'Monitor',       3,  350.00, '2024-03-01', 'East',  'Pending'),
  (2, 'Laptop Pro',    1, 1200.00, '2024-03-05', 'North', 'Completed');
 
-- Verify data loaded correctly
SELECT 'EMPLOYEES' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM EMPLOYEES
UNION ALL
SELECT 'SALES_ORDERS', COUNT(*) FROM SALES_ORDERS;

-- ============================================================
--  MODULE 1A: Basic Standard View
--  Goal: Show only active employees with full name
-- ============================================================
 
-- Create a simple view
CREATE OR REPLACE VIEW VW_ACTIVE_EMPLOYEES AS
SELECT
    EMP_ID,
    FIRST_NAME || ' ' || LAST_NAME  AS FULL_NAME,
    DEPARTMENT,
    EMAIL,
    HIRE_DATE,
    DATEDIFF('year', HIRE_DATE, CURRENT_DATE()) AS YEARS_WITH_COMPANY
FROM EMPLOYEES
WHERE IS_ACTIVE = TRUE;
 
-- Query the view like a table
SELECT * FROM VW_ACTIVE_EMPLOYEES
ORDER BY YEARS_WITH_COMPANY DESC;
 
-- Count active employees per department
SELECT DEPARTMENT, COUNT(*) AS HEADCOUNT
FROM VW_ACTIVE_EMPLOYEES
GROUP BY DEPARTMENT
ORDER BY HEADCOUNT DESC;

-- ============================================================
--  MODULE 1B: View with JOIN (Multi-table view)
--  Goal: Combine employees + orders in one reusable view
-- ============================================================
 
CREATE OR REPLACE VIEW VW_SALES_SUMMARY AS
SELECT
    E.EMP_ID,
    E.FIRST_NAME || ' ' || E.LAST_NAME AS SALES_REP,
    E.DEPARTMENT,
    S.ORDER_ID,
    S.PRODUCT_NAME,
    S.QUANTITY,
    S.UNIT_PRICE,
    S.QUANTITY * S.UNIT_PRICE AS TOTAL_VALUE,
    S.ORDER_DATE,
    S.STATUS
FROM EMPLOYEES E
JOIN SALES_ORDERS S ON E.EMP_ID = S.EMP_ID
WHERE E.DEPARTMENT = 'Sales';
 
-- Use the view
SELECT
    SALES_REP,
    SUM(TOTAL_VALUE)      AS TOTAL_SALES,
    COUNT(ORDER_ID)       AS ORDER_COUNT,
    AVG(TOTAL_VALUE)      AS AVG_ORDER_VALUE
FROM VW_SALES_SUMMARY
WHERE STATUS = 'Completed'
GROUP BY SALES_REP
ORDER BY TOTAL_SALES DESC;

-- ============================================================
--  MODULE 1C: Replacing a View & Inspecting Metadata
-- ============================================================
 
-- Replace an existing view (add REGION column)
CREATE OR REPLACE VIEW VW_ACTIVE_EMPLOYEES AS
SELECT
    EMP_ID,
    FIRST_NAME || ' ' || LAST_NAME  AS FULL_NAME,
    DEPARTMENT,
    EMAIL,
    HIRE_DATE,
    DATEDIFF('year', HIRE_DATE, CURRENT_DATE()) AS YEARS_WITH_COMPANY
FROM EMPLOYEES
WHERE IS_ACTIVE = TRUE;
 
-- List all views in this schema
SHOW VIEWS IN SCHEMA TRAINING;
 
-- Inspect the view DDL
SELECT GET_DDL('VIEW', 'VW_ACTIVE_EMPLOYEES');
 
-- Check view metadata from Information Schema
SELECT TABLE_NAME, IS_SECURE, VIEW_DEFINITION
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'TRAINING';
 
-- Clean up (optional - keep for later modules)
-- DROP VIEW IF EXISTS VW_ACTIVE_EMPLOYEES;

-- ============================================================
--  MODULE 1D: Recursive View (Bonus)
--  Goal: Model manager-employee hierarchy
-- ============================================================
 
-- First, add manager relationship to employees
CREATE OR REPLACE TABLE EMP_HIERARCHY (
    EMP_ID      NUMBER,
    EMP_NAME    VARCHAR(100),
    MANAGER_ID  NUMBER,
    TITLE       VARCHAR(50)
);
 
INSERT INTO EMP_HIERARCHY VALUES
  (1, 'CEO Sarah',      NULL, 'CEO'),
  (2, 'VP Alice',       1,    'VP Engineering'),
  (3, 'VP Bob',         1,    'VP Sales'),
  (4, 'Eng Carol',      2,    'Senior Engineer'),
  (5, 'Eng David',      2,    'Engineer'),
  (6, 'Sales Eve',      3,    'Account Executive'),
  (7, 'Sales Frank',    3,    'Account Executive');
 
-- Create a recursive view to show full reporting chain
CREATE OR REPLACE RECURSIVE VIEW VW_ORG_HIERARCHY
  (EMP_ID, EMP_NAME, TITLE, MANAGER_ID, LEVEL, ORG_PATH)
AS (
    -- Anchor: top-level (CEO)
    SELECT EMP_ID, EMP_NAME, TITLE, MANAGER_ID, 0, EMP_NAME
    FROM   EMP_HIERARCHY
    WHERE  MANAGER_ID IS NULL
 
    UNION ALL
 
    -- Recursive: each level down
    SELECT
        e.EMP_ID, e.EMP_NAME, e.TITLE, e.MANAGER_ID,
        h.LEVEL + 1,
        h.ORG_PATH || ' > ' || e.EMP_NAME
    FROM EMP_HIERARCHY   e
    JOIN VW_ORG_HIERARCHY h ON e.MANAGER_ID = h.EMP_ID
);
 
-- Query the hierarchy
SELECT
    REPEAT('  ', LEVEL) || EMP_NAME  AS EMPLOYEE,
    TITLE,
    LEVEL AS HIERARCHY_LEVEL,
    ORG_PATH
FROM VW_ORG_HIERARCHY
ORDER BY ORG_PATH;

-- ============================================================
--  MODULE 2A: Create a Secure View
--  Goal: Hide salary data from non-HR users
-- ============================================================
 
-- Standard view -- salary IS visible in DDL
CREATE OR REPLACE VIEW VW_EMP_STANDARD AS
SELECT EMP_ID, FIRST_NAME, LAST_NAME, DEPARTMENT, SALARY
FROM EMPLOYEES;
 
-- Secure view -- same data, but DDL hidden from non-owners
CREATE OR REPLACE SECURE VIEW VW_EMP_SECURE AS
SELECT EMP_ID, FIRST_NAME, LAST_NAME, DEPARTMENT, SALARY
FROM EMPLOYEES;
 
-- Query both -- results look identical to the user
SELECT * FROM VW_EMP_STANDARD LIMIT 5;
SELECT * FROM VW_EMP_SECURE   LIMIT 5;
 
-- Verify which view is secure
SELECT TABLE_NAME, IS_SECURE
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'TRAINING'
  AND TABLE_NAME IN ('VW_EMP_STANDARD', 'VW_EMP_SECURE');
 
-- DDL visible for standard view
SELECT GET_DDL('VIEW', 'VW_EMP_STANDARD');
 
-- DDL hidden for secure view (only shows to owner)
SELECT GET_DDL('VIEW', 'VW_EMP_SECURE');

-- ============================================================
--  MODULE 2B: Row-Level Security with CURRENT_ROLE()
--  Goal: Each department sees only their own employees
-- ============================================================
 
-- Access control table: maps role -> allowed department
CREATE OR REPLACE TABLE DEPT_ACCESS_RULES (
    ROLE_NAME   VARCHAR(100),
    DEPARTMENT  VARCHAR(50)
);
 
INSERT INTO DEPT_ACCESS_RULES VALUES
  ('SYSADMIN',       'Engineering'),
  ('SYSADMIN',       'Sales'),
  ('SYSADMIN',       'HR'),
  ('SYSADMIN',       'Finance'),
  ('ACCOUNTADMIN',   'Engineering'),
  ('ACCOUNTADMIN',   'Sales'),
  ('ACCOUNTADMIN',   'HR'),
  ('ACCOUNTADMIN',   'Finance');
 
-- Secure view: each role sees only their allowed departments
CREATE OR REPLACE SECURE VIEW VW_DEPT_FILTERED AS
SELECT
    E.EMP_ID,
    E.FIRST_NAME,
    E.LAST_NAME,
    E.DEPARTMENT,
    E.SALARY,
    E.HIRE_DATE,
    CURRENT_ROLE()   AS VIEWER_ROLE  -- show which role is querying
FROM EMPLOYEES E
WHERE E.DEPARTMENT IN (
    SELECT DEPARTMENT
    FROM   DEPT_ACCESS_RULES
    WHERE  UPPER(ROLE_NAME) = CURRENT_ROLE()
);
 
-- Query the secure view
SELECT * FROM VW_DEPT_FILTERED ORDER BY DEPARTMENT, LAST_NAME;
 
-- Show current role and verify filter is working
SELECT CURRENT_ROLE(), CURRENT_USER();

-- ============================================================
--  MODULE 2C: Convert existing view to Secure & back
-- ============================================================
 
-- Check current secure status
SHOW VIEWS LIKE 'VW_SALES_SUMMARY';
 
-- Convert standard view to secure
ALTER VIEW VW_SALES_SUMMARY SET SECURE;
 
-- Verify it is now secure
SELECT TABLE_NAME, IS_SECURE
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'TRAINING'
  AND TABLE_NAME = 'VW_SALES_SUMMARY';
 
-- Revert back to standard view
ALTER VIEW VW_SALES_SUMMARY UNSET SECURE;
 
-- Confirm it is no longer secure
SELECT TABLE_NAME, IS_SECURE
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'TRAINING'
  AND TABLE_NAME = 'VW_SALES_SUMMARY';

-- ============================================================
--  MODULE 3A: Create a Materialized View
--  Goal: Pre-compute daily sales aggregates
--  NOTE: Requires Snowflake Enterprise Edition
-- ============================================================
 
-- Create a Materialized View for daily sales summary
CREATE OR REPLACE MATERIALIZED VIEW MVW_DAILY_SALES AS
SELECT
    ORDER_DATE,
    REGION,
    PRODUCT_NAME,
    COUNT(ORDER_ID)                   AS TOTAL_ORDERS,
    SUM(QUANTITY)                     AS TOTAL_UNITS_SOLD,
    SUM(QUANTITY * UNIT_PRICE)        AS TOTAL_REVENUE,
    AVG(QUANTITY * UNIT_PRICE)        AS AVG_ORDER_VALUE,
    MIN(QUANTITY * UNIT_PRICE)        AS MIN_ORDER_VALUE,
    MAX(QUANTITY * UNIT_PRICE)        AS MAX_ORDER_VALUE
FROM SALES_ORDERS
WHERE STATUS = 'Completed'
GROUP BY ORDER_DATE, REGION, PRODUCT_NAME;
 
-- Query the materialized view -- results come from pre-computed store
SELECT * FROM MVW_DAILY_SALES
ORDER BY ORDER_DATE, REGION;
 
-- Regional monthly summary using the MV
SELECT
    REGION,
    DATE_TRUNC('month', ORDER_DATE)   AS SALE_MONTH,
    SUM(TOTAL_REVENUE)                AS MONTHLY_REVENUE,
    SUM(TOTAL_UNITS_SOLD)             AS MONTHLY_UNITS
FROM MVW_DAILY_SALES
GROUP BY REGION, SALE_MONTH
ORDER BY REGION, SALE_MONTH;

-- ============================================================
--  MODULE 3B: Inspect MV and test auto-refresh
-- ============================================================
 
-- List all materialized views
SHOW MATERIALIZED VIEWS IN SCHEMA TRAINING;
 
-- Check MV status and freshness
SELECT * FROM TABLE(
    VIEWS_TRAINING_DB.INFORMATION_SCHEMA.MATERIALIZED_VIEW_REFRESH_HISTORY(
        DATE_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())
    )
) LIMIT 10;
 
-- Insert new data into base table
INSERT INTO SALES_ORDERS (EMP_ID, PRODUCT_NAME, QUANTITY, UNIT_PRICE, ORDER_DATE, REGION, STATUS)
VALUES
  (2, 'Tablet',  3, 499.00, CURRENT_DATE(), 'North', 'Completed'),
  (5, 'Tablet',  2, 499.00, CURRENT_DATE(), 'South', 'Completed');
 
-- Snowflake auto-refreshes MV in the background
-- Query MV immediately -- Snowflake uses MV + delta from base table
SELECT * FROM MVW_DAILY_SALES
WHERE ORDER_DATE = CURRENT_DATE()
ORDER BY REGION;

-- ============================================================
--  MODULE 3C: Clustered Materialized View
--  Goal: Demonstrate CLUSTER BY on an MV for faster range queries
--  NOTE: Clustering benefits appear on larger datasets; shown here
--        for syntax and concept familiarity.
-- ============================================================

-- Create a clustered MV optimized for region + date range queries
-- NOTE: CLUSTER BY requires an explicit column list after the view name
CREATE OR REPLACE MATERIALIZED VIEW MVW_SALES_BY_REGION
    (REGION, ORDER_DATE, PRODUCT_NAME, EMP_ID, ORDER_COUNT, TOTAL_UNITS, TOTAL_REVENUE)
    CLUSTER BY (REGION, ORDER_DATE)
AS
SELECT
    REGION,
    ORDER_DATE,
    PRODUCT_NAME,
    EMP_ID,
    COUNT(ORDER_ID)            AS ORDER_COUNT,
    SUM(QUANTITY)              AS TOTAL_UNITS,
    SUM(QUANTITY * UNIT_PRICE) AS TOTAL_REVENUE
FROM SALES_ORDERS
WHERE STATUS = 'Completed'
GROUP BY REGION, ORDER_DATE, PRODUCT_NAME, EMP_ID;

-- Check clustering information (depth, overlap, etc.)
SELECT SYSTEM$CLUSTERING_INFORMATION('VIEWS_TRAINING_DB.TRAINING.MVW_SALES_BY_REGION');

-- Query the clustered MV -- benefits from micro-partition pruning on REGION + ORDER_DATE
SELECT
    REGION,
    SUM(TOTAL_REVENUE)  AS REGION_REVENUE,
    SUM(TOTAL_UNITS)    AS REGION_UNITS,
    SUM(ORDER_COUNT)    AS REGION_ORDERS
FROM MVW_SALES_BY_REGION
WHERE ORDER_DATE BETWEEN '2024-01-01' AND '2024-03-31'
GROUP BY REGION
ORDER BY REGION_REVENUE DESC;

-- Compare: single-region drill-down (cluster pruning skips other regions)
SELECT
    ORDER_DATE,
    PRODUCT_NAME,
    TOTAL_UNITS,
    TOTAL_REVENUE
FROM MVW_SALES_BY_REGION
WHERE REGION = 'North'
ORDER BY ORDER_DATE;

-- ============================================================
--  MODULE 4: Semantic Views (Public Preview)
--  Correct syntax per official Snowflake docs
-- ============================================================

-- IMPORTANT: Syntax rules to remember
--   TABLES:      alias AS physical_table_name  PRIMARY KEY (col)
--   FACTS:       table_alias.logical_name AS <sql_expr>
--   DIMENSIONS:  table_alias.logical_name AS <sql_expr>
--   METRICS:     table_alias.logical_name AS <agg_sql_expr>
--   Clause order MUST be: TABLES → FACTS → DIMENSIONS → METRICS

-- Step 1: Create the Semantic View
CREATE OR REPLACE SEMANTIC VIEW SV_EMPLOYEES
  TABLES (
    emp AS VIEWS_TRAINING_DB.TRAINING.EMPLOYEES
      PRIMARY KEY (EMP_ID)
  )
  FACTS (
    emp.salary_fact     AS SALARY,
    emp.emp_id_fact     AS EMP_ID
  )
  DIMENSIONS (
    emp.department      AS DEPARTMENT,
    emp.first_name      AS FIRST_NAME,
    emp.last_name       AS LAST_NAME,
    emp.is_active       AS IS_ACTIVE,
    emp.hire_date       AS HIRE_DATE
  )
  METRICS (
    emp.total_employees     AS COUNT(EMP_ID),
    emp.avg_salary          AS AVG(SALARY),
    emp.total_salary_cost   AS SUM(SALARY),
    emp.active_count        AS COUNT_IF(IS_ACTIVE)
  )
  COMMENT = 'Semantic layer over EMPLOYEES table for training demo';

-- Step 2: Verify it was created
SHOW SEMANTIC VIEWS IN SCHEMA TRAINING;

-- Step 3: Inspect structure (tables, facts, dimensions, metrics)
DESCRIBE SEMANTIC VIEW SV_EMPLOYEES;

-- Step 4: Query using SEMANTIC_VIEW() table function
--   Syntax: SELECT * FROM SEMANTIC_VIEW(view_name METRICS ... DIMENSIONS ...)
SELECT *
FROM SEMANTIC_VIEW(
    SV_EMPLOYEES
    DIMENSIONS emp.department
    METRICS    emp.total_employees,
               emp.avg_salary,
               emp.total_salary_cost
)
ORDER BY avg_salary DESC; 

-- Step 5: Filter with WHERE inside SEMANTIC_VIEW
SELECT *
FROM SEMANTIC_VIEW(
    SV_EMPLOYEES
    DIMENSIONS emp.department
    METRICS    emp.total_employees,
               emp.avg_salary
    WHERE      emp.is_active = TRUE
)
ORDER BY total_employees DESC;   

-- Step 6: Active headcount metric
SELECT *
FROM SEMANTIC_VIEW(
    SV_EMPLOYEES
    DIMENSIONS emp.department
    METRICS    emp.active_count,
               emp.total_employees
)
ORDER BY active_count DESC; 

-- Step 7: Rename output columns with aliases inside SEMANTIC_VIEW()
SELECT *
FROM SEMANTIC_VIEW(
    SV_EMPLOYEES
    DIMENSIONS emp.department          AS dept,
               emp.is_active           AS active_flag
    METRICS    emp.avg_salary          AS mean_salary,
               emp.total_employees     AS headcount
)
ORDER BY mean_salary DESC;      

-- Step 8: View the DDL
SELECT GET_DDL('SEMANTIC VIEW', 'SV_EMPLOYEES');

-- ============================================================
--  CLEANUP: Run after the session to remove all objects
-- ============================================================
 
-- Drop all views created in training
DROP VIEW  IF EXISTS VW_ACTIVE_EMPLOYEES;
DROP VIEW  IF EXISTS VW_SALES_SUMMARY;
DROP VIEW  IF EXISTS VW_EMP_STANDARD;
DROP VIEW  IF EXISTS VW_DEPT_FILTERED;
DROP VIEW  IF EXISTS VW_EMP_SECURE;
DROP VIEW  IF EXISTS VW_ORG_HIERARCHY;
 
DROP MATERIALIZED VIEW IF EXISTS MVW_DAILY_SALES;
DROP MATERIALIZED VIEW IF EXISTS MVW_SALES_BY_REGION;
DROP MATERIALIZED VIEW IF EXISTS MVW_SECURE_SALES;
 
DROP SEMANTIC VIEW IF EXISTS SV_EMPLOYEES;
 
-- Drop base tables
DROP TABLE IF EXISTS EMPLOYEES;
DROP TABLE IF EXISTS SALES_ORDERS;
DROP TABLE IF EXISTS EMP_HIERARCHY;
DROP TABLE IF EXISTS DEPT_ACCESS_RULES;
 
-- Drop schema and database (optional)
-- DROP SCHEMA   IF EXISTS VIEWS_TRAINING_DB.TRAINING;
-- DROP DATABASE IF EXISTS VIEWS_TRAINING_DB;
 
SELECT 'Cleanup complete!' AS STATUS;
