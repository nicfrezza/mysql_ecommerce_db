#!/bin/bash
# =====================================================================
# BACKUP FULL DIÁRIO — mysqldump com single-transaction
# (não bloqueia InnoDB; consistente sem parar a aplicação)
# =====================================================================
BACKUP_DIR="/backups/ecommerce"
DATE=$(date +%Y-%m-%d_%H%M)
FILE="$BACKUP_DIR/ecommerce_full_$DATE.sql.gz"
RETENTION_DAYS=14

mkdir -p "$BACKUP_DIR"

mysqldump \
  --user=backup_user \
  --password="$MYSQL_PWD" \
  --single-transaction \      # snapshot consistente sem lock
  --routines \                # inclui procedures (sp_checkout!)
  --triggers \
  --events \
  --master-data=2 \           # registra binlog position (p/ point-in-time recovery)
  ecommerce_db | gzip > "$FILE"

# Rotação: apaga backups antigos
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Log
echo "[$(date)] backup: $FILE ($(du -h $FILE | cut -f1))" >> "$BACKUP_DIR/backup.log"