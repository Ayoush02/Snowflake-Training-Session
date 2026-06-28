USE ROLE ACCOUNTADMIN;


-- ============================================================
-- STEP 1: ENVIRONMENT SETUP - Run as SYSADMIN or ACCOUNTADMIN
-- ============================================================

-- Create dedicated database and schema
CREATE DATABASE IF NOT EXISTS CORTEX_TRAINING_DB;
USE DATABASE CORTEX_TRAINING_DB;
CREATE SCHEMA IF NOT EXISTS ECOMMERCE;
USE SCHEMA ECOMMERCE;

-- Create Virtual Warehouse
CREATE WAREHOUSE IF NOT EXISTS CORTEX_WH
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 120
  AUTO_RESUME = TRUE
  COMMENT = 'Warehouse for Cortex AI Training';

USE WAREHOUSE CORTEX_WH;

-- ============================================================
-- STEP 2: CREATE TABLE
-- ============================================================
CREATE OR REPLACE TABLE ECOMMERCE_ORDERS (
  ORDER_ID           VARCHAR(20)    NOT NULL,
  CUSTOMER_ID        VARCHAR(20),
  PRODUCT_ID         VARCHAR(20),
  CUSTOMER_NAME      VARCHAR(100),
  AGE_GROUP          VARCHAR(20),
  GENDER             VARCHAR(20),
  CITY               VARCHAR(100),
  STATE              VARCHAR(100),
  REGION             VARCHAR(50),
  PRODUCT_CATEGORY   VARCHAR(100),
  PRODUCT_NAME       VARCHAR(200),
  SALES_CHANNEL      VARCHAR(100),
  PAYMENT_METHOD     VARCHAR(100),
  CUSTOMER_SEGMENT   VARCHAR(50),
  ORDER_DATE         DATE,
  DELIVERY_DATE      DATE,
  UNIT_PRICE         NUMBER(12,2),
  QUANTITY           NUMBER(5,0),
  DISCOUNT_PCT       NUMBER(5,2),
  GROSS_AMOUNT       NUMBER(12,2),
  DISCOUNT_AMOUNT    NUMBER(12,2),
  NET_AMOUNT         NUMBER(12,2),
  GST_RATE           NUMBER(5,2),
  GST_AMOUNT         NUMBER(12,2),
  TOTAL_AMOUNT       NUMBER(12,2),
  SHIPPING_STATUS    VARCHAR(50),
  REVIEW_RATING      NUMBER(2,0),
  FEEDBACK_SENTIMENT VARCHAR(30),
  ORDER_YEAR         NUMBER(4,0),
  ORDER_MONTH        NUMBER(2,0),
  MONTH_NAME         VARCHAR(20),
  IS_WEEKDAY         NUMBER(1,0)
);

-- ============================================================
-- STEP 3: CREATE STAGE AND LOAD DATA
-- ============================================================
CREATE OR REPLACE STAGE CORTEX_STAGE
  FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                 SKIP_HEADER = 1 NULL_IF = ('') EMPTY_FIELD_AS_NULL = TRUE);

-- Upload CSV using Snowsight: Data > Add Data > Load files into table
-- OR use SnowSQL CLI:
-- PUT file://ecommerce_cortex_dataset.csv @CORTEX_STAGE AUTO_COMPRESS=TRUE;

COPY INTO ECOMMERCE_ORDERS
FROM @CORTEX_STAGE/ecommerce_cortex_dataset.csv.gz
FILE_FORMAT = (TYPE='CSV' FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1
              NULL_IF=('') EMPTY_FIELD_AS_NULL=TRUE)
ON_ERROR = 'CONTINUE';

-- Verify load
SELECT COUNT(*) AS TOTAL_RECORDS FROM ECOMMERCE_ORDERS;
SELECT * FROM ECOMMERCE_ORDERS LIMIT 5;

-- Grant Cortex usage to your role
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SYSADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ACCOUNTADMIN;

-- Verify Cortex is accessible
-- SELECT SNOWFLAKE.CORTEX.SENTIMENT('This training is excellent!') AS TEST_SENTIMENT;
-- Expected output: a value close to 1.0 (highly positive)

