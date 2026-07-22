#!/bin/bash
# power-button.sh — Chamado pelo udev quando o botão Power é pressionado
# Mostra notificação e desliga após 10 segundos

DELAY=10
USER_NAME=$(loginctl list-sessions --no-legend | awk '{print $1}' | head -1)
USER_HOME=$(eval echo "~$(loginctl show-session $USER_NAME -p Name --value 2>/dev/null || echo bn)")
DBUS_ADDRESS="unix:path=/run/user/$(id -u ${USER_NAME:-bn})/bus"

# Cancelar desligamento anterior se existir
pkill -f "shutdown -c" 2>/dev/null || true
pkill -f "power-countdown" 2>/dev/null || true

# Notificar o usuário
sudo -u "${USER_NAME:-bn}" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDRESS" \
  notify-send -u critical -t 10000 \
  "⏻ Desligando..." \
  "PC será desligado em ${DELAY} segundos.\nPressione Power novamente para cancelar." \
  2>/dev/null || true

# Countdown em background (cancelável)
(
  sleep "$DELAY"
  shutdown now "Desligamento solicitado via botão Power"
) &
echo $! > /tmp/power-countdown.pid
