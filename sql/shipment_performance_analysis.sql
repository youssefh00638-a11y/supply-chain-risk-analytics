USE supply_chain;
GO

-- Confirm active database
SELECT DB_NAME() AS current_database;

-----------------------------------------------------------
-----------------------------------------------------------
-- Base Analytical View
-----------------------------------------------------------
CREATE OR ALTER VIEW vw_shipment_performance_base AS
SELECT
    sh.shipment_id,
    sh.po_id,
    po.supplier_id,
    sh.warehouse_id,
    sh.carrier,
    sh.shipment_date,
    po.expected_delivery,
    sh.arrival_date,
    CAST(DATEDIFF(DAY, po.expected_delivery, sh.arrival_date) / 30.0 AS DECIMAL(10,1)) AS delay_months,

    CASE
        WHEN sh.arrival_date > po.expected_delivery THEN 1
        ELSE 0
    END AS is_late
FROM vw_shipments_clean sh
JOIN purchase_order_cn po 
    ON sh.po_id = po.po_id
WHERE sh.invalid_date_flag = 0
  AND sh.canceled_po_shipment_flag = 0;
GO



--Overall On-Time vs Late Performance
CREATE OR ALTER VIEW On_Time_vs_Late_Performance AS
SELECT
    CASE WHEN is_late = 1 THEN 'late' ELSE 'on_time' END AS delivery_status,
    COUNT(*) AS shipment_count,
    100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS percentage_of_total
FROM vw_shipment_performance_base
GROUP BY is_late;

--Delay Severity Distribution
CREATE OR ALTER VIEW Delay_Severity_Distribution AS 
SELECT 
    CASE
        WHEN delay_months <= 1.5 THEN 'minor'     
        WHEN delay_months <= 3.0 THEN 'moderate'
        ELSE 'severe'
    END AS delay_severity,
    COUNT(*) AS shipment_count
FROM vw_shipment_performance_base
WHERE is_late = 1
GROUP BY 
    CASE
        WHEN delay_months <= 1.5 THEN 'minor'
        WHEN delay_months <= 3.0 THEN 'moderate'
        ELSE 'severe'
    END;


-- Supplier Reliability & Delay Risk Profile
-- =====================================================
CREATE OR ALTER VIEW vw_supplier_delay_risk_profile AS
SELECT
    s.supplier_id,
    s.name AS supplier_name,

    COUNT(*) AS total_shipments,

    SUM(b.is_late) AS late_shipments,

    -- % of shipments that were late
    ROUND(
        100.0 * SUM(b.is_late) / NULLIF(COUNT(*), 0),
        2
    ) AS late_percentage,

    -- Average delay (months) for late shipments only
    ROUND(
        AVG(
            CASE 
                WHEN b.is_late = 1 THEN b.delay_months 
            END
        ),
        2
    ) AS avg_delay_months,
    /* -------------------------------------------------
       Risk Tier Classification
       ------------------------------------------------- */
    CASE
        WHEN SUM(b.is_late) = 0 THEN 'low'
        WHEN
            (100.0 * SUM(b.is_late) / COUNT(*)) >= 40
            AND AVG(CASE WHEN b.is_late = 1 THEN b.delay_months END) >= 3
            THEN 'high'
        WHEN
            (100.0 * SUM(b.is_late) / COUNT(*)) >= 20
            THEN 'medium'
        ELSE 'low'
    END AS delay_risk_tier

FROM vw_shipment_performance_base b
JOIN vw_suppliers_clean s
    ON s.supplier_id = b.supplier_id
GROUP BY
    s.supplier_id,
    s.name;

--Carrier Reliability
CREATE OR ALTER VIEW vw_carrier_reliability as
SELECT
    carrier,
    COUNT(*) AS total_shipments,
    SUM(is_late) AS late_shipments,
    100.0 * SUM(is_late) / COUNT(*) AS late_rate_pct,
    AVG(CASE WHEN is_late = 1 THEN delay_months END) AS avg_delay_months
FROM vw_shipment_performance_base
GROUP BY carrier



--exposed warehouses 
CREATE OR ALTER VIEW exposed_warehouses as
SELECT
    warehouse_id,
    COUNT(*) AS total_shipments,
    SUM(is_late) AS late_shipments,
    100.0 * SUM(is_late) / COUNT(*) AS late_rate_pct
FROM vw_shipment_performance_base
GROUP BY warehouse_id;

CREATE OR ALTER VIEW vw_shipment_delay_monthly AS
SELECT
    *,
    FORMAT(arrival_date, 'yyyy-MM') AS arrival_month
FROM vw_shipment_performance_base;

--delay severity over time 
create or alter view delay_severity_by_month  as 
SELECT
    arrival_month,

     CASE
        WHEN delay_months <= 1.5 THEN 'minor'     
        WHEN delay_months <= 3.0 THEN 'moderate'
        ELSE 'severe'
    END AS delay_severity,

    COUNT(*) AS shipment_count,

    ROUND(
        100.0 * COUNT(*) 
        / SUM(COUNT(*)) OVER (PARTITION BY arrival_month),
        2
    ) AS severity_share_pct

FROM vw_shipment_delay_monthly
WHERE is_late = 1          -- exclude early shipments
GROUP BY
    arrival_month,
     CASE
        WHEN delay_months <= 1.5 THEN 'minor'     
        WHEN delay_months <= 3.0 THEN 'moderate'
        ELSE 'severe'
    END 