-- Quick data quality check
SELECT
  COUNT(*)                                            AS TOTAL_ROWS,
  COUNT(DISTINCT CUSTOMER_ID)                        AS UNIQUE_CUSTOMERS,
  COUNT(DISTINCT PRODUCT_CATEGORY)                   AS CATEGORIES,
  COUNT(DISTINCT CITY)                               AS CITIES,
  MIN(ORDER_DATE)                                    AS EARLIEST_ORDER,
  MAX(ORDER_DATE)                                    AS LATEST_ORDER,
  ROUND(SUM(TOTAL_AMOUNT)/1000000, 2)               AS TOTAL_REVENUE_MILLIONS
FROM ECOMMERCE_ORDERS;

-- Distribution check
SELECT PRODUCT_CATEGORY, COUNT(*) AS ORDERS, ROUND(AVG(TOTAL_AMOUNT),2) AS AVG_ORDER
FROM ECOMMERCE_ORDERS
GROUP BY PRODUCT_CATEGORY
ORDER BY ORDERS DESC;

-- ============================================================
-- MODULE 3A: SENTIMENT ANALYSIS
-- ============================================================

-- Basic sentiment on feedback (using review rating as proxy text)
-- First create a review_text column to simulate customer reviews
-- ============================================================
-- MODULE 3A: SENTIMENT ANALYSIS
-- ============================================================

-- Basic sentiment on feedback (using review rating as proxy text)
-- First create a review_text column to simulate customer reviews
CREATE OR REPLACE TABLE ECOMMERCE_WITH_REVIEWS AS
SELECT *,
  CASE
    WHEN REVIEW_RATING = 5 THEN 'Excellent product! Absolutely loved it. Fast delivery and great quality.'
    WHEN REVIEW_RATING = 4 THEN 'Good product, met expectations. Delivery was on time and packaging was fine.'
    WHEN REVIEW_RATING = 3 THEN 'Average experience. Product is okay but could be better. Delivery took time.'
    WHEN REVIEW_RATING = 2 THEN 'Not satisfied with the product quality. Expected better for the price paid.'
    WHEN REVIEW_RATING = 1 THEN 'Terrible experience. Product damaged on arrival. Very poor customer service.'
    ELSE 'No review provided.'
  END AS REVIEW_TEXT
FROM ECOMMERCE_ORDERS;

-- Run SENTIMENT on review text 

SELECT
  ORDER_ID,
  PRODUCT_NAME,
  REVIEW_RATING,
  REVIEW_TEXT,
  SNOWFLAKE.CORTEX.SENTIMENT(REVIEW_TEXT) AS SENTIMENT_SCORE,
  CASE
    WHEN SNOWFLAKE.CORTEX.SENTIMENT(REVIEW_TEXT) > 0.3  THEN 'Positive'
    WHEN SNOWFLAKE.CORTEX.SENTIMENT(REVIEW_TEXT) < -0.3 THEN 'Negative'
    ELSE 'Neutral'
  END AS SENTIMENT_LABEL
FROM ECOMMERCE_WITH_REVIEWS
LIMIT 20;

-- Aggregate sentiment by category
SELECT
  PRODUCT_CATEGORY,
  COUNT(*) AS TOTAL_REVIEWS,
  ROUND(AVG(SNOWFLAKE.CORTEX.SENTIMENT(REVIEW_TEXT)), 4) AS AVG_SENTIMENT,
  SUM(CASE WHEN SNOWFLAKE.CORTEX.SENTIMENT(REVIEW_TEXT) > 0.3 THEN 1 ELSE 0 END) AS POSITIVE_COUNT,
  SUM(CASE WHEN SNOWFLAKE.CORTEX.SENTIMENT(REVIEW_TEXT) < -0.3 THEN 1 ELSE 0 END) AS NEGATIVE_COUNT
FROM ECOMMERCE_WITH_REVIEWS
GROUP BY PRODUCT_CATEGORY
ORDER BY AVG_SENTIMENT DESC;


-- ============================================================
-- MODULE 3B: SUMMARIZE
-- ============================================================
-- THIS CODE MIGHT NOT RUN AS SNOWFLAKE.CORTEX.SUMMARIZE MAY NOT BE IN TRIAL ACCOUNTS AS YOU CAN CHECK THOUGH

-- Summarize customer feedback for a product category
SELECT
  PRODUCT_CATEGORY,
  SNOWFLAKE.CORTEX.SUMMARIZE(
    LEFT(
      LISTAGG(REVIEW_TEXT, ' | ') WITHIN GROUP (ORDER BY ORDER_DATE DESC),
      20000
    )
  ) AS CATEGORY_FEEDBACK_SUMMARY
