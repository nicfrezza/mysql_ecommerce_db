# 🛒 MySQL E-commerce Database

Banco de dados relacional completo para um e-commerce, construído em **MySQL 8 (InnoDB)**. O projeto vai além da modelagem de tabelas: cobre **transações atômicas, controle de concorrência, tuning de queries, segurança, manutenção e backup**, ou seja, o ciclo de vida de um banco de dados em produção.

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Advanced-orange)
![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)

---

## 📌 Destaques

- **Modelagem normalizada** com 11 tabelas, chaves estrangeiras, `CHECK` constraints e estratégias de `ON DELETE` pensadas para cada relacionamento.
- **Snapshots históricos**: o preço (`order_items.unit_price`) e o endereço de entrega (`orders.shipping_*`) são copiados no momento da compra, então mudanças futuras não alteram pedidos antigos.
- **Checkout atômico** via *stored procedure* (`sp_checkout`) com lock pessimista para evitar *oversell*.
- **Demonstrações práticas** de níveis de isolamento, padrões de locking e deadlock (com prevenção).
- **Tuning com `EXPLAIN`**: exemplos de antes/depois com índices, queries SARGable e covering index.
- **Segurança**: princípio do menor privilégio, views com dados mascarados e tabela de auditoria.
- **Operação**: queries de monitoramento, rotinas de manutenção, arquivamento de pedidos e backup automatizado.

---

## 🗂️ Estrutura do Projeto

```
mysql_ecommerce_db/
├── database/
│   └── 01.create_tables.sql        # Schema completo (tabelas, constraints e índices base)
├── data/
│   ├── dml_operations.sql          # Operações do dia a dia (carrinho, cancelamento, soft delete)
│   └── reports.sql                 # Relatórios analíticos
├── transactions/
│   ├── chackout_transaction.sql    # Stored procedure sp_checkout
│   └── isolation_levels.sql        # Níveis de isolamento e lost update
├── locks/
│   ├── locking_patterns.sql        # Lock pessimista, compartilhado, otimista e de tabela
│   └── deadlock_demo.sql           # Reprodução e prevenção de deadlock
├── performance/
│   ├── index.sql                   # Índices justificados por queries reais + FULLTEXT
│   └── query_tuning.sql            # Antes/depois com EXPLAIN
├── security/
│   ├── users_and_privileges.sql    # Usuários e privilégios por função
│   └── masked_views.sql            # Views mascaradas + audit_log
├── maintenance/
│   ├── routine_maintenance.sql     # ANALYZE, CHECK, limpeza de carrinhos e pagamentos
│   └── archive_old_orders.sql      # Arquivamento de pedidos com mais de 2 anos
├── monitoring/
│   └── monitoring_queries.sql      # Diagnóstico de saúde do banco
└── backup/
    └── backup_full.sh              # Backup diário com mysqldump + rotação
```

---

## 🧩 Modelo de Dados

### Tabelas

| Tabela | Descrição |
|---|---|
| `users` | Clientes e administradores (`role` validada por `CHECK`) |
| `addresses` | Endereços do usuário, com flags de entrega e cobrança padrão |
| `categories` | Categorias hierárquicas (auto-relacionamento via `parent_id`) |
| `products` | Catálogo de produtos, com *soft delete* via `is_active` |
| `product_variants` | Variantes por SKU, com preço e estoque |
| `product_attributes` | Atributos dinâmicos do produto (chave/valor) |
| `product_images` | Imagens com ordem de exibição e imagem principal |
| `cart_items` | Carrinho (`UNIQUE(user_id, product_variant_id)` evita duplicatas) |
| `orders` | Pedidos, com snapshot do endereço de entrega |
| `order_items` | Itens do pedido, com snapshot do preço unitário |
| `payments` | Pagamentos e seus status |

### Decisões de design

| Decisão | Motivo |
|---|---|
| `orders → users`: `ON DELETE RESTRICT` | Não permite apagar usuários com histórico de compras |
| `order_items → product_variants`: `ON DELETE RESTRICT` | Não permite apagar variantes que já foram vendidas |
| `ON DELETE CASCADE` em endereços, carrinho e mídias do produto | Dados dependentes que perdem o sentido sem o pai |
| `ON DELETE SET NULL` em categorias e produtos | Preserva o produto/subcategoria se a categoria for removida |
| `DECIMAL(10,2)` para valores monetários | Evita erros de arredondamento de ponto flutuante |
| `CHECK` em preço, estoque, quantidade e status | Integridade garantida no próprio banco |

---

## ⚙️ Funcionalidades em Detalhe

### 1. Checkout transacional (`transactions/`)

A procedure `sp_checkout(p_user_id, p_payment_method)` executa tudo em **uma única transação**: ou o pedido é criado por completo, ou nada acontece.

