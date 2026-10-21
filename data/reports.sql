USE ecommerce_db;

-- =====================================================================
-- RELATÓRIOS ANALÍTICOS
-- =====================================================================

-- 1. Receita mensal (pagamentos concluídos)
SELECT DATE_FORMAT(p.created_at, '%Y-%m') AS mes,
       COUNT(DISTINCT p.order_id)         AS pedidos,
       SUM(p.amount)                      AS receita
FROM payments p
WHERE p.status = 'completed'
GROUP BY mes
ORDER BY mes DESC;

-- 2. Top 10 produtos mais vendidos
SELECT p.name,
       v.sku,
       SUM(oi.quantity)                        AS unidades_vendidas,
       SUM(oi.quantity * oi.unit_price)        AS receita_total
FROM order_items oi
JOIN product_variants v ON v.id = oi.product_variant_id
JOIN products p         ON p.id = v.product_id
GROUP BY p.name, v.sku
ORDER BY unidades_vendidas DESC
LIMIT 10;

-- 3. Histórico de pedidos do cliente (com snapshot de endereço)
SELECT o.id, o.order_status, o.total_amount, o.created_at,
       o.shipping_city, o.shipping_state,
       GROUP_CONCAT(CONCAT(p.name, ' x', oi.quantity) SEPARATOR '; ') AS itens
FROM orders o
JOIN order_items oi         ON oi.order_id = o.id
JOIN product_variants v     ON v.id = oi.product_variant_id
JOIN products p             ON p.id = v.product_id
WHERE o.user_id = 1
GROUP BY o.id
ORDER BY o.created_at DESC;

-- 4. Clientes top por valor gasto
SELECT u.first_name, u.last_name, u.email,
       COUNT(o.id)    AS total_pedidos,
       SUM(o.total_amount) AS valor_total
FROM users u
JOIN orders o ON o.user_id = u.id
GROUP BY u.id
ORDER BY valor_total DESC
LIMIT 10;

-- 5. Estoque crítico (< 10 unidades)
SELECT p.name, v.sku, v.stock_quantity
FROM product_variants v
JOIN products p ON p.id = v.product_id
WHERE v.stock_quantity < 10 AND p.is_active = TRUE
ORDER BY v.stock_quantity ASC;

-- 6. Itens abandonados no carrinho há mais de 7 dias
SELECT u.email, p.name, ci.quantity, ci.created_at
FROM cart_items ci
JOIN users u            ON u.id = ci.user_id
JOIN product_variants v ON v.id = ci.product_variant_id
JOIN products p         ON p.id = v.product_id
WHERE ci.created_at < NOW() - INTERVAL 7 DAY;