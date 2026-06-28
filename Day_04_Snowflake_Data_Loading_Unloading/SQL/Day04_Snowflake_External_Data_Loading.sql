USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE OR REPLACE DATABASE RETAILS;
USE RETAILS;
USE SCHEMA PUBLIC;


CREATE OR REPLACE TABLE DEMOGRAPHIC_RAW
(AGE_DESC	CHAR(20),
MARITAL_STATUS_CODE	CHAR(5),
INCOME_DESC	VARCHAR(40),
HOMEOWNER_DESC	VARCHAR(40),
HH_COMP_DESC	VARCHAR(50),
HOUSEHOLD_SIZE_DESC	VARCHAR(50),
KID_CATEGORY_DESC	VARCHAR(40),
household_key INT PRIMARY KEY
);

CREATE OR REPLACE TABLE CAMPAIGN_DESC_RAW
(DESCRIPTION CHAR(10),	
CAMPAIGN	INT ,
START_DAY	INT,
END_DAY INT,
PRIMARY KEY (DESCRIPTION),
UNIQUE (CAMPAIGN));


CREATE OR REPLACE TABLE CAMPAIGN_RAW
(DESCRIPTION	CHAR(10) ,
household_key	INT,
CAMPAIGN INT,
FOREIGN KEY (DESCRIPTION) references CAMPAIGN_DESC_RAW(DESCRIPTION) ,
FOREIGN KEY (CAMPAIGN) references CAMPAIGN_DESC_RAW(CAMPAIGN),
FOREIGN KEY (household_key) references demographic_RAW(household_key)
);

CREATE OR REPLACE TABLE PRODUCT_RAW
(PRODUCT_ID	INT PRIMARY KEY,
MANUFACTURER 	INT,
DEPARTMENT	VARCHAR(50),
BRAND	VARCHAR(30),
COMMODITY_DESC	VARCHAR(65),
SUB_COMMODITY_DESC VARCHAR(65)	,
CURR_SIZE_OF_PRODUCT VARCHAR(15)
);


CREATE OR REPLACE TABLE COUPON_RAW
(COUPON_UPC	INT,
PRODUCT_ID	INT,
CAMPAIGN INT,
FOREIGN KEY (PRODUCT_ID) references PRODUCT_RAW(PRODUCT_ID),
FOREIGN KEY (CAMPAIGN) references CAMPAIGN_DESC_RAW(CAMPAIGN)
);


CREATE OR REPLACE TABLE COUPON_REDEMPT_RAW
(household_key	INT,
DAY	INT,
COUPON_UPC	INT,
CAMPAIGN INT,
FOREIGN KEY (household_key) references demographic_RAW(household_key),
FOREIGN KEY (CAMPAIGN) references CAMPAIGN_DESC_RAW(CAMPAIGN)
);

CREATE OR REPLACE TABLE TRANSACTION_RAW 
(household_key	INT,
BASKET_ID	INT,
DAY	INT,
PRODUCT_ID	INT,
QUANTITY	INT,
SALES_VALUE	FLOAT,
STORE_ID	INT,
RETAIL_DISC	FLOAT,
TRANS_TIME	INT,
WEEK_NO	INT,
COUPON_DISC	INT,
COUPON_MATCH_DISC INT,
FOREIGN KEY (PRODUCT_ID) references PRODUCT_RAW(PRODUCT_ID),
FOREIGN KEY (household_key) references demographic_RAW(household_key)
);

-- ==========================================================================================================

----------------------------------------------------AWS (S3) INTEGRATION------------------------------------------------------------------------
CREATE OR REPLACE STORAGE integration s3_int
TYPE = EXTERNAL_STAGE
STORAGE_PROVIDER = S3
ENABLED = TRUE
STORAGE_AWS_ROLE_ARN ='arn:aws:iam::668461484967:role/day04_role' 
STORAGE_ALLOWED_LOCATIONS =('s3://day04bucket/');

DESC integration s3_int;

USE DATABASE RETAILS;
USE RETAILS;

CREATE OR REPLACE FILE FORMAT RETAIL_CSV
    TYPE = 'CSV'
    COMPRESSION = 'NONE'
    FIELD_DELIMITER = ','
    FIELD_OPTIONALLY_ENCLOSED_BY = 'NONE'
    SKIP_HEADER = 1;

