-- Pregunta 1: ¿Qué % de pedidos llega tarde y cómo evoluciona mes a mes?
-- Atrasado = fecha de entrega (sin hora) posterior a la fecha estimada (sin hora)
SELECT
    strftime('%Y-%m', order_purchase_timestamp) AS mes,
    COUNT(*) AS total_pedidos,
    SUM(CASE
            WHEN DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)
            THEN 1 ELSE 0
        END) AS atrasados,
    ROUND(100.0 * SUM(CASE
            WHEN DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)
            THEN 1 ELSE 0
        END) / COUNT(*), 1) AS pct_atraso
FROM pedidos_limpios
GROUP BY mes
ORDER BY mes;
