#!/usr/bin/env bash
# steam-x.sh — Abre Steam com XWayland garantido
~/.config/scripts/wait-for-x.sh 10
exec steam "$@"