CREATE OR REPLACE STAGE RETAIL_STAGE
URL ='s3://day04bucket'
FILE_FORMAT = RETAIL_CSV
storage_integration = s3_int;

LIST @RETAIL_STAGE;

SHOW STAGES;

-- =============================================
-- Snowpipe Creation
-- =============================================

--CREATE SNOWPIPE THAT RECOGNISES CSV THAT ARE INGESTED FROM EXTERNAL STAGE AND COPIES THE DATA INTO EXISTING TABLE

--The AUTO_INGEST=true parameter specifies to read 
--- event notifications sent from an S3 bucket to an SQS queue when new data is ready to load.


CREATE OR REPLACE PIPE RETAIL_SNOWPIPE_DEMOGRAPHIC_RAW AUTO_INGEST = TRUE AS
COPY INTO "RETAILS"."PUBLIC"."DEMOGRAPHIC_RAW"
FROM '@RETAIL_STAGE/DEMOGRAPHIC_RAW/' --s3 bucket subfolde4r name
FILE_FORMAT = RETAIL_CSV; --YOUR CSV FILE FORMAT NAME

CREATE OR REPLACE PIPE RETAIL_SNOWPIPE_CAMPAIGN_DESC_RAW AUTO_INGEST = TRUE AS
COPY INTO "RETAILS"."PUBLIC"."CAMPAIGN_DESC_RAW"
FROM '@RETAIL_STAGE/CAMPAIGN_DESC_RAW/' 
FILE_FORMAT = RETAIL_CSV;

CREATE OR REPLACE PIPE RETAIL_SNOWPIPE_CAMPAIGN_RAW AUTO_INGEST = TRUE AS
COPY INTO "RETAILS"."PUBLIC"."CAMPAIGN_RAW"
FROM '@RETAIL_STAGE/CAMPAIGN_RAW/' 
FILE_FORMAT = RETAIL_CSV;

CREATE OR REPLACE PIPE RETAIL_SNOWPIPE_PRODUCT_RAW AUTO_INGEST = TRUE AS
COPY INTO "RETAILS"."PUBLIC"."PRODUCT_RAW"
FROM '@RETAIL_STAGE/PRODUCT_RAW/' 
FILE_FORMAT = RETAIL_CSV;


CREATE OR REPLACE PIPE RETAIL_SNOWPIPE_COUPON_RAW AUTO_INGEST = TRUE AS
COPY INTO "RETAILS"."PUBLIC"."COUPON_RAW"
FROM '@RETAIL_STAGE/COUPON_RAW/' 
FILE_FORMAT = RETAIL_CSV;

CREATE OR REPLACE PIPE RETAIL_SNOWPIPE_COUPON_REDEMPT_RAW  AUTO_INGEST = TRUE AS
COPY INTO "RETAILS"."PUBLIC"."COUPON_REDEMPT_RAW"
FROM '@RETAIL_STAGE/COUPON_REDEMPT_RAW/' 
FILE_FORMAT = RETAIL_CSV;

CREATE OR REPLACE PIPE RETAIL_SNOWPIPE_TRANSACTION_RAW  AUTO_INGEST = TRUE AS
COPY INTO "RETAILS"."PUBLIC"."TRANSACTION_RAW"
FROM '@RETAIL_STAGE/TRANSACTION_RAW/' 
FILE_FORMAT = RETAIL_CSV;

SHOW PIPES;

-- THERE WILL BE NO DATA => You have to create event notification in s3 bucket

SELECT COUNT(*) FROM DEMOGRAPHIC_RAW;
SELECT COUNT(*) FROM CAMPAIGN_DESC_RAW;
SELECT COUNT(*) FROM CAMPAIGN_RAW;
SELECT COUNT(*) FROM PRODUCT_RAW;
SELECT COUNT(*) FROM COUPON_RAW;
SELECT COUNT(*) FROM COUPON_REDEMPT_RAW;
SELECT COUNT(*) FROM TRANSACTION_RAW;

----------------------------------------------------------PIPEREFRESH-----------------------------------------------------------------

