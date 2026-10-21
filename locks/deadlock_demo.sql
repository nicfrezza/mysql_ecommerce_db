USE ecommerce_db;

-- =====================================================================
-- DEADLOCK: clássico de e-commerce (duas transações em ordem inversa)
-- Execute manualmente em 2 sessões, na ordem indicada
-- =====================================================================

-- Sessão A:                          -- Sessão B:
START TRANSACTION;
UPDATE product_variants
SET stock_quantity = stock_quantity - 1
WHERE id = 1;                        -- trava linha 1
                                     START TRANSACTION;
                                     UPDATE product_variants
                                     SET stock_quantity = stock_quantity - 1
                                     WHERE id = 2;                 -- trava linha 2
UPDATE product_variants
SET stock_quantity = stock_quantity - 1
WHERE id = 2;                        -- espera lock da linha 2 (sessão B)
                                     UPDATE product_variants
                                     SET stock_quantity = stock_quantity - 1
                                     WHERE id = 1;   -- espera linha 1 => 💀 DEADLOCK
                                     -- MySQL mata UMA das transações (vítima)

-- Diagnóstico pós-deadlock:
SHOW ENGINE INNODB STATUS\G          -- seção "LATEST DETECTED DEADLOCK"

-- PREVENÇÃO (a lição do portfólio):
-- Sempre atualizar as linhas NA MESMA ORDEM (ORDER BY id):
START TRANSACTION;
    SELECT id FROM product_variants WHERE id IN (2, 1) ORDER BY id FOR UPDATE;
    -- agora as duas sessões lockam na ordem id=1, id=2 => sem ciclo
COMMIT;