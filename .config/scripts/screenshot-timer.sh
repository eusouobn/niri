#!/usr/bin/env bash
set -euo pipefail
DIR="$HOME/Imagens/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"
sleep 5
if niri msg -j outputs &>/dev/null; then
  MONITOR=$(niri msg -j outputs | grep -oP '"name":\s*"[^"]*"' | grep -oP '"[^"]*"$' | tr -d '"' | head -1)
  grim -o "$MONITOR" "$FILE"
else
  grim "$FILE"
fi
wl-copy < "$FILE"