1. Percorre o carrinho com um cursor `FOR UPDATE` (lock pessimista).
2. Valida o estoque de cada item dentro da transação.
3. Calcula total, frete e impostos.
4. Cria o pedido com **snapshot do endereço** padrão de entrega.
5. Cria os itens com **snapshot do preço** e debita o estoque.
6. Registra o pagamento como `pending`.
7. Limpa o carrinho e confirma (`COMMIT`).

```sql
CALL sp_checkout(2, 'credit_card');
```

O arquivo `isolation_levels.sql` demonstra `REPEATABLE READ` vs `READ COMMITTED` em duas sessões simultâneas e mostra a diferença entre um *lost update* (errado) e a leitura com `FOR UPDATE` (correto).

### 2. Concorrência e locks (`locks/`)

| Padrão | Quando usar |
|---|---|
| `SELECT ... FOR UPDATE` (pessimista) | Alta chance de conflito, como o estoque durante o checkout |
| `FOR SHARE` (compartilhado) | Ler com garantia de que a linha não mudará |
| Otimista (`UPDATE ... WHERE stock_quantity >= n` + `ROW_COUNT()`) | Conflitos raros, com retry na aplicação |
| `LOCK TABLES` | Somente manutenção; evitar em produção |

O `deadlock_demo.sql` reproduz o deadlock clássico (duas transações atualizando as mesmas linhas em ordem inversa), mostra como diagnosticá-lo com `SHOW ENGINE INNODB STATUS` e ensina a **prevenção: sempre travar as linhas na mesma ordem** (`ORDER BY id`).

### 3. Performance (`performance/`)

- Cada índice é justificado pela query que ele atende.
- Índice composto `orders(user_id, created_at)` elimina *full table scan* e *filesort* no histórico do cliente.
- Índice `FULLTEXT` em `products(name, description)` para busca textual.
- Exemplos de antes/depois com `EXPLAIN`:
  - Query com `YEAR(created_at)` (invalida o índice) → reescrita como *range scan* (SARGable).
  - Covering index em `payments(status, created_at)`.

### 4. Relatórios (`data/reports.sql`)

- Receita mensal (pagamentos concluídos)
- Top 10 produtos mais vendidos
- Histórico de pedidos do cliente (com `GROUP_CONCAT`)
- Clientes com maior valor gasto
- Estoque crítico (< 10 unidades)
- Itens abandonados no carrinho há mais de 7 dias

### 5. Segurança (`security/`)

| Usuário | Perfil | Permissões |
|---|---|---|
| `app_user` | Backend da aplicação | `SELECT`, `INSERT`, `UPDATE` (sem `DELETE`) |
| `checkout_svc` | Serviço de checkout | Apenas `EXECUTE` em `sp_checkout` |
| `bi_user` | BI / relatórios | Somente leitura |
| `dba_admin` | Administração | Todos os privilégios (apenas `localhost`) |
| `backup_user` | Backup | Leitura global + `LOCK TABLES`, `PROCESS`, `EVENT`, `TRIGGER` |

Também há **views mascaradas** (`v_customers_public`, `v_orders_support`) que escondem `password_hash`, mascaram e-mails e CEPs, e uma tabela `audit_log` para auditoria.

### 6. Manutenção e operação (`maintenance/`, `monitoring/`, `backup/`)

- **Manutenção**: `ANALYZE TABLE`, `CHECK TABLE`, limpeza de carrinhos abandonados (> 30 dias) e pagamentos pendentes órfãos (> 24h).
- **Arquivamento**: move pedidos com mais de 2 anos para `orders_archive` e `order_items_archive` dentro de uma transação.
- **Monitoramento**: processos ativos, locks em espera, tamanho das tabelas, índices não utilizados, *full table scans*, *hit rate* do buffer pool e ativação do slow query log.
- **Backup**: `mysqldump --single-transaction` (sem bloquear o InnoDB), com rotinas, triggers, eventos, posição do binlog para *point-in-time recovery*, compressão com gzip e retenção de 14 dias.

---

## 🚀 Como Executar

### Pré-requisitos

- MySQL 8.0+
- Cliente `mysql` e `mysqldump` (para o script de backup)

> 💡 Os scripts de `data/` assumem a existência de dados de exemplo (usuários, produtos, SKUs etc.). Popule o banco com seus próprios dados de teste antes de executá-los.

---

## 🧠 Conceitos Demonstrados

`Normalização` · `Integridade referencial` · `ACID` · `Stored Procedures` · `Cursores` · `Níveis de isolamento` · `Locks pessimista/otimista` · `Deadlocks` · `Índices compostos` · `Covering index` · `FULLTEXT` · `EXPLAIN` · `Soft delete` · `Views` · `Menor privilégio` · `Mascaramento de dados` · `Auditoria` · `Arquivamento de dados` · `Backup e recuperação` · `Performance Schema / sys schema`

---

## 👤 Autor

**Nicoli Frezza**
[GitHub](https://github.com/nicfrezza)

---

## 📄 Licença

Projeto desenvolvido para fins de estudo e portfólio.
