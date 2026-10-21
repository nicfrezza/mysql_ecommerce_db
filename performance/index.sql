USE ecommerce_db;

-- =====================================================================
-- ÍNDICES — cada um justificado por uma query real do sistema
-- =====================================================================

-- 1. Histórico de pedidos do cliente (reports.sql #3)
--    Query: WHERE user_id = ? ORDER BY created_at DESC
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);

-- 2. Detalhe do pedido (order_items sempre join por order_id)
CREATE INDEX idx_order_items_order ON order_items(order_id);

-- 3. Pagamentos de um pedido + relatório por status
CREATE INDEX idx_payments_order  ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(status, created_at);

-- 4. Variantes de um produto (página de detalhe do produto)
CREATE INDEX idx_variants_product ON product_variants(product_id);

-- 5. Listagem de catálogo por categoria (só ativos)
--    Query: WHERE category_id = ? AND is_active = TRUE
CREATE INDEX idx_products_category ON products(category_id, is_active);

-- 6. Busca textual no catálogo (fulltext)
CREATE FULLTEXT INDEX ft_products_search ON products(name, description);
-- Uso:
SELECT name FROM products
WHERE MATCH(name, description) AGAINST('notebook leve' IN NATURAL LANGUAGE MODE);