FROM CORTEX_TRAINING_DB.ECOMMERCE.ECOMMERCE_WITH_REVIEWS
WHERE PRODUCT_CATEGORY = 'Electronics'
GROUP BY PRODUCT_CATEGORY;

-- Summarize per shipping status complaints
SELECT
  SHIPPING_STATUS,
  SNOWFLAKE.CORTEX.SUMMARIZE(
    LEFT(
      LISTAGG(REVIEW_TEXT, '. ') WITHIN GROUP (ORDER BY ORDER_DATE DESC),
      20000
    )
  ) AS STATUS_SUMMARY
FROM CORTEX_TRAINING_DB.ECOMMERCE.ECOMMERCE_WITH_REVIEWS
WHERE SHIPPING_STATUS IN ('Returned', 'Cancelled')
GROUP BY SHIPPING_STATUS;

-- ============================================================
-- MODULE 3C: COMPLETE() - LLM Text Generation
-- ============================================================

-- Generate product descriptions using LLM
SELECT DISTINCT
  PRODUCT_NAME,
  PRODUCT_CATEGORY,
  ROUND(AVG(UNIT_PRICE), 2) AS AVG_PRICE,
  SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-8b',
    CONCAT(
      'Write a 2-sentence marketing description for this product: ',
      PRODUCT_NAME,
      ' in category ',
      PRODUCT_CATEGORY,
      ' priced at INR ',
      ROUND(AVG(UNIT_PRICE), 2),
      '. Keep it concise and engaging for Indian e-commerce customers.'
    )
  ) AS PRODUCT_DESCRIPTION
FROM ECOMMERCE_ORDERS
GROUP BY PRODUCT_NAME, PRODUCT_CATEGORY
LIMIT 5;

-- Classify customer complaints automatically
SELECT
  ORDER_ID,
  SHIPPING_STATUS,
  REVIEW_TEXT,
  SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-8b',
    CONCAT(
      'Classify this customer review into ONE category: ',
      '[DELIVERY_ISSUE, PRODUCT_QUALITY, PRICING, PACKAGING, CUSTOMER_SERVICE, POSITIVE_EXPERIENCE] ',
      'Review: ', REVIEW_TEXT,
      '. Respond with ONLY the category name, nothing else.'
    )
  ) AS COMPLAINT_CATEGORY
FROM ECOMMERCE_WITH_REVIEWS
WHERE REVIEW_RATING <= 2
LIMIT 10;

-- Generate upsell recommendations using COMPLETE
SELECT
  CUSTOMER_ID,
  CUSTOMER_NAME,
  PRODUCT_CATEGORY,
  CUSTOMER_SEGMENT,
  SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-70b',
    CONCAT(
      'A customer who is a ',CUSTOMER_SEGMENT,' buyer just purchased items from ',
      PRODUCT_CATEGORY,' category. Suggest 2 complementary product categories ',
      'they might buy next. Reply in exactly this JSON format: ',
      '{"primary_recommendation": "<category>", "secondary_recommendation": "<category>"}' 
    )
  ) AS UPSELL_RECOMMENDATIONS
FROM ECOMMERCE_ORDERS
WHERE CUSTOMER_SEGMENT = 'VIP'
LIMIT 5;

-- ============================================================
-- MODULE 3D: TRANSLATE()
-- ============================================================

-- Translate product names to Hindi for regional campaigns
SELECT
  PRODUCT_NAME,
  PRODUCT_CATEGORY,
  SNOWFLAKE.CORTEX.TRANSLATE(PRODUCT_NAME, 'en', 'hi') AS PRODUCT_NAME_HINDI,
  SNOWFLAKE.CORTEX.TRANSLATE(PRODUCT_NAME, 'en', 'ta') AS PRODUCT_NAME_TAMIL,
  SNOWFLAKE.CORTEX.TRANSLATE(PRODUCT_NAME, 'en', 'it') AS PRODUCT_NAME_TELUGU
FROM ECOMMERCE_ORDERS
GROUP BY PRODUCT_NAME, PRODUCT_CATEGORY
LIMIT 10;

-- Translate city-level customer communications
SELECT
  CITY, STATE,
  CONCAT('Your order from ', PRODUCT_NAME, ' has been ', SHIPPING_STATUS) AS NOTIFICATION_EN,
  SNOWFLAKE.CORTEX.TRANSLATE(
    CONCAT('Your order from ', PRODUCT_NAME, ' has been ', SHIPPING_STATUS),
    'en', 'hi'
  ) AS NOTIFICATION_HINDI