ALTER PIPE RETAIL_SNOWPIPE_DEMOGRAPHIC_RAW refresh;
ALTER PIPE  RETAIL_SNOWPIPE_CAMPAIGN_DESC_RAW refresh;
ALTER PIPE  RETAIL_SNOWPIPE_CAMPAIGN_RAW refresh;
ALTER PIPE  RETAIL_SNOWPIPE_PRODUCT_RAW refresh;
ALTER PIPE  RETAIL_SNOWPIPE_COUPON_RAW refresh;
ALTER PIPE  RETAIL_SNOWPIPE_COUPON_REDEMPT_RAW refresh;
ALTER PIPE  RETAIL_SNOWPIPE_TRANSACTION_RAW refresh;



SELECT * FROM DEMOGRAPHIC_RAW;
SELECT * FROM CAMPAIGN_DESC_RAW;
SELECT * FROM CAMPAIGN_RAW;
SELECT * FROM PRODUCT_RAW;
SELECT * FROM COUPON_RAW;
SELECT * FROM COUPON_REDEMPT_RAW;
SELECT * FROM TRANSACTION_RAW;

-- If you delete data files by mistake from the folder in s3 bucket then it will not delete from the snowflake
-- Your data is safe. That is the beauty of storage integration.

-- ==============================================================================
-- Semi-Structured Data
-- ==============================================================================

--IOT_V2_TABLE CREATION

CREATE OR REPLACE DATABASE IOT_DB;
CREATE OR REPLACE SCHEMA IOT_SCHEMA;

create or replace file format iot_csv
type='csv'
compression='none'
field_delimiter=','
field_optionally_enclosed_by='\042' -- double quotes ASCII value
skip_header=1;


create or replace TABLE IOT_DB.IOT_SCHEMA.LOAD_IOTV2_EUEXPERIENCE00320055 
(
	ATOMICCONSENTS VARCHAR(16777216),
	DATA VARIANT,
	ORIGINREGION VARCHAR(16777216),
	REQUESTID VARCHAR(16777216),
	SERIALNUMBER VARCHAR(16777216),
	SOURCE_FILE_NAME VARCHAR(16777216),
	EVENT_LOCAL_TIMESTAMP VARCHAR(16777216)
);

create or replace TABLE LOAD_IOTV2_EUEXPERIENCE00320055_COPY as select * from LOAD_IOTV2_EUEXPERIENCE00320055;

create or replace TABLE IOT_DB.IOT_SCHEMA.LOAD_IOTV2_JPEXPERIENCE00320055 (
	ATOMICCONSENTS VARCHAR(16777216),
	DATA VARIANT,
	ORIGINREGION VARCHAR(16777216),
	REQUESTID VARCHAR(16777216),
	SERIALNUMBER VARCHAR(16777216),
	SOURCE_FILE_NAME VARCHAR(16777216),
	EVENT_LOCAL_TIMESTAMP VARCHAR(16777216)
);

create or replace TABLE LOAD_IOTV2_JPEXPERIENCE00320055_COPY as select * from LOAD_IOTV2_JPEXPERIENCE00320055;
select * from IOT_DB.IOT_SCHEMA.LOAD_IOTV2_EUEXPERIENCE00320055_COPY;

--endMCUtemperature
--startMCUtemperature

create or replace TABLE IOT_DB.IOT_SCHEMA.LOAD_IOTV2_NZEXPERIENCE002F0052 (
	ATOMICCONSENTS VARCHAR(16777216),
	DATA VARIANT,
	ORIGINREGION VARCHAR(16777216),
	REQUESTID VARCHAR(16777216),
	SERIALNUMBER VARCHAR(16777216),
	SOURCE_FILE_NAME VARCHAR(16777216),
	EVENT_LOCAL_TIMESTAMP VARCHAR(16777216)
);

create or replace TABLE LOAD_IOTV2_NZEXPERIENCE002F0052_COPY as select * from LOAD_IOTV2_NZEXPERIENCE002F0052;

----------------------------------------------------AWS (S3) INTEGRATION------------------------------------------------------------------------
create or replace file format iot_csv
type='csv'
compression='none'
field_delimiter=','
field_optionally_enclosed_by='\042' -- double quotes ASCII value
skip_header=1;

CREATE OR REPLACE STORAGE integration iot_si
TYPE = EXTERNAL_STAGE
STORAGE_PROVIDER = S3
ENABLED = TRUE
STORAGE_AWS_ROLE_ARN ='arn:aws:iam::668461484967:role/ajiotv2_role' 
STORAGE_ALLOWED_LOCATIONS =('s3://ajiotv2/');

