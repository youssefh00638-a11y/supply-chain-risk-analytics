## Supply Chain Risk Analytics

### Objective 
This project analyzes supply chain operational data to identify shipment delays, supplier reliability risks, warehouse exposure, and inventory stockout threats.
The solution uses SQL-based analytical modeling with layered, reusable views and Power BI dashboards to support data-driven decision-making for procurement and inventory planning.
### Dataset
Synthetic supply chain data covering:
- Suppliers
- Products
- Warehouses
- Inventory
- Purchase Orders
- Shipments

### Key Steps
**Data Preparation & Quality Control**

-Validated row counts and enforced foreign key integrity across all core tables.

-Identified and excluded orphaned and inconsistent records.

-Standardized status fields for orders, shipments, and suppliers.

-Applied business rule checks (invalid dates, canceled orders, data anomalies).

-Exposed clean, analysis-ready datasets through SQL views while preserving raw data.

**Shipment Performance & Delay Analysis**

-Built a centralized analytical view to calculate delivery delays and late flags.

-Measured on-time vs late delivery performance.

-Analyzed delay severity using month-based delay buckets.

-Conducted time-series analysis to detect evolving delay patterns.

-Evaluated performance across suppliers, carriers, and warehouses.

**Supplier Reliability & Risk Classification**

-Aggregated shipment performance at supplier level.

-Calculated late delivery rates and average delay duration.

-Classified suppliers into Low / Medium / High risk tiers based on delivery behavior.

**Inventory & Stockout Risk Analysis**

-Identified low-stock products relative to reorder thresholds.

-Measured warehouse-level exposure.

-Mapped product dependency on suppliers.

-Linked supplier delay risk directly to inventory shortage and stockout exposure.
### Tools
- SQL Server (data validation, cleaning, transformations)
- Power BI (interactive dashboards)
- Excel (exploratory analysis)

### Key Insights
The following insights are derived from a controlled synthetic dataset designed to demonstrate analytical workflows and risk modeling logic.

-76% of shipments were delivered late, indicating a significant breakdown in delivery reliability across the supply chain.

-Out of 21 valid shipments, 11 were classified as severely late, highlighting not only frequent delays but also high delay severity.

-From 13 active suppliers, 9 were identified as high-risk, signaling systemic supplier reliability issues rather than isolated incidents.

-Warehouse 3 emerged as the most exposed location, showing the highest concentration of delayed supplier dependencies and stockout-risk products.

-Five products were identified as stocked out or below reorder level, spanning three warehouses, with direct traceability to their reorder thresholds and associated suppliers.

-Delay severity increased over recent months, suggesting a deteriorating supplier performance trend.
