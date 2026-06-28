# Blinkit Analytics Dashboard

A comprehensive Streamlit dashboard for Blinkit (quick-commerce) analytics, built entirely using **Cortex Code (CoCo)** on Snowflake.

## Database Schema

**Database:** `BLINKIT_DW` | **Schema:** `RAW`

### Table 1: BLINKIT_ORDERS (5,000 rows)

Core orders table capturing every customer transaction.

| Column | Type | Description |
|--------|------|-------------|
| ORDER_ID | NUMBER(12,0) | Primary key. Unique order identifier |
| CUSTOMER_ID | NUMBER(12,0) | Customer who placed the order |
| ORDER_DATE | TIMESTAMP_NTZ | Timestamp when the order was placed |
| PROMISED_DELIVERY_TIME | TIMESTAMP_NTZ | Estimated delivery time shown to customer |
| ACTUAL_DELIVERY_TIME | TIMESTAMP_NTZ | Actual delivery timestamp |
| DELIVERY_STATUS | VARCHAR(50) | `On Time`, `Delayed`, or `Cancelled` |
| ORDER_TOTAL | NUMBER(10,2) | Total order amount in INR (Rs. 50 - 5,000) |
| PAYMENT_METHOD | VARCHAR(50) | `Cash`, `UPI`, or `Card` |
| DELIVERY_PARTNER_ID | NUMBER(12,0) | Assigned delivery partner |
| STORE_ID | NUMBER(12,0) | Blinkit dark store that fulfilled the order |

### Table 2: BLINKIT_DELIVERY_PERFORMANCE (1,000 rows)

Delivery-level metrics for analyzing logistics efficiency.

| Column | Type | Description |
|--------|------|-------------|
| ORDER_ID | NUMBER(12,0) | Primary key. References BLINKIT_ORDERS |
| DELIVERY_PARTNER_ID | NUMBER(12,0) | Delivery partner assigned |
| PROMISED_TIME | TIMESTAMP_NTZ | Promised delivery timestamp |
| ACTUAL_TIME | TIMESTAMP_NTZ | Actual delivery timestamp |
| DELIVERY_TIME_MINUTES | NUMBER(6,2) | **Virtual column** — auto-computed as `DATEDIFF(MINUTE, PROMISED_TIME, ACTUAL_TIME)` |
| DISTANCE_KM | NUMBER(6,2) | Distance from store to customer (0.5 - 12 km) |
| DELIVERY_STATUS | VARCHAR(50) | `On Time`, `Delayed`, or `Cancelled` |
| REASONS_IF_DELAYED | VARCHAR(200) | Delay/cancellation reason. NULL for on-time deliveries. Values: `Heavy traffic congestion`, `Incorrect address provided`, `Order preparation delay at store`, `Delivery partner vehicle breakdown`, `Weather conditions - heavy rain`, `Customer cancelled order`, `Store out of stock`, `Payment failure` |

### Table 3: BLINKIT_ORDER_ITEMS (1,000 rows)

Line-item details for each order — products, quantities, and pricing.

| Column | Type | Description |
|--------|------|-------------|
| ORDER_ID | NUMBER(12,0) | Composite PK. References BLINKIT_ORDERS |
| PRODUCT_ID | NUMBER(12,0) | Composite PK. Product identifier (100001 - 199999) |
| QUANTITY | NUMBER(10,0) | Units ordered (1 - 6) |
| UNIT_PRICE | NUMBER(10,2) | Price per unit in INR (Rs. 10 - 1,500) |
| TOTAL_PRICE | NUMBER(12,2) | **Virtual column** — auto-computed as `QUANTITY * UNIT_PRICE` |

### Table 4: BLINKIT_MARKETING_PERFORMANCE (5,400 rows)

Campaign-level marketing metrics across channels.

| Column | Type | Description |
|--------|------|-------------|
| CAMPAIGN_ID | NUMBER(12,0) | Unique campaign identifier |
| CAMPAIGN_NAME | VARCHAR(100) | `New User Discount`, `Weekend Special`, `Festival Offer`, `Flash Sale`, `Membership Drive`, `Referral Bonus` |
| DATE | DATE | Campaign run date |
| TARGET_AUDIENCE | VARCHAR(50) | `New Users`, `Premium`, `Inactive`, `Regular` |
| CHANNEL | VARCHAR(50) | `App`, `Email`, or `SMS` |
| IMPRESSIONS | NUMBER(10,0) | Total ad impressions (500 - 10,000) |
| CLICKS | NUMBER(10,0) | Total clicks (50 - 1,000) |
| CONVERSIONS | NUMBER(10,0) | Total conversions (10 - 200) |
| SPEND | NUMBER(12,2) | Campaign spend in INR (Rs. 500 - 10,000) |
| REVENUE_GENERATED | NUMBER(12,2) | Revenue attributed to campaign (Rs. 1,000 - 15,000) |
| ROAS | NUMBER(6,2) | Return on Ad Spend (1.0 - 5.0) |

## Dashboard KPIs & Visualizations

### Top-Level KPI Cards

