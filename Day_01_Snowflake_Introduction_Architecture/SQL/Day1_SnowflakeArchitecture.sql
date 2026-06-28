-- Assigning the role for the account 
USE ROLE ACCOUNTADMIN;

-- Assigning the warehouse to the account 
USE WAREHOUSE COMPUTE_WH;

CREATE OR REPLACE DATABASE TRAINING_DB;
USE DATABASE TRAINING_DB;
CREATE OR REPLACE SCHEMA TIME_TRAVEL_DEMO;
USE SCHEMA TIME_TRAVEL_DEMO;

-- Create sample data
CREATE OR REPLACE TABLE sales (
    sale_id INT,
    product STRING,
    amount NUMBER(10,2),
    sale_date TIMESTAMP
);
INSERT INTO sales VALUES
(1, 'Laptop', 50000, CURRENT_TIMESTAMP()),
(2, 'Mobile', 25000, CURRENT_TIMESTAMP()),
(3, 'Keyboard', 2000, CURRENT_TIMESTAMP());

SELECT * FROM sales;
-- Capture Current Timestamp
SELECT CURRENT_TIMESTAMP(); -- Copy the timestamp value shown because Now this timestamp represents the old version of the table.

-- Modify Data
UPDATE sales
SET amount = amount + 10000;

-- Insert More Data
INSERT INTO sales VALUES
(4, 'Mouse', 1500, CURRENT_TIMESTAMP());

SELECT * FROM sales; -- modified data

-- TIME TRAVEL — Query Old Data Using TIMESTAMP

