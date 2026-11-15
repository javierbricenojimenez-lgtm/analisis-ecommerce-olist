-- Pregunta 3: ¿Cuánto baja la nota de la reseña cuando un pedido llega tarde?

-- 3a. A tiempo vs atrasado
SELECT
    CASE
        WHEN DATE(p.order_delivered_customer_date) > DATE(p.order_estimated_delivery_date)
        THEN 'Atrasado' ELSE 'A tiempo'
    END AS estado_entrega,
    COUNT(*) AS pedidos,
    ROUND(AVG(r.review_score), 2) AS nota_promedio,
    ROUND(100.0 * SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_nota_1,
    ROUND(100.0 * SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_nota_5
FROM pedidos_limpios AS p
INNER JOIN resenas_por_pedido AS r ON p.order_id = r.order_id
GROUP BY estado_entrega;

-- 3b. Por tramo de días de atraso
SELECT
    CASE
        WHEN dias <= 0  THEN '0. A tiempo'
        WHEN dias <= 3  THEN '1. 1-3 días'
        WHEN dias <= 7  THEN '2. 4-7 días'
        WHEN dias <= 14 THEN '3. 8-14 días'
        ELSE '4. Más de 14 días'
    END AS tramo_atraso,
    COUNT(*) AS pedidos,
    ROUND(AVG(nota), 2) AS nota_promedio,
    ROUND(100.0 * SUM(CASE WHEN nota = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_nota_1
FROM (
    SELECT
        julianday(DATE(p.order_delivered_customer_date))
          - julianday(DATE(p.order_estimated_delivery_date)) AS dias,
        r.review_score AS nota
    FROM pedidos_limpios AS p
    INNER JOIN resenas_por_pedido AS r ON p.order_id = r.order_id
)
GROUP BY tramo_atraso
ORDER BY tramo_atraso;
