USE supply_chain;
GO

-- Confirm active database
SELECT DB_NAME() AS current_database;

-- =========================
-- Phase 1: Row Count Checks
-- =========================
SELECT COUNT(*) AS customers_count FROM dbo.customers;
SELECT COUNT(*) AS inventory_count FROM dbo.inventory;
SELECT COUNT(*) AS products_count FROM dbo.products;
SELECT COUNT(*) AS po_items_count FROM dbo.purchase_order_items;
SELECT COUNT(*) AS po_count FROM dbo.purchase_orders;
SELECT COUNT(*) AS shipments_count FROM dbo.shipments;
SELECT COUNT(*) AS suppliers_count FROM dbo.suppliers;
SELECT COUNT(*) AS warehouses_count FROM dbo.warehouses;

-- ==================================================
-- Phase 1: Foreign Key Validation - Inventory
-- ==================================================
-- Validate inventory.warehouse_id ? warehouses.warehouse_id
-- Validate inventory.product_id ? products.product_id
SELECT 
    i.inventory_id,
    i.warehouse_id,
    i.product_id
FROM dbo.inventory i
LEFT JOIN dbo.warehouses w
    ON i.warehouse_id = w.warehouse_id
LEFT JOIN dbo.products p
    ON i.product_id = p.product_id
WHERE w.warehouse_id IS NULL
   OR p.product_id IS NULL;


-- ==================================================
-- Phase 1: Foreign Key Validation - Purchase Orders
-- ==================================================
-- Validate purchase_orders.supplier_id ? suppliers.supplier_id
SELECT 
    po.po_id,
    po.supplier_id
FROM dbo.purchase_orders po
LEFT JOIN dbo.suppliers s
    ON po.supplier_id = s.supplier_id
WHERE s.supplier_id IS NULL;

-- ==================================================
-- Phase 1: Foreign Key Validation - PO Items
-- ==================================================
-- Validate purchase_order_items.po_id ? purchase_orders.po_id
-- Validate purchase_order_items.product_id ? products.product_id
SELECT 
    poi.po_item_id,
    poi.po_id,
    poi.product_id
FROM dbo.purchase_order_items poi
LEFT JOIN dbo.purchase_orders po
    ON poi.po_id = po.po_id
LEFT JOIN dbo.products p
    ON poi.product_id = p.product_id
WHERE po.po_id IS NULL
   OR p.product_id IS NULL;

--Validate shipments.po_id ? purchase_orders.po_id , shipments.warehouse_id ? warehouses.warehouse_id
SELECT 
    s.shipment_id,
    s.po_id,
    s.warehouse_id
FROM dbo.shipments s
LEFT JOIN dbo.purchase_orders po
    ON s.po_id = po.po_id
LEFT JOIN dbo.warehouses w
    ON s.warehouse_id = w.warehouse_id
WHERE po.po_id IS NULL
   OR w.warehouse_id IS NULL;

--Shipments Linked to Canceled Orders
SELECT 
    s.shipment_id,
    s.po_id,
    po.status AS po_status
FROM dbo.shipments s
JOIN dbo.purchase_orders po
    ON s.po_id = po.po_id
WHERE po.status = 'canceled';

/* ============================================================
   Clean Purchase Orders
   ============================================================ */

CREATE OR ALTER VIEW vw_purchase_orders_clean AS
SELECT
    po.po_id,
    po.supplier_id,

    /* Standardize order status */
    CASE
        WHEN po.status IS NULL OR LTRIM(RTRIM(po.status)) = '' THEN 'unknown'
        ELSE LOWER(LTRIM(RTRIM(po.status)))
    END AS status,

    po.order_date,
    po.expected_delivery,

    /* Flag invalid delivery dates (delivery before order) */
    CASE
        WHEN po.expected_delivery < po.order_date THEN 1
        ELSE 0
    END AS invalid_delivery_date_flag,

    /* Clean total amount */
    CASE
        WHEN po.total_amount IS NULL OR po.total_amount <= 0 THEN NULL
        ELSE ROUND(po.total_amount, 2)
    END AS total_amount_clean

FROM dbo.purchase_orders po
JOIN dbo.suppliers s
    ON po.supplier_id = s.supplier_id;


/* ============================================================
   Clean Shipments
   ============================================================ */