DESC integration iot_si;

CREATE OR REPLACE STAGE iot_stage
URL ='s3://ajiotv2'
file_format = iot_csv
storage_integration = iot_si;

SHOW STAGES;

LIST @iot_stage;

-------------------------------------------------iotv2_snowpipe--------------------------------------------------------------------

CREATE OR REPLACE PIPE iotv2_snowpipe_EUEXPERIENCE00320055 AUTO_INGEST = TRUE AS
COPY INTO IOT_DB.IOT_SCHEMA.LOAD_IOTV2_EUEXPERIENCE00320055 --yourdatabase -- your schema ---your table
FROM '@iot_stage/iotv2_prd_euexperience00320055/' --s3 bucket subfolde4r name
FILE_FORMAT = iot_csv; --YOUR CSV FILE FORMAT NAME

CREATE OR REPLACE PIPE iotv2_snowpipe_JPEXPERIENCE00320055 AUTO_INGEST = TRUE AS
COPY INTO IOT_DB.IOT_SCHEMA.LOAD_IOTV2_JPEXPERIENCE00320055
FROM '@iot_stage/iotv2_prd_jpexperience00320055/' 
FILE_FORMAT = iot_csv;

CREATE OR REPLACE PIPE iotv2_snowpipe_NZEXPERIENCE002F0052 AUTO_INGEST = TRUE AS
COPY INTO IOT_DB.IOT_SCHEMA.LOAD_IOTV2_NZEXPERIENCE002F0052
FROM '@iot_stage/iotv2_prd_nzexperience002f0052/' 
FILE_FORMAT = iot_csv;


----------------------------------------------------------PIPEREFRESH-----------------------------------------------------------------

ALTER PIPE iotv2_snowpipe_EUEXPERIENCE00320055 refresh;
ALTER PIPE  iotv2_snowpipe_JPEXPERIENCE00320055 refresh;
ALTER PIPE  iotv2_snowpipe_NZEXPERIENCE002F0052 refresh;

SELECT COUNT(*) FROM LOAD_IOTV2_EUEXPERIENCE00320055;
SELECT COUNT(*) FROM LOAD_IOTV2_JPEXPERIENCE00320055;
SELECT COUNT(*) FROM LOAD_IOTV2_NZEXPERIENCE002F0052;

SELECT * FROM LOAD_IOTV2_EUEXPERIENCE00320055;
SELECT * FROM LOAD_IOTV2_JPEXPERIENCE00320055;
SELECT * FROM LOAD_IOTV2_NZEXPERIENCE002F0052;

---------------------------------------------------------------------------------------------