FROM ECOMMERCE_ORDERS
WHERE STATE IN ('Maharashtra', 'Gujarat')
LIMIT 5;

-- ============================================================
-- MODULE 3E: EXTRACT_ANSWER()
-- ============================================================

-- Extract specific answers from review text
SELECT
  ORDER_ID,
  PRODUCT_NAME,
  REVIEW_TEXT,
  SNOWFLAKE.CORTEX.EXTRACT_ANSWER(REVIEW_TEXT, 'What is the customer saying about delivery?') AS DELIVERY_INSIGHT,
  SNOWFLAKE.CORTEX.EXTRACT_ANSWER(REVIEW_TEXT, 'What is the customer saying about product quality?') AS QUALITY_INSIGHT
FROM ECOMMERCE_WITH_REVIEWS
WHERE REVIEW_RATING IN (1, 2, 5)
LIMIT 10;

-- ============================================================
-- MODULE 3F: EMBED_TEXT & VECTOR SIMILARITY SEARCH
-- ============================================================
-- NOT FOR TRAIL ACCOUNTS

-- Create embeddings table for product reviews
CREATE OR REPLACE TABLE REVIEW_EMBEDDINGS AS
SELECT
  ORDER_ID,
  PRODUCT_NAME,
  PRODUCT_CATEGORY,
  REVIEW_TEXT,
  REVIEW_RATING,
  SNOWFLAKE.CORTEX.EMBED_TEXT_768('snowflake-arctic-embed-m', REVIEW_TEXT) AS REVIEW_EMBEDDING
FROM ECOMMERCE_WITH_REVIEWS
LIMIT 500; -- Limiting for demo; remove limit for full dataset

-- Semantic similarity search: find reviews similar to a query
SELECT
  ORDER_ID,
  PRODUCT_NAME,
  REVIEW_TEXT,
  REVIEW_RATING,
  VECTOR_COSINE_SIMILARITY(
    REVIEW_EMBEDDING,
    SNOWFLAKE.CORTEX.EMBED_TEXT_768(
      'snowflake-arctic-embed-m',
      'product arrived damaged and broken'
    )
  ) AS SIMILARITY_SCORE
FROM REVIEW_EMBEDDINGS
ORDER BY SIMILARITY_SCORE DESC
LIMIT 10;

-- Find semantically similar complaints for clustering
SELECT
  A.ORDER_ID AS ORDER_A,
  B.ORDER_ID AS ORDER_B,
  A.REVIEW_TEXT AS REVIEW_A,
  B.REVIEW_TEXT AS REVIEW_B,
  VECTOR_COSINE_SIMILARITY(A.REVIEW_EMBEDDING, B.REVIEW_EMBEDDING) AS SIMILARITY
FROM REVIEW_EMBEDDINGS A
JOIN REVIEW_EMBEDDINGS B ON A.ORDER_ID < B.ORDER_ID
WHERE VECTOR_COSINE_SIMILARITY(A.REVIEW_EMBEDDING, B.REVIEW_EMBEDDING) > 0.95
  AND A.REVIEW_RATING <= 2
LIMIT 10;

-- ============================================================
-- MODULE 4: CORTEX ANALYST - SEMANTIC MODEL SETUP
-- ============================================================

-- Step 1: Create stage for semantic model YAML
CREATE OR REPLACE STAGE SEMANTIC_MODELS_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage for Cortex Analyst semantic model files';

-- Step 2: Create the semantic model YAML content
-- Save the following as ecommerce_semantic_model.yaml and upload to stage:
/*
name: ecommerce_sales_model
description: E-commerce sales semantic model for natural language querying
tables:
  - name: ECOMMERCE_ORDERS
    description: Main orders table with customer and product details
    base_table:
      database: CORTEX_TRAINING_DB
      schema: ECOMMERCE
      table: ECOMMERCE_ORDERS
    dimensions:
      - name: product_category
        description: Category of the product
        expr: PRODUCT_CATEGORY
        data_type: TEXT
      - name: city
        description: Customer city
        expr: CITY
        data_type: TEXT
      - name: region
        description: Geographic region
        expr: REGION
        data_type: TEXT
      - name: customer_segment
        description: Customer segment (New/Regular/Premium/VIP)
        expr: CUSTOMER_SEGMENT
        data_type: TEXT
      - name: shipping_status
        description: Delivery status of order
        expr: SHIPPING_STATUS
        data_type: TEXT
      - name: sales_channel
        description: Channel through which order was placed
        expr: SALES_CHANNEL
        data_type: TEXT
    time_dimensions:
      - name: order_date
        description: Date when order was placed
        expr: ORDER_DATE
        data_type: DATE
    measures:
      - name: total_revenue
        description: Total order amount including GST
        expr: SUM(TOTAL_AMOUNT)
        data_type: NUMBER
      - name: order_count
        description: Number of orders
        expr: COUNT(DISTINCT ORDER_ID)
        data_type: NUMBER
      - name: avg_order_value
        description: Average order value
        expr: AVG(TOTAL_AMOUNT)
        data_type: NUMBER
      - name: avg_rating
        description: Average customer review rating
        expr: AVG(REVIEW_RATING)
        data_type: NUMBER
*/

