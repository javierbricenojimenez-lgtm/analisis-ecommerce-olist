-- Pregunta 2: ¿Qué vendedores concentran los atrasos y cuánta venta representan?
-- Mínimo 50 pedidos para que el % sea confiable. Segmentos: volumen (200 pedidos) x atraso (6,8 % = promedio)
SELECT
    seller_id, seller_state, total_pedidos, pedidos_atrasados, pct_atraso,
    venta_total, venta_atrasada,
    CASE
        WHEN total_pedidos >= 200 AND pct_atraso >  6.8 THEN '1. Prioridad'
        WHEN total_pedidos <  200 AND pct_atraso >  6.8 THEN '2. Vigilar'
        WHEN total_pedidos >= 200 AND pct_atraso <= 6.8 THEN '3. Clave'
        ELSE '4. Confiable'
    END AS segmento
FROM (
    SELECT
        l.seller_id,
        l.seller_state,
        COUNT(DISTINCT l.order_id) AS total_pedidos,
        COUNT(DISTINCT CASE
            WHEN DATE(p.order_delivered_customer_date) > DATE(p.order_estimated_delivery_date)
            THEN l.order_id END) AS pedidos_atrasados,
        ROUND(100.0 * COUNT(DISTINCT CASE
            WHEN DATE(p.order_delivered_customer_date) > DATE(p.order_estimated_delivery_date)
            THEN l.order_id END) / COUNT(DISTINCT l.order_id), 1) AS pct_atraso,
        ROUND(SUM(l.precio), 0) AS venta_total,
        ROUND(SUM(CASE
            WHEN DATE(p.order_delivered_customer_date) > DATE(p.order_estimated_delivery_date)
            THEN l.precio ELSE 0 END), 0) AS venta_atrasada
    FROM lineas_pedido AS l
    INNER JOIN pedidos_limpios AS p ON l.order_id = p.order_id
    GROUP BY l.seller_id, l.seller_state
    HAVING COUNT(DISTINCT l.order_id) >= 50
)
ORDER BY segmento, venta_atrasada DESC;

-- Venta total general (denominador del % de venta): R$ 13.179.778
SELECT ROUND(SUM(l.precio), 0) AS venta_total_general
FROM lineas_pedido AS l
INNER JOIN pedidos_limpios AS p ON l.order_id = p.order_id;