create or replace view IOT_DB.IOT_SCHEMA.V_LOAD_IOTV2_JSON_IQOS4_HOLDER_EXP
(
	ATOMICCONSENTS,
	RECORDINDEX,
	RECORDFORMATVERSION,
	RECORDSIZE,
	STARTTIME,
	EXPCREDIT,
	STARTBATTERYGAUGELEVEL,
	ENDBATTERYGAUGELEVEL,
	CONTROLSTARTBATTERYVOLTAGE,
	CONTROLSTARTTEMPERATURE2,
	CONTROLINTERNALRESISTORINDICATOR,
	CONTROLENDBATTERYVOLTAGE,
	CONTROLENDTEMPERATURE2,
	CONTROLSTOPREASON,
	STARTREASON,
	SKU,
	STARTTEMP1,
	STARTTEMP2,
    START_MCU_TEMPERATURE,
    END_MCU_TEMPERATURE,
	STARTDCDCVOLTAGE,
	ENDTEMP1,
	ENDTEMP2,
	ENDDCDCVOLTAGE,
	DCDCVOLTAGEVARIATION,
	INTERNALRESISTORINDICATOR,
	STARTCONDUCTANCE,
	FIRSTVALLEYCONDUCTANCE,
	FIRSTDELTASCURVECONDUCTANCE,
	LASTDELTASCURVECONDUCTANCE,
	PREHEATSLOPETIME,
	OUTOFRANGEREGULATION,
	DRIFTCOMPENSATIONERROR,
	HEATINGDURATION,
	PAUSEDURATION,
	PAUSETIMESTAMP,
	PAUSEENERGY,
	HEATINGENERGY,
	ENGINESTOPREASON,
	HEATINGPROFILE,
	STARTBATTERYVOLTAGE,
	ENDBATTERYVOLTAGE,
	BATTERYVOLTAGEVARIATION,
	LASTVALLEYCONDUCTANCE,
	FIRSTHILLCONDUCTANCE,
	CALIBRATIONDURATION,
	HOTALARMTREATED,
	MAXIMUMDELTASVARIATION,
	VALIDSCURVEDETECTED,
	COOLINGSEQUENCEFAILURE,
	CALIBRATIONPULSEFAILURE,
	APPLICATIONVERSION,
	PUFFCOUNT,
	PUFFS,
	INDEX,
	PUFFCOUNTBEFOREPAUSE,
	PUFFCOUNTAFTERPAUSE,
	PUFFVOLUMEAFTER14PUFFS,
	TOTALPUFFVOLUME,
    PUFFDURATION,
	PAUSEPROFILE,
	ENERGYTOFIRSTVALLEY,
	STICKEXTRACTIONDURATION,
	ENGINEFLAGS,
	CONTROLFLAGS,
	ORIGINREGION,
	REQUESTID,
	SERIALNUMBER,
	SOURCE_FILE_NAME,
	EVENT_LOCAL_TIMESTAMP
) as
SELECT 
EXP3.ATOMICCONSENTS,
parse_json(DATA):recordIndex,
parse_json(DATA):recordFormatVersion,
parse_json(DATA):recordSize,
parse_json(DATA):startTime,
parse_json(DATA):expCredit,
parse_json(DATA):startBatteryGaugeLevel,
parse_json(DATA):endBatteryGaugeLevel,
parse_json(DATA):controlStartBatteryVoltage,
parse_json(DATA):controlStartTemperature2,
parse_json(DATA):controlInternalResistorIndicator,
parse_json(DATA):controlEndBatteryVoltage,
parse_json(DATA):controlEndTemperature2,
parse_json(DATA):controlStopReason,
parse_json(DATA):startReason,
parse_json(DATA):SKU,
parse_json(DATA):startTemp1,
parse_json(DATA):startTemp2,
parse_json(DATA):startMCUtemperature,
parse_json(DATA):endMCUtemperature,
parse_json(DATA):startDCDCVoltage,
parse_json(DATA):endTemp1,
parse_json(DATA):endTemp2,
parse_json(DATA):endDCDCVoltage,
parse_json(DATA):DCDCVoltageVariation,
parse_json(DATA):internalResistorIndicator,
parse_json(DATA):startConductance,
parse_json(DATA):firstValleyConductance,
parse_json(DATA):firstDeltaScurveConductance,
parse_json(DATA):lastDeltaScurveConductance,
parse_json(DATA):preheatSlopeTime,
parse_json(DATA):outOfRangeRegulation,
parse_json(DATA):driftCompensationError,
parse_json(DATA):heatingDuration,
parse_json(DATA):pauseDuration,
parse_json(DATA):pauseTimeStamp,
parse_json(DATA):pauseEnergy,
parse_json(DATA):heatingEnergy,
parse_json(DATA):engineStopReason,
parse_json(DATA):heatingProfile,
parse_json(DATA):startBatteryVoltage,
parse_json(DATA):endBatteryVoltage,
parse_json(DATA):batteryVoltageVariation,
parse_json(DATA):lastValleyConductance,
parse_json(DATA):firstHillConductance,
parse_json(DATA):calibrationDuration,
parse_json(DATA):hotAlarmTreated,
parse_json(DATA):maximumDeltaSvariation,
parse_json(DATA):validScurveDetected,
parse_json(DATA):coolingSequenceFailure,
parse_json(DATA):calibrationPulseFailure,
parse_json(DATA):application version,
parse_json(DATA):puffCount,
parse_json(DATA):puffs,
parse_json(DATA):index,
NULL,
NULL,
NULL,
NULL,
parse_json(DATA):puffDuration,
NULL,
NULL,
NULL,
NULL,
NULL,
EXP3.ORIGINREGION,
REPLACE(EXP3.REQUESTID,'__USAGE_DATA',''),
EXP3.SERIALNUMBER,
EXP3.SOURCE_FILE_NAME,
EXP3.EVENT_LOCAL_TIMESTAMP
FROM (SELECT ATOMICCONSENTS,DATA,ORIGINREGION,REQUESTID,SERIALNUMBER,SOURCE_FILE_NAME,EVENT_LOCAL_TIMESTAMP
FROM IOT_DB.IOT_SCHEMA.LOAD_IOTV2_EUEXPERIENCE00320055
UNION
SELECT ATOMICCONSENTS,DATA,ORIGINREGION,REQUESTID,SERIALNUMBER,SOURCE_FILE_NAME,EVENT_LOCAL_TIMESTAMP
FROM IOT_DB.IOT_SCHEMA.LOAD_IOTV2_JPEXPERIENCE00320055
UNION
SELECT ATOMICCONSENTS,DATA,ORIGINREGION,REQUESTID,SERIALNUMBER,SOURCE_FILE_NAME,EVENT_LOCAL_TIMESTAMP
FROM IOT_DB.IOT_SCHEMA.LOAD_IOTV2_NZEXPERIENCE002F0052
) EXP3;

