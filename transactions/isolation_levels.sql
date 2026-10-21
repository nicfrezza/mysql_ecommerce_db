USE ecommerce_db;

-- =====================================================================
-- DEMONSTRAÇÃO: por que e-commerce usa READ COMMITTED / REPEATABLE READ
-- Execute em DUAS sessões simultâneas para visualizar
-- =====================================================================

-- CENÁRIO: problema de leitura fantasma / não repetível
-- Sessão A:                              -- Sessão B:
SET TRANSACTION ISOLATION
    LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT COUNT(*) FROM orders WHERE order_status='pending';
                                         INSERT INTO orders (...) VALUES (...); COMMIT;
SELECT COUNT(*) FROM orders WHERE order_status='pending';
-- REPEATABLE READ (padrão InnoDB): mesma contagem nas 2 leituras ✔
-- READ COMMITTED: contagem muda (non-repeatable read) ✘

-- VERIFICAR nível atual:
SELECT @@transaction_isolation;

-- DEMONSTRAÇÃO de lost update SEM lock (errado) vs COM lock (correto):
--  ERRADO (race condition — dois clientes compram o último item):
--   SELECT stock_quantity FROM product_variants WHERE id = 4;        -- ambos veem 5
--   ... app calcula 5-3=2 ...                                        -- ambos calculam
--   UPDATE product_variants SET stock_quantity = 2 WHERE id = 4;     -- oversell!

--  CORRETO (lock na leitura):
START TRANSACTION;
SELECT stock_quantity FROM product_variants WHERE id = 4 FOR UPDATE;  -- bloqueia a linha
UPDATE product_variants SET stock_quantity = stock_quantity - 3 WHERE id = 4;
COMMIT;  -- libera o lock