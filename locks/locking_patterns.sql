USE ecommerce_db;

-- =====================================================================
-- PADRÕES DE LOCKING
-- =====================================================================

-- 1. LOCK PESSIMISTA — SELECT ... FOR UPDATE
--    Reserva o estoque durante a transação. Outras transações esperam.
START TRANSACTION;
SELECT id, stock_quantity FROM product_variants
WHERE sku = 'PH-X-256-WHT'
FOR UPDATE;   -- bloqueia apenas ESSAS linhas (row lock), não a tabela
-- ... processa pagamento ...
UPDATE product_variants SET stock_quantity = stock_quantity - 1 WHERE sku = 'PH-X-256-WHT';
COMMIT;

-- 2. LOCK COMPARTILHADO — FOR SHARE
--    Lê sem bloquear outras leituras, mas impede UPDATE simultâneo.
START TRANSACTION;
SELECT total_amount FROM orders WHERE id = 1 FOR SHARE;
COMMIT;

-- 3. LOCK OTIMISTA (versioning) — sem lock, mas com retry
--    Mais útil quando o conflito é raro:
START TRANSACTION;
    UPDATE product_variants
    SET stock_quantity = stock_quantity - 2
    WHERE id = 4
      AND stock_quantity >= 2;   -- condição já valida a versão atual
    -- se ROW_COUNT() = 0 => estoque mudou => aplicativo faz retry
    SELECT ROW_COUNT();
COMMIT;

-- 4. LOCK DE TABELA inteira (evite em produção; útil p/ manutenção)
LOCK TABLES products WRITE;
-- ... operações DDL/DML de manutenção ...
UNLOCK TABLES;