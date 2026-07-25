#!/usr/bin/env bash
# restore-opencode.sh — Restaura backup do opencode
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

BACKUP_DIR="$HOME/Backups/opencode"

echo ""
echo -e "${BOLD}  Restaurar OpenCode${NC}"
echo ""

# Listar backups disponíveis
if [ ! -d "$BACKUP_DIR" ]; then
  echo -e "  ${RED}✘${NC} Nenhum backup encontrado em $BACKUP_DIR"
  exit 1
fi

echo -e "  ${BOLD}Backups disponíveis:${NC}"
echo ""
BACKUPS=($(ls -t "$BACKUP_DIR"/opencode-backup-*.tar.gz 2>/dev/null))
if [ ${#BACKUPS[@]} -eq 0 ]; then
  echo -e "  ${RED}✘${NC} Nenhum backup encontrado"
  exit 1
fi

for i in "${!BACKUPS[@]}"; do
  FILE="${BACKUPS[$i]}"
  SIZE=$(du -h "$FILE" | cut -f1)
  DATE=$(stat -c '%y' "$FILE" | cut -d. -f1)
  echo "    $((i+1))) $(basename "$FILE") ($SIZE) — $DATE"
done

echo ""
read -rp "  Selecione [1-${#BACKUPS[@]}]: " choice

if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#BACKUPS[@]} ]; then
  SELECTED="${BACKUPS[$((choice-1))]}"
  echo ""
  echo -e "  ${CYAN}→${NC} Restaurando $(basename "$SELECTED")..."

  # Parar opencode se estiver rodando
  pkill opencode 2>/dev/null || true
  sleep 1

  # Restaurar
  mkdir -p "$HOME/.local/share/opencode"
  mkdir -p "$HOME/.config/opencode"
  tar xzf "$SELECTED" -C "$HOME"

  echo -e "  ${GREEN}✔${NC} Backup restaurado com sucesso!"
  echo -e "  ${CYAN}→${NC} Execute opencode para continuar de onde parou"
else
  echo -e "  ${RED}✘${NC} Seleção inválida"
fi
echo ""
