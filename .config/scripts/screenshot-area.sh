#!/usr/bin/env bash
set -euo pipefail
DIR="$HOME/Imagens/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"
grim -g "$(slurp)" "$FILE"
wl-copy < "$FILE"
