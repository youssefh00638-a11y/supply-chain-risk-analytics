/* ============================================================
    Phase 3: Risk & Exposure Layer
   ============================================================ */

-- 1. Corrected Inventory Base (Live Math)
CREATE OR ALTER VIEW vw_inventory_risk_base AS
SELECT
    i.inventory_id,
    i.warehouse_id,
    i.product_id,
    i.quantity_on_hand,
    p.reorder_level,
    CASE 
        WHEN i.quantity_on_hand < p.reorder_level THEN 1 
        ELSE 0 
    END AS is_below_reorder_level,
    i.last_updated
FROM inventory_cn i
JOIN vw_products_clean p ON p.product_id = i.product_id;
GO

-- 2. Supplier Risk Aggregation 
CREATE OR ALTER VIEW vw_product_supplier_risk_agg AS
SELECT
    poi.product_id,
    MAX(CASE sdr.delay_risk_tier 
            WHEN 'low' THEN 1 
            WHEN 'medium' THEN 2 
            ELSE 3 
        END) AS max_supplier_risk_score,
    CASE 
        WHEN MAX(CASE sdr.delay_risk_tier WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END) = 3 THEN 'high'
        WHEN MAX(CASE sdr.delay_risk_tier WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END) = 2 THEN 'medium'
        ELSE 'low'
    END AS max_delay_risk_tier 
FROM vw_po_items_clean poi
JOIN purchase_order_cn po ON poi.po_id = po.po_id
JOIN vw_supplier_delay_risk_profile sdr ON po.supplier_id = sdr.supplier_id
GROUP BY poi.product_id;
GO

-- 3. Warehouse Exposure 
CREATE OR ALTER VIEW vw_warehouse_supply_exposure AS
SELECT
    ir.warehouse_id,
    COUNT(DISTINCT ir.product_id) AS total_low_stock_products,
    SUM(CASE WHEN sr.max_delay_risk_tier = 'high' THEN 1 ELSE 0 END) AS high_risk_supplier_count
FROM vw_inventory_risk_base ir
JOIN vw_product_supplier_risk_agg sr ON ir.product_id = sr.product_id
WHERE ir.is_below_reorder_level = 1
GROUP BY ir.warehouse_id;
GO

-- 4. Composite Risk 
CREATE OR ALTER VIEW vw_inventory_composite_risk AS
SELECT
    ir.product_id,
    ir.warehouse_id,
    ir.is_below_reorder_level,
    ISNULL(sr.max_supplier_risk_score, 0) AS supplier_risk_score,
    (ir.is_below_reorder_level * 2) + ISNULL(sr.max_supplier_risk_score, 0) AS composite_risk_score
FROM vw_inventory_risk_base ir
LEFT JOIN vw_product_supplier_risk_agg sr ON ir.product_id = sr.product_id;
GO

--finantial risk exposure
CREATE OR ALTER VIEW vw_financial_risk_exposure AS
SELECT 
    p.product_id,
    p.name AS product_name,
    p.sku,
    SUM(p.reorder_level - ir.quantity_on_hand) AS units_below_threshold,
    ROUND(SUM((p.reorder_level - ir.quantity_on_hand) * p.unit_price_clean), 2) AS revenue_at_risk,
    sr.max_delay_risk_tier
FROM vw_inventory_risk_base ir
JOIN vw_products_clean p ON ir.product_id = p.product_id
JOIN vw_product_supplier_risk_agg sr ON ir.product_id = sr.product_id
WHERE ir.is_below_reorder_level = 1
GROUP BY p.name,p.product_id, p.sku, sr.max_delay_risk_tier;
GO