SELECT * FROM IOT_DB.IOT_SCHEMA.V_LOAD_IOTV2_JSON_IQOS4_HOLDER_EXP;

SELECT * FROM IOT_DB.IOT_SCHEMA.V_LOAD_IOTV2_JSON_IQOS4_HOLDER_EXP
WHERE START_MCU_TEMPERATURE IS NOT NULL AND END_MCU_TEMPERATURE IS NOT NULL;

SELECT * FROM IOT_DB.IOT_SCHEMA.V_LOAD_IOTV2_JSON_IQOS4_HOLDER_EXP
WHERE START_MCU_TEMPERATURE <> 'null'
AND END_MCU_TEMPERATURE <> 'null';
--PUFFDURATION <> 'null'

SELECT  data:startMCUtemperature::VARCHAR as "Starting MCU Temperature Value",
data:endMCUtemperature::VARCHAR as "Ending MCU Temperature Value"
FROM LOAD_IOTV2_EUEXPERIENCE00320055
WHERE data:startMCUtemperature <> 'null'
AND data:startMCUtemperature <> 'null';

-- SELECT 
-- data:puffs::VARCHAR as "Puffs"
--data:endMCUtemperature::VARCHAR as "Ending MCU Temperature Value"
-- FROM LOAD_IOTV2_EUEXPERIENCE00320055

-- NULL Values
-- Snowflake supports two types of NULL values in semi-structured data:

-- SQL NULL: SQL NULL means the same thing for semi-structured data types as it means for structured data types: the value is missing or unknown.

-- JSON null (sometimes called “VARIANT NULL”): 
-- In a VARIANT column, JSON null values are stored as a string containing the word “null” to distinguish them from SQL NULL values.

-- The following example contrasts SQL NULL and JSON null:;

-- select 
    -- parse_json(NULL) AS "SQL NULL", 
    -- parse_json('null') AS "JSON NULL", 
    -- parse_json('[ null ]') AS "JSON NULL",
    -- parse_json('{ "a": null }'):a AS "JSON NULL",
    -- parse_json('{ "a": null }'):b AS "ABSENT VALUE";

-- To convert a VARIANT "null" value to SQL NULL, cast it as a string. For example:;

-- select 
--     parse_json('{ "a": null }'):a,
--     to_char(parse_json('{ "a": null }'):a);

------------------------------------------- READING SEMI-STRUCTURED-DATA ------------------------------------------------

CREATE OR REPLACE table parsing_json_data
( 
  src variant
)
AS
SELECT PARSE_JSON(column1) AS src
FROM VALUES
('{ 
    "date" : "2017-04-28", 
    "dealership" : "Valley View Auto Sales",
    "salesperson" : {
      "id": "55",
      "name": "Frank Beasley"
    },
    "customer" : [
      {"name": "Joyce Ridgely", "phone": "16504378889", "address": "San Francisco, CA"}
    ],
    "vehicle" : [
      {"make": "Honda", "model": "Civic", "year": "2017", "price": "20275", "extras":["ext warranty", "paint protection"]}
    ]
}'),
('{ 
    "date" : "2017-04-28", 
    "dealership" : "Tindel Toyota",
    "salesperson" : {
      "id": "274",
      "name": "Greg Northrup"
    },
    "customer" : [
      {"name": "Bradley Greenbloom", "phone": "12127593751", "address": "New York, NY"}
    ],
    "vehicle" : [
      {"make": "Toyota", "model": "Camry", "year": "2017", "price": "23500", "extras":["ext warranty", "rust proofing", "fabric protection"]}  
    ]
}') v;


