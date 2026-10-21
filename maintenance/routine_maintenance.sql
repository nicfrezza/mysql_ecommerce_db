USE ecommerce_db;

-- =====================================================================
-- ROTINAS DE MANUTENÇÃO
-- =====================================================================

-- 1. Atualizar estatísticas de índice (otimiza o query planner)
ANALYZE TABLE users, orders, order_items, products, product_variants;

-- 2. Reclaim de espaço (após grandes deletes; bloqueia — usar em janela!)
-- OPTIMIZE TABLE order_items;

-- 3. Verificar integridade das tabelas InnoDB
CHECK TABLE orders, order_items, payments;

-- 4. Limpar carrinhos abandonados (> 30 dias) — job semanal
DELETE FROM cart_items
WHERE created_at < NOW() - INTERVAL 30 DAY;

-- 5. Pagamentos pendentes órfãos há > 24h → marcar failed (job diário)
UPDATE payments
SET status = 'failed'
WHERE status = 'pending'
  AND created_at < NOW() - INTERVAL 1 DAY;