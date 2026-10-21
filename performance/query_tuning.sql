USE ecommerce_db;

-- =====================================================================
-- QUERY TUNING — antes/depois com EXPLAIN
-- =====================================================================

-- ❌ ANTES: FULL TABLE SCAN (type=ALL) — sem índice em orders(user_id)
EXPLAIN FORMAT=TREE
SELECT o.id, o.total_amount, o.created_at
FROM orders o
WHERE o.user_id = 1
ORDER BY o.created_at DESC
LIMIT 20;

-- ✔ DEPOIS: com idx_orders_user_created
--    type=ref, key=idx_orders_user_created, sem filesort
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);
EXPLAIN FORMAT=TREE
SELECT o.id, o.total_amount, o.created_at
FROM orders o
WHERE o.user_id = 1
ORDER BY created_at DESC
LIMIT 20;

-- ❌ ANTES: função na coluna mata o índice
EXPLAIN SELECT COUNT(*) FROM orders
WHERE YEAR(created_at) = 2025;          -- type=ALL

-- ✔ DEPOIS: range scan (SARGable)
EXPLAIN SELECT COUNT(*) FROM orders
WHERE created_at >= '2025-01-01'
  AND created_at <  '2026-01-01';       -- type=range

-- ❌ ANTES: SELECT * força leitura de todas as colunas grandes
--    (orders tem 5 colunas de endereço snapshot)
-- ✔ DEPOIS: covering index (índice contém tudo que a query precisa)
EXPLAIN
SELECT order_id, status FROM payments
WHERE status = 'completed';   -- com idx(status, created_at): Extra=Using index