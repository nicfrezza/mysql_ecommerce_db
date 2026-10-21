-- =====================================================================
-- MONITORING — diagnóstico de saúde do banco
-- =====================================================================

-- 1. Conexões ativas + queries em execução
SHOW PROCESSLIST;
SELECT * FROM sys.session
WHERE command != 'Sleep' AND db = 'ecommerce_db';

-- 2. Locks em espera (quem trava quem)
SELECT r.trx_id              AS waiting_trx,
       r.trx_mysql_thread_id AS waiting_thread,
       b.trx_mysql_thread_id AS blocking_thread,
       r.trx_query           AS waiting_query
FROM performance_schema.data_lock_waits w
JOIN information_schema.innodb_trx b ON b.trx_id = w.BLOCKING_ENGINE_TRANSACTION_ID
JOIN information_schema.innodb_trx r ON r.trx_id = w.REQUESTING_ENGINE_TRANSACTION_ID;

-- 3. Tamanho das tabelas (detecta crescimento anômalo)
SELECT table_name,
       ROUND((data_length + index_length)/1024/1024, 1) AS size_mb,
       table_rows
FROM information_schema.tables
WHERE table_schema = 'ecommerce_db'
ORDER BY data_length + index_length DESC;

-- 4. Índices nunca usados (candidatos a remoção)
SELECT * FROM sys.schema_unused_indexes
WHERE object_schema = 'ecommerce_db';

-- 5. Queries mais custosas (do sys schema)
SELECT * FROM sys.statements_with_full_table_scans
WHERE db = 'ecommerce_db' LIMIT 10;

-- 6. Uso de buffer pool (hit rate deve ser > 99%)
SELECT ROUND(100 * (1 - (innodb_buffer_pool_reads / innodb_buffer_pool_read_requests)), 2)
       AS buffer_pool_hit_pct
FROM (SELECT variable_value AS innodb_buffer_pool_reads
      FROM performance_schema.global_status
      WHERE variable_name = 'Innodb_buffer_pool_reads') r,
     (SELECT variable_value AS innodb_buffer_pool_read_requests
      FROM performance_schema.global_status
      WHERE variable_name = 'Innodb_buffer_pool_read_requests') t;

-- 7. Habilitar slow query log (diagnóstico de performance)
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 0.5;  -- queries > 0.5s