-- Step 3: After uploading YAML, test Cortex Analyst via Snowsight
-- Navigate to: Snowsight > AI & ML > Cortex Analyst
-- Select your semantic model file and start asking natural language questions

-- Example questions to ask Cortex Analyst:
-- 'What is the total revenue by product category in 2023?'
-- 'Which city has the most orders?'
-- 'Show me monthly revenue trend for Electronics'
-- 'What is the average order value for VIP customers?'
-- 'Which region has the highest return rate?'CORTEX_TRAINING_DB.ECOMMERCE.CORTEX_STAGE

LIST @cortex_stage;


-- ============================================================
-- MODULE 4B: CORTEX SEARCH SERVICE
-- ============================================================

-- Create Cortex Search Service on review text
CREATE OR REPLACE CORTEX SEARCH SERVICE PRODUCT_REVIEW_SEARCH
  ON REVIEW_TEXT
  ATTRIBUTES PRODUCT_CATEGORY, PRODUCT_NAME, REVIEW_RATING, SHIPPING_STATUS
  WAREHOUSE = CORTEX_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT
      ORDER_ID,
      PRODUCT_CATEGORY,
      PRODUCT_NAME,
      REVIEW_TEXT,
      REVIEW_RATING,
      SHIPPING_STATUS,
      CUSTOMER_SEGMENT,
      ORDER_DATE
    FROM ECOMMERCE_WITH_REVIEWS
  );

-- Query the Search Service using REST API syntax via SQL
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'CORTEX_TRAINING_DB.ECOMMERCE.PRODUCT_REVIEW_SEARCH',
    '{
      "query": "product damaged during delivery",
      "columns": ["ORDER_ID", "PRODUCT_NAME", "REVIEW_TEXT", "REVIEW_RATING"],
      "filter": {"@eq": {"SHIPPING_STATUS": "Delivered"}},
      "limit": 10
    }'
  )
) AS SEARCH_RESULTS;

-- Search for positive reviews by category
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'CORTEX_TRAINING_DB.ECOMMERCE.PRODUCT_REVIEW_SEARCH',
    '{
      "query": "excellent quality fast delivery happy customer",
      "columns": ["ORDER_ID", "PRODUCT_CATEGORY", "PRODUCT_NAME", "REVIEW_TEXT"],
      "filter": {"@eq": {"PRODUCT_CATEGORY": "Electronics"}},
      "limit": 5
    }'
  )
) AS POSITIVE_SEARCH;


-- ============================================================
-- MODULE 5A: CORTEX ML - FORECASTING
-- ============================================================

-- Prepare monthly sales aggregation for forecasting
CREATE OR REPLACE VIEW MONTHLY_SALES AS
SELECT
  DATE_TRUNC('MONTH', ORDER_DATE)    AS SALES_MONTH,
  PRODUCT_CATEGORY,
  SUM(TOTAL_AMOUNT)                  AS TOTAL_REVENUE,
  COUNT(DISTINCT ORDER_ID)           AS ORDER_COUNT,
  AVG(TOTAL_AMOUNT)                  AS AVG_ORDER_VALUE
FROM ECOMMERCE_ORDERS
WHERE SHIPPING_STATUS NOT IN ('Cancelled', 'Returned')
GROUP BY 1, 2
ORDER BY 1, 2;

-- Verify data
SELECT * FROM MONTHLY_SALES ORDER BY SALES_MONTH LIMIT 20;

-- Create forecast model for Electronics category
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST ELECTRONICS_REVENUE_FORECAST (
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'MONTHLY_SALES'),
  SERIES_COLNAME => 'PRODUCT_CATEGORY',
  TIMESTAMP_COLNAME => 'SALES_MONTH',
  TARGET_COLNAME => 'TOTAL_REVENUE',
  CONFIG_OBJECT => { 'ON_ERROR': 'SKIP' }
);