SELECT * FROM parsing_json_data;

---- Traversing Semi-structured Data
--- Insert a colon : between the VARIANT column name and any first-level element: <column>:<level1_element>.


/* Note
In the following examples, the query output is enclosed in double quotes because the query output is VARIANT, not VARCHAR. (The VARIANT values are not strings; the VARIANT values contain strings.) Operators : and subsequent . and [] always return VARIANT values containing strings. */



SELECT src:dealership
FROM parsing_json_data
ORDER BY 1;


-- There are two ways to access elements in a JSON object:
-- Dot Notation (in this topic).
-- Bracket Notation (in this topic).

-- Important

-- Regardless of which notation you use, the column name is case-insensitive but element names are case-sensitive. 
-- For example, in the following list, the first two paths are equivalent, but the third is not:

-- src:salesperson.name
-- SRC:salesperson.name
-- SRC:Salesperson.Name


-- Dot Notation
-- Use dot notation to traverse a path in a JSON object: <column>:<level1_element>.<level2_element>.<level3_element>. 
-- Optionally enclose element names in double quotes: <column>:"<level1_element>"."<level2_element>"."<level3_element>".;

--Get the names of all salespeople who sold cars:;

SELECT src:salesperson.name
FROM parsing_json_data
ORDER BY 1;

-- Bracket Notation
-- Alternatively, use bracket notation to traverse the path in an object: <column>['<level1_element>']['<level2_element>']. Enclose element names in single quotes. Values are retrieved as strings.

-- Get the names of all salespeople who sold cars:;

SELECT src['salesperson']['name']
FROM parsing_json_data
ORDER BY 1;



-- Retrieving a Single Instance of a Repeating Element
-- Retrieve a specific numbered instance of a child element in a repeating array by adding a numbered predicate (starting from 0) to the array reference.

-- Note that to retrieve all instances of a child element in a repeating array, it is necessary to flatten the array. 

-- Get the vehicle details for each sale:;

SELECT src:customer[0].name, src:vehicle[0]
 FROM parsing_json_data
ORDER BY 1;

-- Get the price of each car sold:;
SELECT src:customer[0].name, src:vehicle[0].price
FROM parsing_json_data
ORDER BY 1;


-- Explicitly Casting Values
-- When you extract values from a VARIANT, you can explicitly cast the values to the desired data type. 
-- For example, you can extract the prices as numeric values and perform calculations on them:;

SELECT src:vehicle[0].price::NUMBER * 0.10 AS tax
FROM parsing_json_data
ORDER BY tax;

-- By default, when VARCHARs, DATEs, TIMEs, and TIMESTAMPs are retrieved from a VARIANT column, the values are surrounded by double quotes. 
-- You can eliminate the double quotes by explicitly casting the values. For example:;

SELECT src:dealership, src:dealership::VARCHAR
FROM parsing_json_data
ORDER BY 2;


-- Using the FLATTEN Function to Parse Arrays
-- Parse an array using the FLATTEN function. FLATTEN is a table function that produces a lateral view of a VARIANT, OBJECT, or ARRAY column. The function returns a row for each object, and the LATERAL modifier joins the data with any information outside of the object.

-- Get the names and addresses of all customers. Cast the VARIANT output to string values:;

SELECT
  value:name::string as "Customer Name",
  value:address::string as "Address"
  FROM parsing_json_data, LATERAL FLATTEN(INPUT => SRC:customer);

-- Using the FLATTEN Function to Parse Nested Arrays¶
-- The extras array is nested within the vehicle array in the sample data:

-- "vehicle" : [
--      {"make": "Honda", "model": "Civic", "year": "2017", "price": "20275", "extras":["ext warranty", "paint protection"]}
--    ]
-- Add a second FLATTEN clause to flatten the extras array within the flattened vehicle array and retrieve the “extras” purchased for each car sold:;