-- Use the timestamp copied earlier.
SELECT * 
FROM sales
AT (TIMESTAMP => '2026-05-14 00:07:51.221'::TIMESTAMP

-- This shows table data BEFORE update and insert.
-- Snowflake stores historical versions automatically.

-- if error then => it will be because the timestamp you used is either:
-- Before the table was created
-- OR
-- Outside the Time Travel retention period

-- Alternative — Query Using OFFSET
-- Instead of exact timestamp.
-- Example: Last 5 minutes
SELECT * 
FROM sales
AT (OFFSET => -60*5);

-- OFFSET is in seconds
-- Negative means “go to past”

-- | Offset | Meaning      |
-- | ------ | ------------ |
-- | -60    | 1 minute ago |
-- | -3600  | 1 hour ago   |
-- | -7200  | 2 hours ago  |

-- Delete records accidentally.
DELETE FROM sales
WHERE sale_id = 2;

-- Check current data:
SELECT * FROM sales;

-- Now recover old state:
SELECT *
FROM sales
AT (OFFSET => -60);
-- This shows deleted row.

-- DROP + UNDROP
-- Drop table accidentally.

DROP TABLE sales;

SELECT * FROM sales;  -- It fails.

-- Now recover:
UNDROP TABLE sales;

-- Verify:
SELECT * FROM sales;

-- Table metadata + data restored
-- Works within Time Travel retention period

-- CLONE from Past
-- This is a very important enterprise feature.

-- First modify table again:

UPDATE sales
SET amount = 999;

-- Check data:
SELECT * FROM sales;

-- Now create clone from older version:
CREATE OR REPLACE TABLE sales_recovery
CLONE sales
AT (OFFSET => -60);

-- Check cloned table:
SELECT * FROM sales_recovery;

-- Clone contains old data
-- Zero-copy clone
-- Instant operation
-- No physical duplication initially

-- Show Retention Period
SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' FOR TABLE sales;

SELECT * FROM sales;  -- Current table:

SELECT * 
FROM sales
AT (OFFSET => -60); -- Past table

-- Snowflake automatically maintains historical versions of data for a retention period. We can query, restore, or clone old versions without backups.

-----------------------------------------------------------------------------------------------------------

-- For Semi Structured Data
-- Create Table with VARIANT Column
CREATE OR REPLACE TABLE events (
    event_id INT,
    event_data VARIANT
);
-- Insert JSON Data
INSERT INTO events
SELECT
    1,
    PARSE_JSON('
    {
        "user_id": "U101",
        "product": {
            "name": "Laptop",
            "brand": "Dell"
        },
        "items": [
            {
                "item_name": "Mouse",
                "price": 499.99
            },
            {
                "item_name": "Keyboard",
                "price": 899.50
            }
        ],
        "orders": [
            {
                "order_id": "ORD1001"
            },
            {
                "order_id": "ORD1002"
            }
        ]
    }');

-- PARSE_JSON() converts JSON string into Snowflake VARIANT object.
-- VARIANT can store semi-structured data.

SELECT * FROM events; -- will see complete JSON stored in one column.
-- Unlike relational databases, Snowflake can directly store nested JSON.

-- Query JSON Fields
SELECT
    event_id,
    event_data:user_id::STRING AS user_id,
    event_data:product.name::STRING AS product_name,
    event_data:product.brand::STRING AS brand,
    event_data:items[0].price::FLOAT AS first_item_price
FROM events;

-- Colon Notation -> event_data:user_id is to Access JSON key.
-- Dot Notation -> event_data:product.name is to Access nested object.
-- Array Access -> event_data:items[0] is to Access first array element.
-- Type Casting
-- ::STRING
-- ::FLOAT
-- Convert VARIANT into SQL datatype.

-- Show Entire Array
SELECT
    event_data:items
FROM events;

-- Access Second Array Element
SELECT
    event_data:items[1].item_name::STRING AS second_item
FROM events;

-- FLATTEN Nested Arrays (Most Important Feature)
SELECT
    f.value:order_id::STRING AS order_id
FROM events,
LATERAL FLATTEN(input => event_data:orders) f;

-- FLATTEN Converts Array Into Rows
-- Input JSON
-- "orders": [
--   {"order_id":"ORD1001"},
--   {"order_id":"ORD1002"}
-- ]
-- Output:
-- ORDER_ID
-- ORD1001
-- ORD1002

-- Complete FLATTEN Output
SELECT *
FROM events,
LATERAL FLATTEN(input => event_data:orders);

-- | Column | Meaning            |
-- | ------ | ------------------ |
-- | VALUE  | Actual JSON object |
-- | INDEX  | Array position     |
-- | PATH   | JSON path          |

-- Flatten Items Array
SELECT
    f.value:item_name::STRING AS item_name,
    f.value:price::FLOAT AS price
FROM events,
LATERAL FLATTEN(input => event_data:items) f;

-- Insert Multiple JSON Rows
INSERT INTO events
SELECT
    2,
    PARSE_JSON('
    {
        "user_id": "U102",
        "product": {
            "name": "Mobile",
            "brand": "Samsung"
        },
        "items": [
            {
                "item_name": "Charger",
                "price": 1200
            }
        ],
        "orders": [
            {
                "order_id": "ORD2001"
            }
        ]
    }');

SELECT
    event_id,
    event_data:user_id::STRING AS user_id,
    event_data:product.name::STRING AS product_name
FROM events;

-- Real-World Use Cases 
-- Snowflake Semi-Structured Data is Commonly Used For:

-- | Use Case         | Example            |
-- | ---------------- | ------------------ |
-- | API responses    | JSON payloads      |
-- | Clickstream data | Website tracking   |
-- | IoT devices      | Sensor JSON        |
-- | Logs             | Application logs   |
-- | Kafka ingestion  | Streaming JSON     |
-- | Data lakes       | Parquet/Avro files |


-------------------------------------------------------------
-- SQL Examples — Creating Objects
-------------------------------------------------------------

-- Assigning the role for the account 
USE ROLE ACCOUNTADMIN;
-- Assigning the warehouse to the account 
USE WAREHOUSE COMPUTE_WH;

-- Step 1: Create a Database
CREATE DATABASE SALES_DB
  DATA_RETENTION_TIME_IN_DAYS = 7
  COMMENT = 'Sales domain database';

-- Show databases
SHOW DATABASES LIKE 'SALES_DB';

-- Step 2: Create Schemas
CREATE SCHEMA SALES_DB.RAW        COMMENT = 'Raw ingested data';
CREATE SCHEMA SALES_DB.STAGING    COMMENT = 'Cleaned/transformed data';
CREATE SCHEMA SALES_DB.REPORTING  COMMENT = 'Business-ready analytics';

-- Show schemas
SHOW SCHEMAS IN DATABASE SALES_DB;

-- Step 3: Create a Permanent Table
CREATE OR REPLACE TABLE SALES_DB.REPORTING.SALES_FACT (
  sale_id        NUMBER AUTOINCREMENT PRIMARY KEY,
  sale_date      DATE NOT NULL,
  customer_id    NUMBER NOT NULL,
  product_id     NUMBER NOT NULL,
  region         VARCHAR(50),
  quantity       NUMBER(10,0),
  unit_price     NUMBER(10,2),
  total_amount   NUMBER(12,2),
  created_at     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Describe table structure
DESC TABLE SALES_DB.REPORTING.SALES_FACT;

-- Show tables
SHOW TABLES IN SCHEMA SALES_DB.REPORTING;

-- Step 4: Create a Transient Table (for staging)
CREATE OR REPLACE TRANSIENT TABLE SALES_DB.STAGING.SALES_STAGE (
  raw_data VARIANT
);

-- Describe transient table
DESC TABLE SALES_DB.STAGING.SALES_STAGE;

-- Show tables in staging schema
SHOW TABLES IN SCHEMA SALES_DB.STAGING;

-- Step 5: Create an Internal Stage
CREATE OR REPLACE STAGE SALES_DB.RAW.my_stage
  FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
  );

-- Show stages
SHOW STAGES IN SCHEMA SALES_DB.RAW;

-- Step 6: Create a File Format
CREATE OR REPLACE FILE FORMAT SALES_DB.RAW.csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '')
  EMPTY_FIELD_AS_NULL = TRUE;

-- Show file formats
SHOW FILE FORMATS IN SCHEMA SALES_DB.RAW;

-- Step 7: Create a View
CREATE OR REPLACE VIEW SALES_DB.REPORTING.MONTHLY_REVENUE AS
  SELECT
    DATE_TRUNC('MONTH', sale_date) AS month,
    region,
    SUM(total_amount) AS revenue
  FROM SALES_DB.REPORTING.SALES_FACT
  GROUP BY 1, 2;

-- Show views
SHOW VIEWS IN SCHEMA SALES_DB.REPORTING;
-- Describe view
DESC VIEW SALES_DB.REPORTING.MONTHLY_REVENUE;

-- Step 8: Create a Sequence
CREATE OR REPLACE SEQUENCE SALES_DB.RAW.customer_seq
  START = 1 INCREMENT = 1;

-- Show sequences
SHOW SEQUENCES IN SCHEMA SALES_DB.RAW;

-- Generate sample sequence values
SELECT SALES_DB.RAW.customer_seq.NEXTVAL AS next_sequence_value;

-- Insert Sample Data to View Results
---------------------------------------------------
INSERT INTO SALES_DB.REPORTING.SALES_FACT
(
  sale_date,
  customer_id,
  product_id,
  region,
  quantity,
  unit_price,
  total_amount
)
VALUES
('2026-05-01', 1, 101, 'North', 2, 500, 1000),
('2026-05-02', 2, 102, 'South', 1, 700, 700),
('2026-05-10', 3, 103, 'East', 5, 200, 1000);

-- Query table data
SELECT * 
FROM SALES_DB.REPORTING.SALES_FACT;

-- Query view output
SELECT * 
FROM SALES_DB.REPORTING.MONTHLY_REVENUE;

----------------------------------------------------------------------------------------------------

-- Auto Suspend & Auto Resume

-- Create a warehouse with auto-suspend and auto-resume
CREATE OR REPLACE WAREHOUSE ANALYTICS_WH
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 300           -- Suspend after 5 minutes of inactivity
  AUTO_RESUME = TRUE           -- Resume automatically on query submission
  MIN_CLUSTER_COUNT = 1        -- For multi-cluster: min clusters
  MAX_CLUSTER_COUNT = 3        -- For multi-cluster: max clusters
  SCALING_POLICY = 'STANDARD'  -- STANDARD or ECONOMY
  COMMENT = 'Analytics team warehouse';

-- Manually start/stop a warehouse
ALTER WAREHOUSE ANALYTICS_WH RESUME;
ALTER WAREHOUSE ANALYTICS_WH SUSPEND;

-- Resize a warehouse (takes effect immediately)
ALTER WAREHOUSE ANALYTICS_WH SET WAREHOUSE_SIZE = 'LARGE';

-- =============================================
-- SNOWFLAKE HANDS-ON LAB: SALES ANALYTICS
-- Run each step sequentially 
-- =============================================

-- STEP 1: Set Context
USE ROLE SYSADMIN;

-- STEP 2: Create Virtual Warehouse
CREATE OR REPLACE WAREHOUSE LAB_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 120
  AUTO_RESUME = TRUE
  COMMENT = 'Lab warehouse for training';

USE WAREHOUSE LAB_WH;

-- STEP 3: Create Database and Schemas
CREATE OR REPLACE DATABASE TRAINING_DB
  DATA_RETENTION_TIME_IN_DAYS = 1
  COMMENT = 'Training database for lab exercises';

CREATE OR REPLACE SCHEMA TRAINING_DB.SALES
  COMMENT = 'Sales analytics schema';

USE SCHEMA TRAINING_DB.SALES;

-- STEP 4: Create Tables
CREATE OR REPLACE TABLE CUSTOMERS (
  customer_id    NUMBER(10,0) PRIMARY KEY,
  first_name     VARCHAR(50) NOT NULL,
  last_name      VARCHAR(50) NOT NULL,
  email          VARCHAR(100),
  city           VARCHAR(50),
  country        VARCHAR(50),
  segment        VARCHAR(30)
);

CREATE OR REPLACE TABLE PRODUCTS (
  product_id     NUMBER(10,0) PRIMARY KEY,
  product_name   VARCHAR(100) NOT NULL,
  category       VARCHAR(50),
  sub_category   VARCHAR(50),
  unit_price     NUMBER(10,2)
);

CREATE OR REPLACE TABLE SALES_ORDERS (
  order_id       NUMBER(10,0) PRIMARY KEY,
  order_date     DATE NOT NULL,
  customer_id    NUMBER(10,0) REFERENCES CUSTOMERS(customer_id),
  product_id     NUMBER(10,0) REFERENCES PRODUCTS(product_id),
  quantity       NUMBER(5,0),
  discount_pct   NUMBER(5,2),
  total_amount   NUMBER(12,2),
  region         VARCHAR(30)
);

-- STEP 5: Insert Sample Data (Customers)
INSERT INTO CUSTOMERS VALUES
  (1,'Rahul','Sharma','rahul@example.com','Mumbai','India','Corporate'),
  (2,'Priya','Patel','priya@example.com','Delhi','India','Consumer'),
  (3,'John','Smith','john@example.com','New York','USA','Corporate'),
  (4,'Emma','Wilson','emma@example.com','London','UK','Consumer'),
  (5,'Zhang','Wei','zhang@example.com','Shanghai','China','Corporate'),
  (6,'Fatima','Ahmed','fatima@example.com','Dubai','UAE','Consumer'),
  (7,'Carlos','Garcia','carlos@example.com','Mexico City','Mexico','Consumer'),
  (8,'Yuki','Tanaka','yuki@example.com','Tokyo','Japan','Corporate');

-- STEP 6: Insert Sample Data (Products)
INSERT INTO PRODUCTS VALUES
  (101,'MacBook Pro 14','Technology','Laptops',199999),
  (102,'iPhone 15 Pro','Technology','Phones',99999),
  (103,'Wireless Mouse','Technology','Accessories',2999),
  (104,'Office Chair','Furniture','Chairs',15000),
  (105,'Standing Desk','Furniture','Desks',45000),
  (106,'Notebook Pack','Office Supplies','Paper',500),
  (107,'USB-C Hub','Technology','Accessories',3500),
  (108,'Monitor 27 inch','Technology','Monitors',35000);

-- STEP 7: Insert Sample Data (Orders)
INSERT INTO SALES_ORDERS VALUES
  (1001,'2025-01-05',1,101,2,5.0,379998.00,'APAC'),
  (1002,'2025-01-08',2,102,1,0.0,99999.00,'APAC'),
  (1003,'2025-01-10',3,104,5,10.0,67500.00,'Americas'),
  (1004,'2025-01-12',4,108,3,0.0,105000.00,'EMEA'),
  (1005,'2025-01-15',5,105,10,15.0,382500.00,'APAC'),
  (1006,'2025-02-01',6,103,20,5.0,57000.00,'EMEA'),
  (1007,'2025-02-05',7,106,100,0.0,50000.00,'Americas'),
  (1008,'2025-02-10',8,107,15,10.0,47250.00,'APAC'),
  (1009,'2025-02-14',1,102,3,5.0,284997.00,'APAC'),
  (1010,'2025-03-01',2,104,2,0.0,30000.00,'APAC'),
  (1011,'2025-03-05',3,101,1,0.0,199999.00,'Americas'),
  (1012,'2025-03-10',4,108,5,10.0,157500.00,'EMEA');

-- STEP 8: Basic Verification Queries
SELECT COUNT(*) AS customer_count FROM CUSTOMERS;
SELECT COUNT(*) AS product_count FROM PRODUCTS;
SELECT COUNT(*) AS order_count FROM SALES_ORDERS;

-- STEP 9: Analytical Queries
-- Q1: Total Revenue by Region
SELECT
  region,
  COUNT(order_id) AS total_orders,
  SUM(total_amount) AS total_revenue,
  AVG(total_amount) AS avg_order_value,
  ROUND(SUM(total_amount) / SUM(SUM(total_amount)) OVER () * 100, 2) AS revenue_pct
FROM SALES_ORDERS
GROUP BY region
ORDER BY total_revenue DESC;

-- Q2: Top Products by Revenue
SELECT
  p.product_name,
  p.category,
  SUM(s.quantity) AS units_sold,
  SUM(s.total_amount) AS total_revenue
FROM SALES_ORDERS s
JOIN PRODUCTS p ON s.product_id = p.product_id
GROUP BY p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 5;

-- Q3: Monthly Revenue Trend
SELECT
  DATE_TRUNC('MONTH', order_date) AS month,
  SUM(total_amount) AS monthly_revenue,
  LAG(SUM(total_amount)) OVER (ORDER BY DATE_TRUNC('MONTH', order_date)) AS prev_month,
  ROUND((SUM(total_amount) - LAG(SUM(total_amount))
    OVER (ORDER BY DATE_TRUNC('MONTH', order_date)))
    / LAG(SUM(total_amount)) OVER (ORDER BY DATE_TRUNC('MONTH', order_date)) * 100, 2) AS mom_growth_pct
FROM SALES_ORDERS
GROUP BY DATE_TRUNC('MONTH', order_date)
ORDER BY month;

-- Q4: Customer Segment Analysis
SELECT
  c.segment,
  c.country,
  COUNT(DISTINCT s.order_id) AS orders,
  SUM(s.total_amount) AS revenue
FROM SALES_ORDERS s
JOIN CUSTOMERS c ON s.customer_id = c.customer_id
GROUP BY c.segment, c.country
ORDER BY revenue DESC;

-- STEP 10: Demonstrate Time Travel
-- Check current row count
SELECT COUNT(*) AS before_delete FROM SALES_ORDERS;

-- Accidentally delete some records
DELETE FROM SALES_ORDERS WHERE region = 'EMEA';

-- See the damage
SELECT COUNT(*) AS after_delete FROM SALES_ORDERS;

-- Recover using Time Travel (go back 60 seconds)
SELECT COUNT(*) FROM SALES_ORDERS AT (OFFSET => -60);

-- Restore the deleted records
INSERT INTO SALES_ORDERS
  SELECT * FROM SALES_ORDERS AT (OFFSET => -60)
  WHERE region = 'EMEA';

-- Verify restoration
SELECT COUNT(*) AS restored_count FROM SALES_ORDERS;

-- STEP 11: Zero-Copy Clone 
CREATE TABLE SALES_ORDERS_BACKUP CLONE SALES_ORDERS;
SELECT COUNT(*) FROM SALES_ORDERS_BACKUP; -- Instant! Same data.

-- STEP 12: Check Query History
SELECT
  query_text,
  execution_status,
  total_elapsed_time / 1000 AS elapsed_seconds,
  bytes_scanned,
  percentage_scanned_from_cache
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
ORDER BY start_time DESC
LIMIT 10;


-- Essential SQL Commands Reference

-- Context Setting
-- USE ROLE SYSADMIN;
-- USE WAREHOUSE MY_WH;
-- USE DATABASE MY_DB;
-- USE SCHEMA MY_SCHEMA;

-- -- Warehouse Management
-- CREATE WAREHOUSE wh SIZE='MEDIUM' AUTO_SUSPEND=300 AUTO_RESUME=TRUE;
-- ALTER WAREHOUSE wh SUSPEND;
-- ALTER WAREHOUSE wh RESUME;
-- ALTER WAREHOUSE wh SET WAREHOUSE_SIZE='LARGE';

-- -- Object Creation
-- CREATE DATABASE my_db DATA_RETENTION_TIME_IN_DAYS=7;
-- CREATE SCHEMA my_db.my_schema;
-- CREATE TABLE my_table (id NUMBER, name VARCHAR(100));
-- CREATE TRANSIENT TABLE my_stage_tbl (data VARIANT);
-- CREATE VIEW my_view AS SELECT ...;
-- CREATE STAGE my_stage FILE_FORMAT=(TYPE='CSV' SKIP_HEADER=1);

-- Data Loading
-- PUT file:///local/path/data.csv @my_stage;
-- COPY INTO my_table FROM @my_stage VALIDATION_MODE='RETURN_ERRORS';
-- COPY INTO my_table FROM @my_stage PURGE=TRUE;

-- Time Travel
-- SELECT * FROM my_table AT (OFFSET => -3600);
-- SELECT * FROM my_table AT (TIMESTAMP => '2025-01-15 10:00:00'::TIMESTAMP);
-- UNDROP TABLE my_table;
-- CREATE TABLE recovery CLONE my_table AT (OFFSET => -7200);

-- -- Security
-- CREATE ROLE my_role;
-- GRANT USAGE ON DATABASE my_db TO ROLE my_role;
-- GRANT USAGE ON SCHEMA my_db.my_schema TO ROLE my_role;
-- GRANT SELECT ON ALL TABLES IN SCHEMA my_db.my_schema TO ROLE my_role;
-- GRANT USAGE ON WAREHOUSE my_wh TO ROLE my_role;
-- CREATE USER myuser PASSWORD='...' DEFAULT_ROLE=my_role;
-- GRANT ROLE my_role TO USER myuser;

-- -- Monitoring
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY()) ORDER BY start_time DESC LIMIT 20;
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(DATEADD('days', -7, CURRENT_DATE)));
-- SHOW WAREHOUSES;
-- SHOW DATABASES;
-- SHOW TABLES;
-- SHOW GRANTS TO ROLE my_role;

