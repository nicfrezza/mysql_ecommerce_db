-- =====================================================================
-- PRINCÍPIO DO MENOR PRIVILÉGIO
-- Cada usuário só acessa o que sua função precisa
-- =====================================================================

-- 1. Aplicação (backend): leitura geral + gravação operacional
CREATE USER 'app_user'@'%'    IDENTIFIED BY 'senha_forte_aqui';
GRANT SELECT, INSERT, UPDATE         ON ecommerce_db.*           TO 'app_user'@'%';
-- Sem DELETE: app nunca apaga rows fisicamente (soft delete / procedures)

-- 2. Procedure-only (checkout): pode debitar estoque SEM UPDATE direto
CREATE USER 'checkout_svc'@'%' IDENTIFIED BY 'senha_forte_aqui';
GRANT EXECUTE ON PROCEDURE ecommerce_db.sp_checkout TO 'checkout_svc'@'%';

-- 3. BI/Reporting: somente leitura
CREATE USER 'bi_user'@'%'     IDENTIFIED BY 'senha_forte_aqui';
GRANT SELECT ON ecommerce_db.* TO 'bi_user'@'%';

-- 4. DBA: administração
CREATE USER 'dba_admin'@'localhost' IDENTIFIED BY 'senha_forte_aqui';
GRANT ALL PRIVILEGES ON *.* TO 'dba_admin'@'localhost' WITH GRANT OPTION;

-- 5. Backup: só leitura global + lock para consistência
CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'senha_forte_aqui';
GRANT SELECT, LOCK TABLES, PROCESS, EVENT, TRIGGER ON *.* TO 'backup_user'@'localhost';

-- Hardening
REQUIRE SSL;                       -- conecte via TLS
FLUSH PRIVILEGES;