SELECT
  vm.value:make::string as make,
  vm.value:model::string as model,
  ve.value::string as "Extras Purchased"
  FROM
    parsing_json_data
    , LATERAL FLATTEN(INPUT => SRC:vehicle) vm
    , LATERAL FLATTEN(INPUT => vm.value:extras) ve
  ORDER BY make, model, "Extras Purchased";

-------------------------------------------------------------------------PARQUET FILES-----------------------------------------------------
  
-- Parquet files have embedded schema, so Snowflake can detect columns automatically.
-- You still need to map to your target table.
 
-- Create target table
CREATE OR REPLACE TABLE nyc_taxi_trips (
    vendor_id            INTEGER,
    tpep_pickup_datetime TIMESTAMP_NTZ,
    tpep_dropoff_datetime TIMESTAMP_NTZ,
    passenger_count      INTEGER,
    trip_distance        FLOAT,
    ratecode_id          INTEGER,
    store_and_fwd_flag   VARCHAR(1),
    pu_location_id       INTEGER,
    do_location_id       INTEGER,
    payment_type         INTEGER,
    fare_amount          FLOAT,
    extra                FLOAT,
    mta_tax              FLOAT,
    tip_amount           FLOAT,
    tolls_amount         FLOAT,
    improvement_surcharge FLOAT,
    total_amount         FLOAT
);
 
-- Create Parquet file format
CREATE OR REPLACE FILE FORMAT parquet_format
    TYPE = 'PARQUET'
    COMPRESSION = 'SNAPPY';
 
-- Load Parquet — use $1 to reference the Parquet columns by position
COPY INTO nyc_taxi_trips
    FROM (
        SELECT
            $1:VendorID::INTEGER,
            $1:tpep_pickup_datetime::TIMESTAMP_NTZ,
            $1:tpep_dropoff_datetime::TIMESTAMP_NTZ,
            $1:passenger_count::INTEGER,
            $1:trip_distance::FLOAT,
            $1:RatecodeID::INTEGER,
            $1:store_and_fwd_flag::VARCHAR(1),
            $1:PULocationID::INTEGER,
            $1:DOLocationID::INTEGER,
            $1:payment_type::INTEGER,
            $1:fare_amount::FLOAT,
            $1:extra::FLOAT,
            $1:mta_tax::FLOAT,
            $1:tip_amount::FLOAT,
            $1:tolls_amount::FLOAT,
            $1:improvement_surcharge::FLOAT,
            $1:total_amount::FLOAT
        FROM @iot_stage/taxi_parquet/
    )
    FILE_FORMAT = (FORMAT_NAME = 'parquet_format')
    ON_ERROR = 'CONTINUE';
 
-- Validate 
-- It will show 0 as there is no data loaded 
-- Just to show the demo 

SELECT COUNT(*) FROM nyc_taxi_trips;
SELECT AVG(total_amount), MAX(trip_distance), MIN(fare_amount)
FROM nyc_taxi_trips;


-- ============================================
-- COPY_HISTORY: See all recent loads
-- ============================================
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'parsing_json_data',
    START_TIME => DATEADD('day', -7, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;
 
-- Key columns in output:
-- FILE_NAME       : which S3 file
-- LAST_LOAD_TIME  : when it was loaded
-- STATUS          : LOADED, LOAD_FAILED, PARTIALLY_LOADED
-- ROW_COUNT       : rows successfully loaded
-- ERROR_COUNT     : number of errors
-- FIRST_ERROR     : description of first error
 
-- ============================================
-- LOAD_HISTORY: Alternative view via table
-- ============================================
SELECT *
FROM INFORMATION_SCHEMA.LOAD_HISTORY
WHERE TABLE_NAME = 'parsing_json_data'
  AND LAST_LOAD_TIME > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY LAST_LOAD_TIME DESC;
 
-- ============================================
-- QUERY_HISTORY: See past COPY commands
-- ============================================
SELECT
    QUERY_ID,
    QUERY_TEXT,
    EXECUTION_STATUS,
    ROWS_PRODUCED,
    TOTAL_ELAPSED_TIME / 1000 AS duration_seconds,
    START_TIME
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TYPE = 'COPY'
ORDER BY START_TIME DESC
LIMIT 20;

