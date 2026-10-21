-- =====================================================================
-- ARQUIVAMENTO DE PEDIDOS ANTIGOS (> 2 anos)
-- Mantém a tabela operacional enxuta → queries de vendas recentes rápidas
-- =====================================================================
CREATE TABLE IF NOT EXISTS orders_archive LIKE orders;
CREATE TABLE IF NOT EXISTS order_items_archive LIKE order_items;

START TRANSACTION;

-- 1. Copia pedidos antigos (ON DELETE RESTRICT em order_items protege FK)
INSERT INTO orders_archive
SELECT * FROM orders WHERE created_at < NOW() - INTERVAL 2 YEAR;

INSERT INTO order_items_archive
SELECT oi.* FROM order_items oi
JOIN orders o ON o.id = oi.order_id
WHERE o.created_at < NOW() - INTERVAL 2 YEAR;

-- 2. Remove do operacional (ordem importa: filhos antes dos pais)
DELETE oi FROM order_items oi
JOIN orders o ON o.id = oi.order_id
WHERE o.created_at < NOW() - INTERVAL 2 YEAR;

DELETE FROM payments
WHERE order_id NOT IN (SELECT id FROM orders);  -- payments órfãos arquiváveis

DELETE FROM orders
WHERE created_at < NOW() - INTERVAL 2 YEAR;

COMMIT;

-- 3. Validação
SELECT
  (SELECT COUNT(*) FROM orders)          AS orders_ativos,
  (SELECT COUNT(*) FROM orders_archive)  AS orders_arquivados;