CREATE OR REPLACE VIEW MONTHLY_SALES_SIMPLE AS
SELECT
  DATE_TRUNC('MONTH', ORDER_DATE) AS SALES_MONTH,
  PRODUCT_CATEGORY,
  SUM(TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM ECOMMERCE_ORDERS
WHERE SHIPPING_STATUS NOT IN ('Cancelled', 'Returned')
GROUP BY 1, 2;

CREATE OR REPLACE SNOWFLAKE.ML.FORECAST ELECTRONICS_REVENUE_FORECAST (
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'MONTHLY_SALES_SIMPLE'),
  SERIES_COLNAME => 'PRODUCT_CATEGORY',
  TIMESTAMP_COLNAME => 'SALES_MONTH',
  TARGET_COLNAME => 'TOTAL_REVENUE',
  CONFIG_OBJECT => { 'ON_ERROR': 'SKIP' }
);

-- Generate 6-month forecast
CALL ELECTRONICS_REVENUE_FORECAST!FORECAST(FORECASTING_PERIODS => 6, CONFIG_OBJECT => {'prediction_interval': 0.95});


-- Store forecast results
CREATE OR REPLACE TABLE REVENUE_FORECAST_RESULTS AS
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SELECT * FROM REVENUE_FORECAST_RESULTS ORDER BY TS;

-- Evaluate model performance
CALL ELECTRONICS_REVENUE_FORECAST!SHOW_EVALUATION_METRICS();


-- ============================================================
-- MODULE 5B: ANOMALY DETECTION
-- ============================================================

-- Create daily order count views (split for train/detect)
CREATE OR REPLACE VIEW DAILY_ORDERS_TRAIN AS
SELECT
  ORDER_DATE,
  PRODUCT_CATEGORY,
  COUNT(DISTINCT ORDER_ID) AS DAILY_ORDER_COUNT,
  SUM(TOTAL_AMOUNT)        AS DAILY_REVENUE
FROM ECOMMERCE_ORDERS
WHERE ORDER_DATE < (SELECT MAX(ORDER_DATE) - INTERVAL '30 DAYS' FROM ECOMMERCE_ORDERS)
GROUP BY ORDER_DATE, PRODUCT_CATEGORY
ORDER BY ORDER_DATE;

CREATE OR REPLACE VIEW DAILY_ORDERS_DETECT AS
SELECT
  ORDER_DATE,
  PRODUCT_CATEGORY,
  COUNT(DISTINCT ORDER_ID) AS DAILY_ORDER_COUNT,
  SUM(TOTAL_AMOUNT)        AS DAILY_REVENUE
FROM ECOMMERCE_ORDERS
WHERE ORDER_DATE >= (SELECT MAX(ORDER_DATE) - INTERVAL '30 DAYS' FROM ECOMMERCE_ORDERS)
GROUP BY ORDER_DATE, PRODUCT_CATEGORY
ORDER BY ORDER_DATE;

-- Build anomaly detection model
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ORDER_ANOMALY_DETECTOR (
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'DAILY_ORDERS_TRAIN'),
  SERIES_COLNAME => 'PRODUCT_CATEGORY',
  TIMESTAMP_COLNAME => 'ORDER_DATE',
  TARGET_COLNAME => 'DAILY_ORDER_COUNT',
  LABEL_COLNAME => NULL,
  CONFIG_OBJECT => { 'evaluate': FALSE }
);

-- Detect anomalies
CALL ORDER_ANOMALY_DETECTOR!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'DAILY_ORDERS_DETECT'),
  SERIES_COLNAME => 'PRODUCT_CATEGORY',
  TIMESTAMP_COLNAME => 'ORDER_DATE',
  TARGET_COLNAME => 'DAILY_ORDER_COUNT',
  CONFIG_OBJECT => {'prediction_interval': 0.95}
);

-- Store and analyze anomalies
CREATE OR REPLACE TABLE DETECTED_ANOMALIES AS
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SELECT
  "SERIES" AS CATEGORY,
  TS AS ANOMALY_DATE,
  Y AS ACTUAL_ORDERS,
  FORECAST AS EXPECTED_ORDERS,
  IS_ANOMALY,
  PERCENTILE,
  DISTANCE
FROM DETECTED_ANOMALIES
WHERE IS_ANOMALY = TRUE
ORDER BY ABS(DISTANCE) DESC
LIMIT 20;




