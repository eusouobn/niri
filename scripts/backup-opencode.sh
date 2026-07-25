#!/usr/bin/env bash
# backup-opencode.sh — Backup do opencode (chat, sessões, config)
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

BACKUP_DIR="$HOME/Backups/opencode"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/opencode-backup-$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

echo ""
echo -e "${BOLD}  Backup do OpenCode${NC}"
echo ""

echo -e "  ${CYAN}→${NC} Criando backup..."
tar czf "$BACKUP_FILE" \
  -C "$HOME" \
  .local/share/opencode/opencode.db \
  .config/opencode/ \
  2>/dev/null

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo -e "  ${GREEN}✔${NC} Backup salvo: ${BOLD}$BACKUP_FILE${NC} ($SIZE)"
echo ""

# Listar backups anteriores
echo -e "  ${BOLD}Backups disponíveis:${NC}"
ls -lh "$BACKUP_DIR"/opencode-backup-*.tar.gz 2>/dev/null | awk '{print "    " $NF " (" $5 ")"}'
echo ""
