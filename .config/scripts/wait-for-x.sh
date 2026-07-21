#!/usr/bin/env bash
# wait-for-x.sh — Espera o xwayland-satellite ficar pronto (socket X disponível)
set -euo pipefail

TIMEOUT=${1:-10}
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if [ -S "/tmp/.X11-unix/X1" ] || [ -S "/tmp/.X11-unix/X0" ]; then
        # Socket existe, testa se o display responde
        if xdpyinfo -display ":1" &>/dev/null || xdpyinfo -display ":0" &>/dev/null; then
            exit 0
        fi
    fi
    sleep 0.2
    ELAPSED=$((ELAPSED + 1))
done

echo "⚠ xwayland-satellite não ficou pronto em ${TIMEOUT}s" >&2
exit 1