| KPI | Formula | Source Table |
|-----|---------|-------------|
| Total Orders | `COUNT(order_id)` | BLINKIT_ORDERS |
| Total Revenue | `SUM(order_total)` | BLINKIT_ORDERS |
| Avg Order Value | `MEAN(order_total)` | BLINKIT_ORDERS |
| On-Time Delivery % | `COUNT(status='On Time') / COUNT(*) * 100` | BLINKIT_ORDERS |
| Avg Distance (km) | `MEAN(distance_km)` | BLINKIT_DELIVERY_PERFORMANCE |
| Items Sold | `SUM(quantity)` | BLINKIT_ORDER_ITEMS |

### Orders Tab

| Chart | Type | Description |
|-------|------|-------------|
| Orders Over Time | Area chart | Daily order count trend |
| Revenue Over Time | Bar chart | Daily revenue trend |
| Orders by Delivery Status | Donut chart | On Time / Delayed / Cancelled split |
| Revenue by Payment Method | Bar chart | Cash vs UPI vs Card revenue |

### Delivery Tab

| Chart | Type | Description |
|-------|------|-------------|
| Delivery Distance Distribution | Histogram | Distribution of delivery distances (0.5 - 12 km) |
| Top Delay Reasons | Horizontal bar | Count of each delay/cancellation reason |
| Delivery Status Breakdown | Table | Status counts with percentage progress bars |

### Marketing Tab

| Chart | Type | Description |
|-------|------|-------------|
| Spend vs Revenue by Channel | Grouped bar | Side-by-side spend & revenue for App, Email, SMS |
| Average ROAS by Channel | Bar chart | Mean return on ad spend per channel |
| Campaign Conversions by Audience | Donut chart | Conversions split by New Users, Premium, Inactive, Regular |
| Impressions Over Time | Line chart | Daily impressions trend |

### Customer Insights Tab

| KPI / Chart | Type | Description |
|-------------|------|-------------|
| Unique Customers | Metric card | Count of distinct customer IDs |
| Repeat Customers | Metric card | Customers with more than 1 order |
| Repeat Rate | Metric card | `Repeat Customers / Unique Customers * 100` |
| One-Time Buyers | Metric card | Customers with exactly 1 order |
| Avg Lifetime Value | Metric card | Mean total spend per customer |
| Avg Orders/Customer | Metric card | Mean order count per customer |
| Customer Segmentation | Donut chart | Segments: 1 Order, 2-3 Orders, 4-5 Orders, 6+ Orders |
| Revenue by Customer Segment | Bar chart | Total revenue from each segment |
| New Customers Over Time | Bar chart | Monthly count of first-time buyers |
| Preferred Payment Method | Donut chart | Most-used payment method per customer |
| Top 10 Customers by Revenue | Table | Customer ID, orders, total spent, avg order value, first/last order |

### Raw Data Tab

Interactive table viewer with segmented control to switch between all 4 tables.

### Sidebar Filters

| Filter | Type | Applied To |
|--------|------|-----------|
| Order Date Range | Date picker | Orders, Delivery, Order Items, Marketing |
| Delivery Status | Multi-select (`On Time`, `Delayed`, `Cancelled`) | Orders, Delivery, Order Items |
| Payment Method | Multi-select (`Cash`, `UPI`, `Card`) | Orders, Order Items |
| Marketing Channel | Multi-select (`App`, `Email`, `SMS`) | Marketing |

All filters are cross-applied: changing the date range or delivery status automatically updates every tab and KPI.

## Setup

### 1. Snowflake Setup

Run the SQL setup script to create the database, tables, and load synthetic data:

```sql
-- Execute in Snowflake worksheet or via SnowSQL
SOURCE snowflake_setup.sql
```

Or copy-paste the contents of `snowflake_setup.sql` into a Snowflake worksheet and run.

### 2. Python Dependencies

```bash
pip install -r requirements.txt
```

### 3. Snowflake Connection

The app uses `snowflake.connector` with a named connection. Configure your connection in `~/.snowflake/connections.toml`:

```toml
[your_connection]
account = "your_account"
user = "your_user"
authenticator = "externalbrowser"  # or your auth method
```

Then set the environment variable:

```bash
export SNOWFLAKE_CONNECTION_NAME=your_connection_name
```

Or update the default in `blinkit_dashboard.py` (line 15):

```python
CONNECTION_NAME = os.getenv("SNOWFLAKE_CONNECTION_NAME", "your_connection_name")
```

### 4. Run the Dashboard

```bash
streamlit run blinkit_dashboard.py
```

Open http://localhost:8501 in your browser.

## Tech Stack

- **Streamlit 1.55+** — Dashboard UI framework
- **Snowflake** — Cloud data warehouse
- **Altair 5+** — Declarative interactive charts
- **Pandas** — Data manipulation & aggregation
- **snowflake-connector-python** — Snowflake connectivity
- **Cortex Code (CoCo)** — AI-assisted development (entire project built with CoCo)

## Project Structure

```
BLINKIT_STREAMLIT_WITH_COCO/
├── blinkit_dashboard.py    # Main Streamlit application (604 lines)
├── snowflake_setup.sql     # Database DDLs + synthetic data generation
├── requirements.txt        # Python dependencies
├── .gitignore              # Git ignore rules
└── README.md               # This file
```
