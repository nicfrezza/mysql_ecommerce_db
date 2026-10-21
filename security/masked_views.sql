USE ecommerce_db;

-- =====================================================================
-- VIEW MASCARADA — expõe dados do cliente SEM o hash de senha
-- BI e suporte nunca enxergam password_hash
-- =====================================================================
CREATE OR REPLACE VIEW v_customers_public AS
SELECT id, first_name, last_name,
       CONCAT(LEFT(email, 2), '****', SUBSTRING_INDEX(email, '@', -1)) AS email_mascarado,
       role, created_at
FROM users;

-- View de dados sensíveis mascarados para suporte:
CREATE OR REPLACE VIEW v_orders_support AS
SELECT o.id, o.order_status, o.total_amount, o.created_at,
       u.first_name, u.last_name,
       CONCAT(LEFT(o.shipping_zip_code, 5), '***') AS shipping_zip_mascarado
FROM orders o
JOIN users u ON u.id = o.user_id;

-- BI usa a view, nunca a tabela base:
GRANT SELECT ON ecommerce_db.v_customers_public TO 'bi_user'@'%';
-- (sem GRANT na tabela users!)

-- Audit: quem consultou pedidos (MySQL Enterprise / tabela manual)
CREATE TABLE audit_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_account VARCHAR(100),
    action VARCHAR(50),
    table_name VARCHAR(64)
);