CREATE OR ALTER VIEW vw_shipments_clean AS
SELECT
    s.shipment_id,
    s.po_id,
    s.warehouse_id,

    /* Standardize carrier name */
    CASE
        WHEN s.carrier IS NULL OR LTRIM(RTRIM(s.carrier)) = '' THEN 'unknown'
        ELSE LOWER(LTRIM(RTRIM(s.carrier)))
    END AS carrier,

    s.tracking_number,
    s.shipment_date,
    s.arrival_date,

    /* Flag invalid shipment date logic */
    CASE
        WHEN s.arrival_date < s.shipment_date THEN 1
        ELSE 0
    END AS invalid_date_flag,

    /* Flag shipments linked to canceled purchase orders */
    CASE
        WHEN LOWER(LTRIM(RTRIM(po.status))) = 'canceled' THEN 1
        ELSE 0
    END AS canceled_po_shipment_flag,

    /* Standardize shipment status */
    CASE
        WHEN s.status IS NULL OR LTRIM(RTRIM(s.status)) = '' THEN 'unknown'
        ELSE LOWER(LTRIM(RTRIM(s.status)))
    END AS status

FROM dbo.shipments s
JOIN dbo.purchase_orders po
    ON s.po_id = po.po_id
JOIN dbo.warehouses w
    ON s.warehouse_id = w.warehouse_id;

/* ============================================================
   Clean Purchase Order Items
   ============================================================ */

CREATE OR ALTER VIEW vw_po_items_clean AS
SELECT
    poi.po_item_id,
    poi.po_id,
    poi.product_id,

    poi.quantity,
    poi.unit_cost,

    /* Derived metric: line-level spend */
    ROUND(poi.quantity * poi.unit_cost, 2) AS line_total_cost

FROM dbo.purchase_order_items poi
JOIN dbo.purchase_orders po
    ON poi.po_id = po.po_id
JOIN dbo.products p
    ON poi.product_id = p.product_id
WHERE poi.quantity > 0
  AND poi.unit_cost > 0;


CREATE OR ALTER VIEW inventory_cn AS
SELECT
    i.inventory_id,
    i.warehouse_id,
    i.product_id,

    i.quantity_on_hand,
    i.last_updated,

    -- Business flag: low stock risk
    CASE
        WHEN i.quantity_on_hand <= p.reorder_level THEN 1
        ELSE 0
    END AS is_below_reorder_level

FROM dbo.inventory i
JOIN dbo.warehouses w
    ON i.warehouse_id = w.warehouse_id
JOIN dbo.products p
    ON i.product_id = p.product_id
WHERE i.quantity_on_hand >= 0;


CREATE OR ALTER VIEW vw_suppliers_clean AS
SELECT
    supplier_id,
    name,
    contact_name,
    phone,

    /* Standardize supplier status */
    CASE
        WHEN status IS NULL OR LTRIM(RTRIM(status)) = '' THEN 'unknown'
        ELSE LOWER(LTRIM(RTRIM(status)))
    END AS status,

    /* Clean email */
    CASE
        WHEN email IS NULL OR LTRIM(RTRIM(email)) = '' THEN 'unknown'
        ELSE LTRIM(RTRIM(email))
    END AS email,

    /* Clean address */
    CASE
        WHEN address IS NULL OR LTRIM(RTRIM(address)) = '' THEN 'unknown'
        ELSE LOWER(LTRIM(RTRIM(address)))
    END AS address,

    CASE
    WHEN LOWER(LTRIM(RTRIM(status))) = 'suspended' THEN 1
    ELSE 0
    END AS is_suspended,
    created_at 

FROM dbo.suppliers;


/* ============================================================
   Clean Products
   ============================================================ */

CREATE OR ALTER VIEW vw_products_clean AS
SELECT
    distinct(p.product_id),

    /* Standardize SKU */
    CASE
        WHEN p.sku IS NULL OR LTRIM(RTRIM(p.sku)) = '' THEN 'unknown'
        ELSE UPPER(LTRIM(RTRIM(p.sku)))
    END AS sku,

    /* Clean product name */
    CASE
        WHEN p.name IS NULL OR LTRIM(RTRIM(p.name)) = '' THEN 'unknown'
        ELSE LTRIM(RTRIM(p.name))
    END AS name,

    /* Clean description */
    CASE
        WHEN p.description IS NULL OR LTRIM(RTRIM(p.description)) = '' THEN 'no description'
        ELSE LTRIM(RTRIM(p.description))
    END AS description,

    /* Clean unit price */
    CASE
        WHEN p.unit_price <= 0 THEN NULL
        ELSE ROUND(p.unit_price, 2)
    END AS unit_price_clean,

    /* Clean reorder level */
    CASE
        WHEN p.reorder_level < 0 THEN NULL
        ELSE p.reorder_level
    END AS reorder_level,

    /* Business flag: missing or invalid price */
    CASE
        WHEN p.unit_price IS NULL OR p.unit_price <= 0 THEN 1
        ELSE 0
    END AS invalid_price_flag,

    p.created_at

FROM dbo.products p;
GO

