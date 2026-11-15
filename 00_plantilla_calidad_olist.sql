-- =====================================================================
-- PLANTILLA DE CALIDAD DE DATOS · PROYECTO OLIST
-- Partes 0, 1 y 2: sirven para CUALQUIER base SQLite sin cambiar nada.
-- Partes 3 y 4: ya adaptadas a las tablas de Olist.
-- Para ejecutar una sola consulta: selecciónala y presiona Ctrl + Enter.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PARTE 0. ¿SE IMPORTÓ TODO? Conteo de filas de todas las tablas (2 pasos)
--   Paso 1: ejecuta esta consulta -> devuelve UNA celda con otra consulta.
--   Paso 2: copia la celda, pégala en una pestaña nueva (Ctrl + T) y ejecútala.
-- ---------------------------------------------------------------------
SELECT group_concat(
  'SELECT ''' || name || ''' AS tabla, COUNT(*) AS filas FROM "' || name || '"',
  ' UNION ALL ') || ';' AS consulta
FROM sqlite_master
WHERE type = 'table' AND name NOT LIKE 'sqlite_%';


-- ---------------------------------------------------------------------
-- PARTE 1. PERFIL DE TODAS LAS COLUMNAS DE TODAS LAS TABLAS (2 pasos)
--   Igual que la parte 0: ejecutar, copiar la celda, pegar y ejecutar.
--   Con 1 millón de filas en geolocation puede tardar 1-2 minutos.
--
--   Cómo leerlo:
--     vacios > 0                      -> faltan datos
--     distintos < filas (en la llave) -> hay duplicados
--     con_espacios > 0                -> aplicar TRIM
--     largo_min muy distinto de max   -> formatos distintos
--     distintos bajo (< 20)           -> revisar valores con la PARTE 3
--     valor_min / valor_max           -> orden de TEXTO, no numérico
-- ---------------------------------------------------------------------
SELECT group_concat(
  'SELECT ''' || m.name || ''' AS tabla, ''' || p.name || ''' AS columna, COUNT(*) AS filas, '
  || 'SUM(CASE WHEN TRIM(COALESCE("' || p.name || '",''''))='''' THEN 1 ELSE 0 END) AS vacios, '
  || 'COUNT(DISTINCT "' || p.name || '") AS distintos, '
  || 'SUM(CASE WHEN "' || p.name || '"<>TRIM("' || p.name || '") THEN 1 ELSE 0 END) AS con_espacios, '
  || 'MIN(LENGTH("' || p.name || '")) AS largo_min, MAX(LENGTH("' || p.name || '")) AS largo_max, '
  || 'MIN("' || p.name || '") AS valor_min, MAX("' || p.name || '") AS valor_max '
  || 'FROM "' || m.name || '"',
  ' UNION ALL ') || ';' AS consulta
FROM sqlite_master AS m
JOIN pragma_table_info(m.name) AS p
WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%';


-- ---------------------------------------------------------------------
-- PARTE 2. ESTRUCTURA: QUÉ COLUMNAS TIENE CADA TABLA
-- ---------------------------------------------------------------------
SELECT m.name AS tabla,
       COUNT(*) AS cantidad_columnas,
       group_concat(p.name, ' | ') AS columnas
FROM sqlite_master AS m
JOIN pragma_table_info(m.name) AS p
WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%'
GROUP BY m.name;


-- ---------------------------------------------------------------------
-- PARTE 3. VALORES DE COLUMNAS CON POCAS CATEGORÍAS
-- ---------------------------------------------------------------------

-- 3a. Estados de los pedidos
SELECT order_status AS valor, COUNT(*) AS filas
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY filas DESC;

-- 3b. Notas de las reseñas (deberían ser solo 1 a 5)
SELECT review_score AS valor, COUNT(*) AS filas
FROM olist_order_reviews_dataset
GROUP BY review_score
ORDER BY valor;

-- 3c. Tipos de pago
SELECT payment_type AS valor, COUNT(*) AS filas
FROM olist_order_payments_dataset
GROUP BY payment_type
ORDER BY filas DESC;


-- ---------------------------------------------------------------------
-- PARTE 4. DUPLICADOS EN LA LLAVE DE CADA TABLA
--   La llave es lo que identifica una fila. Si alguna consulta devuelve
--   filas, esa tabla tiene registros repetidos en su llave.
-- ---------------------------------------------------------------------

-- 4a. Pedidos: llave = order_id
SELECT order_id, COUNT(*) AS veces
FROM olist_orders_dataset
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 4b. Clientes: llave = customer_id
SELECT customer_id, COUNT(*) AS veces
FROM olist_customers_dataset
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 4c. Líneas de pedido: llave = order_id + order_item_id
SELECT order_id, order_item_id, COUNT(*) AS veces
FROM olist_order_items_dataset
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- 4d. Pagos: llave = order_id + payment_sequential
SELECT order_id, payment_sequential, COUNT(*) AS veces
FROM olist_order_payments_dataset
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;

-- 4e. Reseñas: llave = review_id
SELECT review_id, COUNT(*) AS veces
FROM olist_order_reviews_dataset
GROUP BY review_id
HAVING COUNT(*) > 1;

-- 4f. Productos: llave = product_id
SELECT product_id, COUNT(*) AS veces
FROM olist_products_dataset
GROUP BY product_id
HAVING COUNT(*) > 1;

-- 4g. Vendedores: llave = seller_id
SELECT seller_id, COUNT(*) AS veces
FROM olist_sellers_dataset
GROUP BY seller_id
HAVING COUNT(*) > 1;


-- =====================================================================
-- PARTE 5. CRUCE ENTRE TABLAS: ¿HAY REGISTROS HUÉRFANOS?
--   Una sola consulta. Cada fila es una revisión y cuántos registros fallan.
--   0 = todo calza. Más de 0 = registros que no tienen pareja en la otra tabla.
-- =====================================================================
SELECT 'Pedidos sin cliente' AS revision, COUNT(*) AS registros
FROM olist_orders_dataset o
LEFT JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'Pedidos sin líneas de producto', COUNT(*)
FROM olist_orders_dataset o
LEFT JOIN (SELECT DISTINCT order_id FROM olist_order_items_dataset) i ON o.order_id = i.order_id
WHERE i.order_id IS NULL
UNION ALL
SELECT 'Pedidos sin pago', COUNT(*)
FROM olist_orders_dataset o
LEFT JOIN (SELECT DISTINCT order_id FROM olist_order_payments_dataset) p ON o.order_id = p.order_id
WHERE p.order_id IS NULL
UNION ALL
SELECT 'Pedidos sin reseña', COUNT(*)
FROM olist_orders_dataset o
LEFT JOIN (SELECT DISTINCT order_id FROM olist_order_reviews_dataset) r ON o.order_id = r.order_id
WHERE r.order_id IS NULL
UNION ALL
SELECT 'Líneas sin pedido', COUNT(*)
FROM olist_order_items_dataset i
LEFT JOIN olist_orders_dataset o ON i.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'Líneas sin vendedor', COUNT(*)
FROM olist_order_items_dataset i
LEFT JOIN olist_sellers_dataset s ON i.seller_id = s.seller_id
WHERE s.seller_id IS NULL
UNION ALL
SELECT 'Líneas sin producto', COUNT(*)
FROM olist_order_items_dataset i
LEFT JOIN olist_products_dataset p ON i.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'Reseñas de pedidos que no existen', COUNT(*)
FROM olist_order_reviews_dataset r
LEFT JOIN olist_orders_dataset o ON r.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'Categorías sin traducción', COUNT(DISTINCT p.product_category_name)
FROM olist_products_dataset p
LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE t.product_category_name IS NULL
  AND TRIM(COALESCE(p.product_category_name, '')) <> '';


-- =====================================================================
-- PARTE 6. FECHAS: PERÍODO CUBIERTO Y LÓGICA
-- =====================================================================

-- 6a. Pedidos por mes de compra (¿qué período cubre? ¿hay meses incompletos?)
SELECT substr(order_purchase_timestamp, 1, 7) AS mes, COUNT(*) AS pedidos
FROM olist_orders_dataset
GROUP BY mes
ORDER BY mes;

-- 6b. Pedidos por estado: ¿cuántos tienen fecha de entrega al cliente?
SELECT order_status,
       COUNT(*) AS pedidos,
       SUM(CASE WHEN TRIM(COALESCE(order_delivered_customer_date, '')) = '' THEN 1 ELSE 0 END) AS sin_fecha_entrega
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY pedidos DESC;

-- 6c. Fechas que no tienen lógica (cada fila debería dar 0)
--     Las fechas vienen como 'AAAA-MM-DD HH:MM:SS', así que se pueden comparar como texto.
SELECT 'Entregado al cliente antes de la compra' AS revision, COUNT(*) AS pedidos
FROM olist_orders_dataset
WHERE TRIM(COALESCE(order_delivered_customer_date, '')) <> ''
  AND order_delivered_customer_date < order_purchase_timestamp
UNION ALL
SELECT 'Aprobado antes de la compra', COUNT(*)
FROM olist_orders_dataset
WHERE TRIM(COALESCE(order_approved_at, '')) <> ''
  AND order_approved_at < order_purchase_timestamp
UNION ALL
SELECT 'Entregado al transportista antes de aprobar', COUNT(*)
FROM olist_orders_dataset
WHERE TRIM(COALESCE(order_delivered_carrier_date, '')) <> ''
  AND TRIM(COALESCE(order_approved_at, '')) <> ''
  AND order_delivered_carrier_date < order_approved_at
UNION ALL
SELECT 'Entregado al cliente antes que al transportista', COUNT(*)
FROM olist_orders_dataset
WHERE TRIM(COALESCE(order_delivered_customer_date, '')) <> ''
  AND TRIM(COALESCE(order_delivered_carrier_date, '')) <> ''
  AND order_delivered_customer_date < order_delivered_carrier_date
UNION ALL
SELECT 'Fecha estimada antes de la compra', COUNT(*)
FROM olist_orders_dataset
WHERE order_estimated_delivery_date < order_purchase_timestamp;

-- 6d. Montos: rangos, ceros y negativos (una fila por columna de monto)
SELECT 'items.price' AS columna,
       COUNT(*) AS filas,
       MIN(CAST(price AS REAL)) AS minimo,
       MAX(CAST(price AS REAL)) AS maximo,
       ROUND(AVG(CAST(price AS REAL)), 2) AS promedio,
       SUM(CASE WHEN CAST(price AS REAL) = 0 THEN 1 ELSE 0 END) AS en_cero,
       SUM(CASE WHEN CAST(price AS REAL) < 0 THEN 1 ELSE 0 END) AS negativos
FROM olist_order_items_dataset
UNION ALL
SELECT 'items.freight_value', COUNT(*),
       MIN(CAST(freight_value AS REAL)), MAX(CAST(freight_value AS REAL)),
       ROUND(AVG(CAST(freight_value AS REAL)), 2),
       SUM(CASE WHEN CAST(freight_value AS REAL) = 0 THEN 1 ELSE 0 END),
       SUM(CASE WHEN CAST(freight_value AS REAL) < 0 THEN 1 ELSE 0 END)
FROM olist_order_items_dataset
UNION ALL
SELECT 'payments.payment_value', COUNT(*),
       MIN(CAST(payment_value AS REAL)), MAX(CAST(payment_value AS REAL)),
       ROUND(AVG(CAST(payment_value AS REAL)), 2),
       SUM(CASE WHEN CAST(payment_value AS REAL) = 0 THEN 1 ELSE 0 END),
       SUM(CASE WHEN CAST(payment_value AS REAL) < 0 THEN 1 ELSE 0 END)
FROM olist_order_payments_dataset
UNION ALL
SELECT 'payments.payment_installments', COUNT(*),
       MIN(CAST(payment_installments AS REAL)), MAX(CAST(payment_installments AS REAL)),
       ROUND(AVG(CAST(payment_installments AS REAL)), 2),
       SUM(CASE WHEN CAST(payment_installments AS REAL) = 0 THEN 1 ELSE 0 END),
       SUM(CASE WHEN CAST(payment_installments AS REAL) < 0 THEN 1 ELSE 0 END)
FROM olist_order_payments_dataset;
