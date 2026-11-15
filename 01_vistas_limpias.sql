-- =====================================================================
-- CAPA LIMPIA: 3 vistas creadas a partir de las tablas originales
-- Las tablas originales no se modifican. Reglas documentadas en la bitácora.
-- =====================================================================

-- Pedidos entregados, con fecha de entrega, en meses completos (ene 2017 - ago 2018)
-- Validación: 96.478 delivered - 8 sin fecha - 267 fuera de período = 96.203
CREATE VIEW pedidos_limpios AS
SELECT
    order_id,
    customer_id,
    order_purchase_timestamp,
    order_estimated_delivery_date,
    order_delivered_customer_date
FROM olist_orders_dataset
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND TRIM(order_delivered_customer_date) <> ''
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01';

-- Una sola reseña por pedido (la más reciente), para no duplicar pedidos en los JOIN
-- Validación: 98.673 pedidos, sin duplicados
CREATE VIEW resenas_por_pedido AS
SELECT order_id, review_id, review_score, review_creation_date
FROM (
    SELECT
        order_id, review_id, review_score, review_creation_date,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_answer_timestamp DESC
        ) AS orden
    FROM olist_order_reviews_dataset
)
WHERE orden = 1;

-- Líneas de pedido con vendedor, precio y flete como número
-- Validación: 112.650 filas (no hay líneas sin vendedor)
CREATE VIEW lineas_pedido AS
SELECT
    i.order_id,
    i.order_item_id,
    i.seller_id,
    s.seller_state,
    CAST(i.price AS REAL)         AS precio,
    CAST(i.freight_value AS REAL) AS flete
FROM olist_order_items_dataset AS i
INNER JOIN olist_sellers_dataset AS s
    ON i.seller_id = s.seller_id;
