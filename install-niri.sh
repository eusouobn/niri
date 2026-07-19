#!/usr/bin/env bash

# ──────────────────────────────────────────────
# Forçar execução com bash (antes do set -euo pipefail)
# ──────────────────────────────────────────────
if [ -z "$BASH_VERSION" ]; then
  echo -e "\033[0;31m✘\033[0m Este script precisa ser executado com bash, não com sh."
  echo "  Use: bash install-niri.sh"
  exit 1
fi

set -euo pipefail

# ──────────────────────────────────────────────
# Cores e funções
# ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAG='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

step()  {
  echo ""
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${CYAN}┃${NC} ${MAG}★${NC} ${BOLD}$1${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}
info()  { echo -e "  ${CYAN}→${NC} $1"; }
ok()    { echo -e "  ${GREEN}✔${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
err()   { echo -e "  ${RED}✘${NC} $1"; }

run() {
  info "$1"
  shift
  "$@"
  echo -e "  ${GREEN}✔${NC} concluído"
}

quote() {
  local quotes=(
    "O terminal é o melhor amigo do admin. — ditado popular"
    "Se não quebrou, você não mexeu o suficiente. — Lei de Murphy"
    "Linux: porque um terminal é mais leve que 5 cliques."
    "Arch btw. — todo usuário Arch"
    "Wayland é o futuro. E ele chegou."
    "Niri: o compositor que você não sabia que precisava."
    "Noctalia: porque a beleza mora nos detalhes."
    "Nem só de i3 vive o homem. — Niri 2025"
    "Pacman -Syu resolve. Sempre."
    "RTFM: a documentação é sua melhor amiga."
    "Sudo faz tudo. Inclusive café. — quase."
    "Systemd: amado por uns, odiado por outros, usado por todos."
    "AUR: porque no AUR tem de tudo, até alma gêmea."
    "Yay — porque compilar na mão é coisa do passado."
    "Tema escuro é mais que preferência, é estilo de vida."
  )
  echo -e "  ${YELLOW}💬${NC} ${quotes[$RANDOM % ${#quotes[@]}]}"
}

banner() {
  echo ""
  echo -e "  ${RED}███╗   ██╗${GREEN}██╗${YELLOW}██████╗ ${BLUE}██╗"
  echo -e "  ${RED}████╗  ██║${GREEN}██║${YELLOW}██╔══██╗${BLUE}██║"
  echo -e "  ${RED}██╔██╗ ██║${GREEN}██║${YELLOW}██████╔╝${BLUE}██║"
  echo -e "  ${RED}██║╚██╗██║${GREEN}██║${YELLOW}██╔══██╗${BLUE}██║"
  echo -e "  ${RED}██║ ╚████║${GREEN}██║${YELLOW}██║  ██║${BLUE}██║"
  echo -e "  ${RED}╚═╝  ╚═══╝${GREEN}╚═╝${YELLOW}╚═╝  ╚═╝${BLUE}╚═╝"
  echo -e "${NC}"
  echo -e "  ${CYAN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}"
  echo -e "  ${CYAN}▓${NC}        ${BOLD}Niri + Noctalia-shell${NC}          ${CYAN}▓${NC}"
  echo -e "  ${CYAN}▓${NC}     ${YELLOW}Instalação Completa — Arch Linux${NC}    ${CYAN}▓${NC}"
  echo -e "  ${CYAN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}"
  echo -e "  ${MAG}✦${NC}  ${BOLD}By eusouobn${NC}  ${MAG}✦${NC}"
  echo ""
  quote
  echo ""
}

# ──────────────────────────────────────────────
# Verificação: não rodar como root
# ──────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
  echo -e "\033[0;31m✘\033[0m NÃO execute este script como root (sudo)."
  echo "  Execute como usuário normal. O script usará sudo automaticamente."
  exit 1
fi

# ──────────────────────────────────────────────
# 1. Boas-vindas
# ──────────────────────────────────────────────
banner

echo -e "  ${YELLOW}⚠${NC} Este script irá transformar seu Arch recém-instalado"
echo -e "     em um ambiente Niri + Noctalia Shell completo."
echo -e "  ${YELLOW}⚠${NC} Certifique-se de estar conectado à internet."
echo ""
echo -n "  ${CYAN}⌨${NC} Pressione ENTER para iniciar a instalação... "
read -r
echo ""

# ──────────────────────────────────────────────
# Verificar sudo
# ──────────────────────────────────────────────
if ! command -v sudo &>/dev/null; then
  echo -e "\033[0;31m✘\033[0m 'sudo' não está instalado."
  echo "  Entre como root e instale: pacman -S sudo"
  echo "  Depois configure: echo \"$USER ALL=(ALL) ALL\" >> /etc/sudoers"
  exit 1
fi

info "Verificando acesso sudo... (digite sua senha se solicitado)"
if ! sudo -v; then
  echo -e "\033[0;31m✘\033[0m Você não tem permissão sudo."
  echo "  Entre como root e configure: echo \"$USER ALL=(ALL) ALL\" >> /etc/sudoers"
  exit 1
fi
ok "Acesso sudo confirmado"

# ──────────────────────────────────────────────
# 2. Detectar pendrive com configs
# ──────────────────────────────────────────────
step "🔍 Procurando backup em pendrive..."

PENDRIVE=""
for mount in /run/media/"$USER"/* /mnt/* /media/*; do
  [ -d "$mount" ] && [ -f "$mount/niri.tar.gz" ] && PENDRIVE="$mount" && break
done

if [ -n "$PENDRIVE" ]; then
  info "Pendrive detectado em: $PENDRIVE"
  quote
else
  warn "Nenhum pendrive com niri.tar.gz encontrado."
  warn "Suas configs serão restauradas do git (se disponível)."
fi

# ──────────────────────────────────────────────
# 3. Otimizar compilação + ferramentas básicas
# ──────────────────────────────────────────────
step "⚙️ Otimizando sistema para compilação..."

run "Sincronizando bancos e instalando nano, git..." sudo pacman -Sy --needed --noconfirm nano git

if ! sudo pacman -Qi base-devel &>/dev/null; then
  run "Instalando base-devel..." sudo pacman -S --needed --noconfirm base-devel
fi

CORES=$(nproc)
MAKEFLAGS="-j$((CORES + 1))"
if grep -q "^#MAKEFLAGS" /etc/makepkg.conf 2>/dev/null; then
  sudo sed -i "s/^#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"$MAKEFLAGS\"/" /etc/makepkg.conf
  ok "MAKEFLAGS ajustado para $MAKEFLAGS ($CORES núcleos + 1)"
elif ! grep -q "^MAKEFLAGS" /etc/makepkg.conf 2>/dev/null; then
  echo "MAKEFLAGS=\"$MAKEFLAGS\"" | sudo tee -a /etc/makepkg.conf > /dev/null
  ok "MAKEFLAGS definido como $MAKEFLAGS"
else
  info "MAKEFLAGS já configurado"
fi

if ! command -v yay &>/dev/null; then
  info "Preparando AUR helper (yay)..."
  rm -rf /tmp/yay-bin
  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
  (cd /tmp/yay-bin && makepkg -si --noconfirm)
  rm -rf /tmp/yay-bin
  ok "yay instalado com sucesso"
  quote
fi

# ──────────────────────────────────────────────
# 4. Pacotes oficiais
# ──────────────────────────────────────────────
OFFICIAL_PACKAGES=(
  dolphin dolphin-plugins kde-cli-tools kio unrar unrar-free unzip
  pacman-contrib kate cmake cmake-extras fish bc fastfetch inxi wget
  code gnome-calculator papers loupe btop gnome-disk-utility
  gnome-text-editor ark kitty firefox vlc vlc-plugins-all mpv
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr
  xdg-desktop-portal-gnome bash-completion vlc-plugin-ffmpeg
  archlinux-xdg-menu xdg-user-dirs xdg-user-dirs-gtk sddm
  nwg-displays polkit-gnome wiremix network-manager-applet
  alsa-utils ffmpeg ffmpegthumbs ffmpegthumbnailer
  breeze breeze5 breeze-gtk qt5ct papirus-icon-theme adwaita-cursors
  ufw gufw ufw-extras
  satty cpio vulkan-tools imagemagick
  bluez bluez-hid2hci bluez-tools bluez-utils bluez-deprecated-tools
  blueman libldac libfdk-aac xwayland-satellite xorg-xhost
  pipewire pipewire-pulse pipewire-alsa pipewire-audio wireplumber
  grim slurp wl-clipboard fuzzel playerctl brightnessctl libnotify
  linux-lts-headers linux-zen-headers
  nwg-look xsettingsd
  noto-fonts ttf-ubuntu-font-family
  ntfs-3g exfatprogs dosfstools btrfs-progs xfsprogs
  jfsutils f2fs-tools udftools e2fsprogs gvfs
  fzf ripgrep jq zenity wlr-randr
  nm-connection-editor upower udisks2 gnome-autoar smbclient
  swayidle xxd
)

step "📦 Instalando pacotes oficiais..."
info "${#OFFICIAL_PACKAGES[@]} pacotes — isso pode levar alguns minutos..."
info "Confira o progresso abaixo:"
info "ntfs-3g exfatprogs dosfstools btrfs-progs xfsprogs jfsutils f2fs-tools udftools e2fsprogs gvfs — suporte a sistemas de arquivos"
echo ""

sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"
echo ""
ok "Pacotes oficiais instalados"

# Garantir que nautilus não foi puxado como dependência
if pacman -Qi nautilus &>/dev/null; then
  info "Removendo nautilus (puxado como dependência)..."
  sudo pacman -Rdd --noconfirm nautilus > /dev/null 2>&1 || true
  ok "nautilus removido"
fi
quote

# ──────────────────────────────────────────────
# 5. Pacotes AUR
# ──────────────────────────────────────────────
AUR_PACKAGES=(
  niri-tearing-git nirimod-git
  noctalia-shell noctalia-qs
  qt6ct-kde ttf-ms-fonts
  orchis-theme adw-gtk-theme
  steam steam-devices heroic-games-launcher-bin
  protonplus mangohud cliphist wev
)

step "🌟 Instalando pacotes AUR..."
info "Niri-tearing-git, NiriMod, Noctalia Shell, temas e fontes Microsoft..."
info "Confira o progresso abaixo:"
echo ""

# Verificar se yay está instalado
if ! command -v yay &>/dev/null; then
  warn "yay não encontrado — instalando..."
  sudo pacman -S --needed --noconfirm yay
fi

yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
echo ""

# Verificar se Noctalia foi instalado
if command -v qs &>/dev/null; then
  ok "Pacotes AUR instalados (incluindo Noctalia Shell)"
else
  warn "Noctalia Shell pode não ter sido instalado"
  info "Tente manualmente: yay -S noctalia-shell noctalia-qs"
fi
quote

# ──────────────────────────────────────────────
# 5b. Verificar instalação do Niri
# ──────────────────────────────────────────────
step "🔍 Verificando instalação do Niri..."

if command -v niri &>/dev/null; then
  ok "Niri detectado: $(niri --version 2>/dev/null || echo 'versão desconhecida')"
else
  warn "Niri não foi encontrado no PATH."
  info "Tentando reinstalar via yay..."
  yay -S --noconfirm niri-tearing-git
  if command -v niri &>/dev/null; then
    ok "Niri instalado com sucesso!"
  else
    err "Niri ainda não encontrado. Instale manualmente: yay -S niri-tearing-git"
  fi
fi
quote

# ──────────────────────────────────────────────
# 6. Nerd Fonts
# ──────────────────────────────────────────────
NERD_FONTS=(
  ttf-ubuntu-mono-nerd
)

step "🔤 Instalando Nerd Fonts..."
info "Ubuntu Mono Nerd Bold..."
echo ""

sudo pacman -S --needed --noconfirm "${NERD_FONTS[@]}"
echo ""
run "Atualizando cache de fontes..." sudo fc-cache -f
ok "Nerd Fonts instaladas — seu terminal nunca mais será o mesmo"
quote

# ──────────────────────────────────────────────
# 6a. Clonar dotfiles do GitHub (ANTES de detectar monitores)
# ──────────────────────────────────────────────
if [ -n "$PENDRIVE" ] && [ -f "$PENDRIVE/niri.tar.gz" ]; then
  step "📂 Restaurando configurações do pendrive..."
  tar -xzf "$PENDRIVE/niri.tar.gz" -C "$HOME/.config"
  ok "Configurações restauradas do pendrive"
  quote
elif [ ! -d "$HOME/.config/niri" ]; then
  step "📥 Clonando dotfiles do GitHub..."
  info "Baixando de https://github.com/eusouobn/niri.git"
  echo ""
  git clone https://github.com/eusouobn/niri.git /tmp/niri-dotfiles
  cp -r /tmp/niri-dotfiles/.config/* "$HOME/.config/"
  rm -rf /tmp/niri-dotfiles
  ok "Dotfiles clonados do GitHub!"
  quote
fi

# ──────────────────────────────────────────────
# 6b. Auto-detecção de monitor + escala
# ──────────────────────────────────────────────
step "🖥️ Detectando monitores e configurando escala..."

# Função: detectar monitores via niri (se rodando) ou kernel DRM
detect_monitors() {
  local monitors=()

  # Tentar via niri msg (funciona se niri já estiver rodando)
  if command -v niri &>/dev/null && niri msg outputs &>/dev/null 2>&1; then
    while IFS= read -r name; do
      [ -n "$name" ] && monitors+=("$name")
    done < <(niri msg -j outputs 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for name in data:
    print(name)
" 2>/dev/null)
  fi

  # Fallback: detectar via kernel DRM (funciona antes do niri iniciar)
  if [ ${#monitors[@]} -eq 0 ]; then
    for card in /sys/class/drm/card*-*/; do
      [ -d "$card" ] || continue
      local status_file="${card}status"
      [ -f "$status_file" ] || continue
      local status
      status=$(cat "$status_file" 2>/dev/null)
      [ "$status" = "connected" ] || continue
      local output_name
      output_name=$(basename "$card" | sed 's/card[0-9]*-//')
      monitors+=("$output_name")
    done
  fi

  if [ ${#monitors[@]} -eq 0 ]; then
    echo ""
    return 1
  fi

  # Para cada monitor detectado, pegar resolução e refresh rate
  for output in "${monitors[@]}"; do
    local width="" height="" refresh=""

    # Tentar via niri msg
    if command -v niri &>/dev/null && niri msg outputs &>/dev/null 2>&1; then
      read -r width height refresh < <(niri msg -j outputs 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
o = data.get('$output', {})
modes = o.get('modes', [])
if modes:
    # Pegar o modo com maior refresh rate
    best = max(modes, key=lambda m: m.get('refresh_rate', 0))
    print(best['width'], best['height'], f\"{best['refresh_rate']/1000:.3f}\")
" 2>/dev/null)
    fi

    # Fallback: kernel DRM
    if [ -z "$width" ]; then
      local card_dir=""
      for card in /sys/class/drm/card*-*/; do
        [ -d "$card" ] || continue
        local out_name
        out_name=$(basename "$card" | sed 's/card[0-9]*-//')
        if [ "$out_name" = "$output" ]; then
          card_dir="$card"
          break
        fi
      done

      if [ -n "$card_dir" ]; then
        # Ler EDID para resolução nativa
        if [ -f "${card_dir}edid" ]; then
          local edid_hex
          edid_hex=$(xxd -p "${card_dir}edid" 2>/dev/null)
          local edid_bin
          edid_bin=$(echo "$edid_hex" | xxd -r -p 2>/dev/null)

          # Procurar por descriptor com resolução
          local i
          for i in 54 72 90 108 126; do
            local tag
            tag=$(echo "$edid_bin" | dd bs=1 count=1 skip=$i 2>/dev/null | xxd -p)
            if [ "$tag" = "000000000000" ]; then
              local w h
              w=$(printf '%d' "0x$(echo "$edid_bin" | dd bs=1 count=1 skip=$((i+2)) 2>/dev/null | xxd -p)")
              h=$(printf '%d' "0x$(echo "$edid_bin" | dd bs=1 count=1 skip=$((i+1)) 2>/dev/null | xxd -p)")
              if [ "$w" -gt 0 ] && [ "$h" -gt 0 ]; then
                width=$w
                height=$h
                break
              fi
            fi
          done
        fi

        # Fallback: ler preferred mode do kernel
        if [ -z "$width" ] && [ -f "${card_dir}modes" ]; then
          local first_mode
          first_mode=$(head -1 "${card_dir}modes" 2>/dev/null)
          if [ -n "$first_mode" ]; then
            width=$(echo "$first_mode" | cut -d'x' -f1)
            height=$(echo "$first_mode" | cut -d'x' -f2 | cut -d' ' -f1)
          fi
        fi

        # Ler refresh rate (maior disponível)
        if [ -z "$refresh" ] && [ -f "${card_dir}modes" ]; then
          local best_refresh="0"
          while IFS= read -r mode_line; do
            local mode_refresh
            mode_refresh=$(echo "$mode_line" | grep -oP '\d+\.\d+' | head -1)
            if [ -n "$mode_refresh" ]; then
              # Comparar floats: usar bc se disponível, senão ignorar decimais
              if command -v bc &>/dev/null; then
                if [ "$(echo "$mode_refresh > $best_refresh" | bc 2>/dev/null)" = "1" ]; then
                  best_refresh="$mode_refresh"
                fi
              else
                # Fallback: pegar o último (geralmente o maior)
                best_refresh="$mode_refresh"
              fi
            fi
          done < "${card_dir}modes"
          [ "$best_refresh" != "0" ] && refresh="$best_refresh"
        fi
      fi
    fi

    [ -n "$width" ] && [ -n "$height" ] && echo "$output ${width}x${height} ${refresh:-60.000}"
  done
}

# Função: calcular escala baseada na resolução vertical
get_scale_for_height() {
  local height="$1"
  if [ "$height" -ge 2160 ]; then
    echo "2.0"
  elif [ "$height" -ge 1440 ]; then
    echo "1.5"
  else
    echo "1.0"
  fi
}

# Detectar monitores
MONITORS_FOUND=$(detect_monitors) || true

if [ -n "$MONITORS_FOUND" ]; then
  info "Monitores detectados:"
  echo "$MONITORS_FOUND" | while read -r line; do
    info "  $line"
  done
  echo ""

  # Gerar blocos output para config.kdl
  NIRI_CONFIG_DIR="$HOME/.config/niri"
  mkdir -p "$NIRI_CONFIG_DIR"
  MONITOR_CONFIG_FILE="$NIRI_CONFIG_DIR/config.kdl"

  # Criar arquivo temporário com os blocos output
  MONITOR_BLOCKS=""
  MAX_HEIGHT=0
  LAST_MONITOR_W=""

  while IFS= read -r line; do
    local_output=$(echo "$line" | awk '{print $1}')
    local_res=$(echo "$line" | awk '{print $2}')
    local_refresh=$(echo "$line" | awk '{print $3}')
    local_width=$(echo "$local_res" | cut -d'x' -f1)
    local_height=$(echo "$local_res" | cut -d'x' -f2)
    local_scale=$(get_scale_for_height "$local_height")

    # Rastrear maior resolução para xsettingsd
    [ "$local_height" -gt "$MAX_HEIGHT" ] && MAX_HEIGHT=$local_height

    # Posição automática: empilhar monitores lado a lado
    local_pos_x=0
    if [ -n "$LAST_MONITOR_W" ]; then
      local_pos_x=$LAST_MONITOR_W
    fi
    LAST_MONITOR_W=$((local_pos_x + local_width))

    MONITOR_BLOCKS="${MONITOR_BLOCKS}output \"${local_output}\" {
    mode \"${local_width}x${local_height}@${local_refresh}\"

    scale ${local_scale}

    transform \"normal\"
    position x=${local_pos_x} y=0
}

"
    info "  ${local_output}: ${local_width}x${local_height} escala ${local_scale}"
  done <<< "$MONITORS_FOUND"

  # Remover blocos output existentes do config.kdl (se existir)
  if [ -f "$MONITOR_CONFIG_FILE" ]; then
    # Usar sed para remover blocos output existentes
    # Remove linhas desde "output \"..." até a próxima "}"
    sed -i '/^output "/,/^}/d' "$MONITOR_CONFIG_FILE"
    # Limpar linhas vazias extras
    sed -i '/^$/N;/^\n$/d' "$MONITOR_CONFIG_FILE"
  fi

  # Adicionar blocos output detectados
  if [ -n "$MONITOR_BLOCKS" ]; then
    echo "" >> "$MONITOR_CONFIG_FILE"
    echo "$MONITOR_BLOCKS" >> "$MONITOR_CONFIG_FILE"
    ok "Blocos output gerados no config.kdl"
  fi

  # Criar ~/.xsettingsd com DPI correto
  XSETTINGSD_SCALE=$(get_scale_for_height "$MAX_HEIGHT")
  XSETTINGSD_DPI=$(python3 -c "print(int(96 * $XSETTINGSD_SCALE))" 2>/dev/null || echo "96")

  cat > "$HOME/.xsettingsd" << XSETEOF
# Auto-gerado pelo install-niri.sh
# Escala detectada: ${XSETTINGSD_SCALE}x (monitor: ${MAX_HEIGHT}p)
Xft/DPI ${XSETTINGSD_DPI}
Xft/Antialias 1
Xft/Hinting 1
Xft/HintStyle hintslight
Xft/rgba rgb
XSETEOF

  ok "~/.xsettingsd criado com DPI ${XSETTINGSD_DPI} (escala ${XSETTINGSD_SCALE}x)"
  info "Isso garante que apps GTK (como Steam) usem a escala correta"
else
  warn "Nenhum monitor detectado."
  info "Os blocos output do config.kdl ficarão como fallback."
  info "Para configurar manualmente, use: bash ~/.config/scripts/monitor-config.sh"
fi
quote

# ──────────────────────────────────────────────
# 6c. Configuração NVIDIA para Wayland
# ──────────────────────────────────────────────
if lspci | grep -qi nvidia; then
  step "🎮 Configurando NVIDIA para Wayland..."

  # Kernel parameters para NVIDIA + Wayland
  if [ -f /etc/default/grub ]; then
    if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
      sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1"/' /etc/default/grub
      sudo grub-mkconfig -o /boot/grub/grub.cfg
      ok "GRUB: nvidia_drm.modeset=1 adicionado"
    else
      info "GRUB já configurado para NVIDIA"
    fi
  fi

  # Modprobe para NVIDIA
  sudo tee /etc/modprobe.d/nvidia.conf > /dev/null <<'EOF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia_drm modeset=1 fbdev=1
EOF
  ok "Modprobe: nvidia.conf configurado"

  # Instalar headers do kernel para compilar módulos NVIDIA
  KERNEL_PKG=$(pacman -Q linux 2>/dev/null | awk '{print $1}')
  if [ -n "$KERNEL_PKG" ]; then
    sudo pacman -S --needed --noconfirm "${KERNEL_PKG}-headers"
    ok "Headers do kernel instalados"
  fi

  # Hooks do initramfs
  sudo tee /etc/mkinitcpio.conf.d/nvidia.conf > /dev/null <<'EOF'
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
  sudo mkinitcpio -P
  ok "Initramfs: módulos NVIDIA incluídos"

  # Variáveis de ambiente para Wayland
  sudo mkdir -p /etc/environment.d
  sudo tee /etc/environment.d/nvidia.conf > /dev/null <<'EOF'
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
EOF
  mkdir -p "$HOME/.config/environment.d"
  cp /etc/environment.d/nvidia.conf "$HOME/.config/environment.d/nvidia.conf"
  ok "Variáveis de ambiente NVIDIA configuradas"

  info "Reinicie para aplicar as mudanças do NVIDIA"
  quote
fi

# ──────────────────────────────────────────────
# 7. SDDM + Astronaut Theme
# ──────────────────────────────────────────────
step "🚀 Configurando SDDM..."

if ! pacman -Qi sddm-astronaut-theme &>/dev/null; then
  info "Instalando tema astronauta..."
  yay -S --needed --noconfirm sddm-astronaut-theme
fi

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<'EOF'
[Theme]
Current=sddm-astronaut-theme
EOF
ok "Tema astronauta definido como padrão"

if [ -n "$PENDRIVE" ] && [ -f "$PENDRIVE/sddm.conf.tar.gz" ]; then
  sudo tar -xzf "$PENDRIVE/sddm.conf.tar.gz" -C /etc/
  info "Configurações do SDDM restauradas do pendrive"
fi
quote

# ──────────────────────────────────────────────
# 8b. Corrigir caminhos absolutos para o usuário atual
# ──────────────────────────────────────────────
step "🔄 Adaptando configs para seu usuário..."
info "Substituindo caminhos absolutos para o usuário atual"
find "$HOME/.config" -type f \( -name "*.json" -o -name "*.conf" -o -name "bookmarks" \) \
  -exec sed -i "s|/home/[^/]*/|$HOME/|g" {} + 2>/dev/null || true
find "$HOME/.config" -type f -name "*.conf" \
  -exec sed -i "s|^color_scheme_path=~|color_scheme_path=$HOME|" {} + 2>/dev/null || true
ok "Caminhos ajustados para $USER"
quote

# ──────────────────────────────────────────────
# 8c. Wrapper gufw (pkexec + xhost + tema escuro)
# ──────────────────────────────────────────────
step "🛡️ Configurando wrapper gufw (tema escuro)..."

mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/gufw" << 'GUFWEOF'
#!/bin/bash
xhost +SI:localuser:root
pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" GTK_THEME="adw-gtk3-dark" /usr/bin/gufw-pkexec "$(whoami)"
GUFWEOF
chmod +x "$HOME/.local/bin/gufw"

# Desktop file override — garante tema escuro no menu de aplicativos
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/gufw.desktop" << GUFWDESKTOP
[Desktop Entry]
Name=Firewall Configuration
Exec=$HOME/.local/bin/gufw
Icon=gufw
Terminal=false
Type=Application
Categories=GNOME;GTK;Settings;Security;
GUFWDESKTOP
ok "gufw wrapper criado (xhost + pkexec + tema escuro)"
quote

# ──────────────────────────────────────────────
# 8d. Variáveis de ambiente para systemd (environment.d)
# ──────────────────────────────────────────────
step "⚡ Configurando variáveis de ambiente para systemd/DBus..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.config/environment.d"

if [ -f "$SCRIPT_DIR/.config/environment.d/01-xdg-base.conf" ]; then
  cp "$SCRIPT_DIR/.config/environment.d/01-xdg-base.conf" "$HOME/.config/environment.d/"
  # Ajusta $HOME para o usuário real
  sed -i "s|\$HOME|$HOME|g" "$HOME/.config/environment.d/01-xdg-base.conf"
  ok "01-xdg-base.conf criado — diretórios XDG"
fi

if [ -f "$SCRIPT_DIR/.config/environment.d/10-kde-on-niri.conf" ]; then
  cp "$SCRIPT_DIR/.config/environment.d/10-kde-on-niri.conf" "$HOME/.config/environment.d/"
  ok "10-kde-on-niri.conf criado — variáveis Qt/KDE para systemd"
fi

info "environment.d é lido pelo systemd --user no login. Essas variáveis"
info "ficam disponíveis para portais, DBus activation e qualquer processo"
info "iniciado pelo systemd."
quote

# ──────────────────────────────────────────────
# 8e. Hook do pacman — reconstruir cache KDE automaticamente
# ──────────────────────────────────────────────
step "⚡ Instalando hook do Pacman para cache KDE..."

if [ -f "$SCRIPT_DIR/etc/pacman.d/hooks/kde-cache.hook" ]; then
  sudo mkdir -p /etc/pacman.d/hooks
  sudo cp "$SCRIPT_DIR/etc/pacman.d/hooks/kde-cache.hook" /etc/pacman.d/hooks/
  ok "Hook instalado — kbuildsycoca6 roda após toda transação do pacman"
  info "Funciona para TODOS os usuários do sistema (usa loginctl + sudo -u)"
  info "com as variáveis XDG_RUNTIME_DIR e DBUS_SESSION_BUS_ADDRESS corretas."
fi
quote

# ──────────────────────────────────────────────
# 8e2. Udisks2 — escrita síncrona para USB
# ──────────────────────────────────────────────
step "💾 Configurando escrita síncrona para USB..."

if [ -f "$SCRIPT_DIR/etc/udisks2/mount_options.conf" ]; then
  sudo mkdir -p /etc/udisks2
  sudo cp "$SCRIPT_DIR/etc/udisks2/mount_options.conf" /etc/udisks2/
  sudo systemctl restart udisks2 2>/dev/null || true
  ok "udisks2 configurado — USBs escrevem direto no disco (sem cache)"
  info "Barra de progresso do Dolphin agora mostra o progresso real"
else
  warn "mount_options.conf não encontrado"
fi
quote

# ──────────────────────────────────────────────
# 8e3. Otimização de I/O e memória para desktop
# ──────────────────────────────────────────────
step "⚡ Otimizando I/O e memória para desktop..."

# I/O Scheduler: NVMe=none, SSD=mq-deadline, HDD=bfq
for disk in /sys/block/nvme*/queue/scheduler /sys/block/sd*/queue/scheduler; do
  [ -f "$disk" ] || continue
  disk_name=$(echo "$disk" | cut -d'/' -f4)

  if echo "$disk_name" | grep -q "^nvme"; then
    echo "none" | sudo tee "$disk" > /dev/null
    echo "  ✔ $disk_name → none (NVMe)"
  elif echo "$disk_name" | grep -q "^sd"; then
    if [ -f "/sys/block/$disk_name/queue/rotational" ]; then
      rotational=$(cat "/sys/block/$disk_name/queue/rotational")
      if [ "$rotational" = "0" ]; then
        echo "mq-deadline" | sudo tee "$disk" > /dev/null
        echo "  ✔ $disk_name → mq-deadline (SSD SATA)"
      else
        echo "bfq" | sudo tee "$disk" > /dev/null
        echo "  ✔ $disk_name → bfq (HDD)"
      fi
    fi
  fi
done

# Dirty pages — flush mais frequente (evita travamento)
sudo sysctl -w vm.dirty_ratio=5 > /dev/null
sudo sysctl -w vm.dirty_background_ratio=2 > /dev/null
sudo sysctl -w vm.dirty_writeback_centisecs=300 > /dev/null
sudo sysctl -w vm.dirty_expire_centisecs=1500 > /dev/null
[ -f /proc/sys/vm/dirty_ratio_bytes ] && sudo sysctl -w vm.dirty_ratio_bytes=134217728 > /dev/null
sudo sysctl -w vm.page-cluster=3 > /dev/null
sudo sysctl -w vm.vfs_cache_pressure=50 > /dev/null

echo "  ✔ dirty_ratio: 5% (era 20%)"
echo "  ✔ dirty_background_ratio: 2% (era 10%)"

# Persistir no boot
sudo tee /etc/sysctl.d/99-desktop-io.conf > /dev/null <<'EOF'
# Otimizações de I/O e memória para desktop
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
vm.dirty_writeback_centisecs = 300
vm.dirty_expire_centisecs = 1500
vm.dirty_ratio_bytes = 134217728
vm.page-cluster = 3
vm.vfs_cache_pressure = 50
EOF

sudo tee /etc/udev/rules.d/60-ioscheduler.rules > /dev/null <<'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF

ok "I/O otimizado — scheduler + dirty pages + cache"
info "Reinicie para aplicar o scheduler nos discos"
quote

# ──────────────────────────────────────────────
# 8e4. Swap — memória virtual
# ──────────────────────────────────────────────
step "🔄 Criando swap de 4GB..."

if swapon --show | grep -q "/swapfile"; then
  info "Swap já existe, ignorando"
else
  sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile

  # Persistir no fstab
  if ! grep -q "^/swapfile" /etc/fstab; then
    echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
  fi

  ok "Swap de 4GB criado e ativado"
  info "Sistema não trava mais com falta de memória"
fi
quote

# ──────────────────────────────────────────────
# 8f. UFW — liberar tráfego do libvirt + Waydroid

if command -v ufw &>/dev/null; then
  # Libera forwarding na bridge virbr0 (NAT das VMs)
  sudo ufw route allow in on virbr0 2>/dev/null || true
  sudo ufw route allow out on virbr0 2>/dev/null || true
  sudo ufw route allow from 192.168.122.0/24 2>/dev/null || true
  sudo ufw route allow to 192.168.122.0/24 2>/dev/null || true

  # Waydroid — DNS, DHCP e forward na waydroid0
  sudo ufw allow 53 2>/dev/null || true
  sudo ufw allow 67 2>/dev/null || true
  sudo ufw route allow in on waydroid0 2>/dev/null || true
  sudo ufw route allow out on waydroid0 2>/dev/null || true

  ok "Regras UFW adicionadas — libvirt e Waydroid com internet"
else
  warn "UFW não encontrado. Se instalar depois, rode:"
  info "  sudo ufw route allow in on virbr0 && sudo ufw route allow out on virbr0"
  info "  sudo ufw allow 53 && sudo ufw allow 67"
  info "  sudo ufw route allow in on waydroid0 && sudo ufw route allow out on waydroid0"
fi
quote

# ──────────────────────────────────────────────
# 8f. Garantir polkit-gnome no config.kdl
# ──────────────────────────────────────────────
step "🔑 Garantindo polkit-gnome no config.kdl..."

CONFIG_KDL="$HOME/.config/niri/config.kdl"
POLKIT_SPAWN='spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"'

if ! grep -qF "$POLKIT_SPAWN" "$CONFIG_KDL" 2>/dev/null; then
  # Adiciona depois da linha do xsettingsd
  sed -i '/spawn-at-startup "xsettingsd"/a\'"$POLKIT_SPAWN" "$CONFIG_KDL"
  ok "polkit-gnome adicionado ao config.kdl"
else
  ok "polkit-gnome já está no config.kdl"
fi
quote

# ──────────────────────────────────────────────
# 9. Ativar serviços
# ──────────────────────────────────────────────
step "⚡ Ativando serviços do sistema..."

info "Bluetooth..."
sudo systemctl enable --now bluetooth || true
ok "Bluetooth ativado"

info "PipeWire (áudio)..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>&1 || true
ok "PipeWire ativado"

info "SDDM (login)..."
sudo systemctl enable sddm 2>&1 || true
ok "SDDM pronto para iniciar"

quote

# ──────────────────────────────────────────────
# 9b. Configurar gerenciamento de energia
# ──────────────────────────────────────────────
step "🔋 Configurando gerenciamento de energia..."

# Desabilitar suspensão automática do systemd-logind
# Em vez de suspender, apenas desliga o monitor após 30 minutos
if [ -f /etc/systemd/logind.conf ]; then
  sudo cp /etc/systemd/logind.conf /etc/systemd/logind.conf.bak 2>/dev/null || true
fi

sudo tee /etc/systemd/logind.conf > /dev/null <<'LOGIND'
[Login]
# Não suspender/hibernar em idle — apenas desligar monitor
IdleAction=ignore
IdleActionSec=infinity
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
LOGIND

ok "systemd-logind configurado: sem suspensão automática"

# Configurar swayidle para desligar monitor após 30 minutos
mkdir -p "$HOME/.config/scripts"

# Criar script de idle management
cat > "$HOME/.config/scripts/swayidle-handler.sh" << 'IDLEEOF'
#!/bin/bash
# Gerenciamento de idle para Niri
# Desliga monitor após 30 minutos de inatividade

TIMEOUT=$((30 * 60))  # 30 minutos em segundos

# Usar swayidle se disponível
if command -v swayidle &>/dev/null; then
  exec swayidle -w \
    timeout "$TIMEOUT" "niri msg output '*' dpms off" \
    resume "niri msg output '*' dpms on"
fi

# Fallback: usar xset (para XWayland)
if command -v xset &>/dev/null; then
  xset s "$TIMEOUT" "$TIMEOUT"
  xset +dpms
  xset dpms 0 0 "$TIMEOUT"
fi
IDLEEOF
chmod +x "$HOME/.config/scripts/swayidle-handler.sh"

# Adicionar spawn-at-startup no config.kdl para swayidle
CONFIG_KDL_POWER="$HOME/.config/niri/config.kdl"
if command -v swayidle &>/dev/null; then
  if ! grep -qF "swayidle-handler" "$CONFIG_KDL_POWER" 2>/dev/null; then
    sed -i '/spawn-at-startup "xsettingsd"/a\spawn-at-startup "~/.config/scripts/swayidle-handler.sh"' "$CONFIG_KDL_POWER"
    ok "swayidle adicionado ao config.kdl (desliga monitor em 30min)"
  else
    ok "swayidle já está no config.kdl"
  fi
else
  warn "swayidle não encontrado. Instale: yay -S swayidle"
  info "Ou configure manualmente o timeout do monitor"
fi

# Configurar GNOME Settings de energia (se gnome-control-center disponível)
if command -v gsettings &>/dev/null; then
  gsettings set org.gnome.desktop.session idle-delay 1800 2>/dev/null || true
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' 2>/dev/null || true
  ok "GNOME power settings configurados (sem suspensão)"
fi

info "Monitor será desligado após 30 minutos de inatividade"
info "Sistema NÃO será suspenso ou hibernado"
quote

# ──────────────────────────────────────────────
# 10. Configurar tema escuro
# ──────────────────────────────────────────────
step "🌙 Aplicando tema escuro..."

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

write_gtk_dark() {
  cat > "$1" << 'EOF'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Ubuntu Bold 12
gtk-application-prefer-dark-theme=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF
}

write_gtk_dark "$HOME/.config/gtk-3.0/settings.ini"
write_gtk_dark "$HOME/.config/gtk-4.0/settings.ini"

command -v nwg-look &>/dev/null && nwg-look -a 2>&1 || true

# Reforça dark theme (nwg-look pode sobrescrever)
write_gtk_dark "$HOME/.config/gtk-3.0/settings.ini"
write_gtk_dark "$HOME/.config/gtk-4.0/settings.ini"

# KDE/Dolphin: forçar Papirus-Dark via kdeglobals
mkdir -p "$HOME/.config"
if [ -f "$HOME/.config/kdeglobals" ]; then
  # Substituir ou adicionar [KDE] IconTheme
  if grep -q "^IconTheme=" "$HOME/.config/kdeglobals"; then
    sed -i 's/^IconTheme=.*/IconTheme=Papirus-Dark/' "$HOME/.config/kdeglobals"
  else
    if grep -q "^\[KDE\]" "$HOME/.config/kdeglobals"; then
      sed -i '/^\[KDE\]/a IconTheme=Papirus-Dark' "$HOME/.config/kdeglobals"
    else
      echo -e "\n[KDE]\nIconTheme=Papirus-Dark" >> "$HOME/.config/kdeglobals"
    fi
  fi
else
  cat > "$HOME/.config/kdeglobals" << 'KDEEOF'
[KDE]
IconTheme=Papirus-Dark
KDEEOF
fi
ok "Dolphin/KDE: Papirus-Dark definido via kdeglobals"

# Garantir que Papirus-Dark está instalado (pacote oficial)
if [ ! -d "$HOME/.local/share/icons/Papirus-Dark" ]; then
  if pacman -Qi papirus-icon-theme &>/dev/null; then
    ok "Papirus-Dark já instalado via pacman"
  else
    warn "Papirus-Dark não encontrado — instale: sudo pacman -S papirus-icon-theme"
  fi
fi

command -v nwg-look &>/dev/null && nwg-look -a > /dev/null 2>&1 || true
ok "Tema escuro aplicado — suave para os olhos"
quote

# ──────────────────────────────────────────────
# 11. Dolphin padrão (xdg-mime)
# ──────────────────────────────────────────────
step "🐬 Definindo Dolphin como gerenciador padrão..."
info "Associando pastas ao Dolphin..."
xdg-mime default org.kde.dolphin.desktop inode/directory
xdg-mime default org.kde.dolphin.desktop x-scheme-handler/trash
ok "Dolphin é o padrão — abrir pasta = Dolphin"
quote

# ──────────────────────────────────────────────
# 12. Ícones
# ──────────────────────────────────────────────
step "🎨 Verificando ícones..."
if pacman -Qi papirus-icon-theme &>/dev/null; then
  ok "Papirus-Dark disponível"
else
  warn "papirus-icon-theme não encontrado — instale: sudo pacman -S papirus-icon-theme"
fi
quote

# ──────────────────────────────────────────────
# 13. xdg-user-dirs
# ──────────────────────────────────────────────
step "📁 Configurando diretórios do usuário..."
info "🔔 Criando Diretórios como Downloads, Documentos, Imagens..."
xdg-user-dirs-update 2>&1 || true
xdg-user-dirs-gtk-update 2>&1 || true
ok "Diretórios criados"


# ──────────────────────────────────────────────
# 14. Final — escolha do usuário
# ──────────────────────────────────────────────
clear 2>/dev/null || true
echo -e "${GREEN}"
echo ' ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗      █████╗  ██████╗ █████╗  ██████╗'
echo ' ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██╔══██╗██╔════╝██╔══██╗██╔══██╗'
echo ' ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ███████║██║     ███████║██║  ██║'
echo ' ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██╔══██║██║     ██╔══██║██║  ██║'
echo ' ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗██║  ██║╚██████╗██║  ██║██████╔╝'
echo ' ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝'
echo -e "${NC}"
echo ""
echo -e "  ${GREEN}✔${NC} Sistema configurado com sucesso! By eusouobn"
echo ""
echo -e "  ${BOLD}O que deseja fazer agora?${NC}"
echo ""
echo -e "  ${CYAN}[1]${NC} Iniciar SDDM agora (tela de login)"
echo -e "  ${CYAN}[2]${NC} Reiniciar o sistema"
echo -e "  ${CYAN}[3]${NC} Sair (voltar ao terminal)"
echo ""
echo -n "  Escolha [1/2/3]: "
read -r choice

case "$choice" in
  1)
    echo ""
    info "Iniciando SDDM..."
    sudo systemctl start sddm
    ;;
  2)
    echo ""
    info "Reiniciando em 5 segundos... Pressione Ctrl+C para cancelar"
    sleep 5
    sudo reboot
    ;;
  *)
    echo ""
    info "Voltando ao terminal. Para iniciar o SDDM manualmente:"
    echo ""
    echo "    sudo systemctl start sddm"
    echo ""
    ;;
esac
