#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════╗
# ║  icons.sh — Gerenciador de ícones global               ║
# ║  Aplica icon theme em GTK3, GTK4, Qt5, Qt6, Dolphin   ║
# ╚══════════════════════════════════════════════════════════╝

# Cores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
info() { echo -e "  ${CYAN}▸${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

# ── Listar icon themes disponíveis ────────────────────────
list_icon_themes() {
  local themes=()

  # /usr/share/icons (pacotes do sistema)
  if [ -d /usr/share/icons ]; then
    for dir in /usr/share/icons/*/; do
      [ -d "$dir" ] || continue
      local name=$(basename "$dir")
      # Pular temas genéricos (cursor, hidpi)
      [[ "$name" == "default" || "$name" == "hicolor" || "$name" == "locolor" ]] && continue
      # Verificar se tem index.theme
      [ -f "${dir}index.theme" ] || continue
      themes+=("$name")
    done
  fi

  # ~/.local/share/icons (usuário)
  if [ -d "$HOME/.local/share/icons" ]; then
    for dir in "$HOME/.local/share/icons"/*/; do
      [ -d "$dir" ] || continue
      local name=$(basename "$dir")
      [[ "$name" == "default" || "$name" == "hicolor" ]] && continue
      [ -f "${dir}index.theme" ] || continue
      # Evitar duplicatas
      local found=0
      for t in "${themes[@]}"; do
        [ "$t" = "$name" ] && found=1 && break
      done
      [ "$found" = "0" ] && themes+=("$name")
    done
  fi

  # Ordenar
  IFS=$'\n' themes=($(sort <<<"${themes[*]}")); unset IFS

  echo "${themes[@]}"
}

# ── Aplicar icon theme ───────────────────────────────────
apply_icon_theme() {
  local theme="$1"

  info "Aplicando ${BOLD}$theme${NC} em todos os toolkits..."

  # GTK3
  mkdir -p "$HOME/.config/gtk-3.0"
  if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$theme/" "$HOME/.config/gtk-3.0/settings.ini"
  else
    cat > "$HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-icon-theme-name=$theme
EOF
  fi
  ok "GTK3: $theme"

  # GTK4
  mkdir -p "$HOME/.config/gtk-4.0"
  if [ -f "$HOME/.config/gtk-4.0/settings.ini" ]; then
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$theme/" "$HOME/.config/gtk-4.0/settings.ini"
  else
    cat > "$HOME/.config/gtk-4.0/settings.ini" << EOF
[Settings]
gtk-icon-theme-name=$theme
EOF
  fi
  ok "GTK4: $theme"

  # Qt5
  if [ -f "$HOME/.config/qt5ct/qt5ct.conf" ]; then
    sed -i "s/^icon_theme=.*/icon_theme=$theme/" "$HOME/.config/qt5ct/qt5ct.conf"
  elif [ -d "$HOME/.config/qt5ct" ]; then
    echo "icon_theme=$theme" >> "$HOME/.config/qt5ct/qt5ct.conf"
  fi
  ok "Qt5: $theme"

  # Qt6
  if [ -f "$HOME/.config/qt6ct/qt6ct.conf" ]; then
    sed -i "s/^icon_theme=.*/icon_theme=$theme/" "$HOME/.config/qt6ct/qt6ct.conf"
  elif [ -d "$HOME/.config/qt6ct" ]; then
    echo "icon_theme=$theme" >> "$HOME/.config/qt6ct/qt6ct.conf"
  fi
  ok "Qt6: $theme"

  # Dolphin/KDE (kdeglobals)
  mkdir -p "$HOME/.config"
  if [ -f "$HOME/.config/kdeglobals" ]; then
    if grep -q "^\[Icons\]" "$HOME/.config/kdeglobals"; then
      if grep -q "^Theme=" "$HOME/.config/kdeglobals"; then
        sed -i "s/^Theme=.*/Theme=$theme/" "$HOME/.config/kdeglobals"
      else
        sed -i "/^\[Icons\]/a Theme=$theme" "$HOME/.config/kdeglobals"
      fi
    else
      echo -e "\n[Icons]\nTheme=$theme" >> "$HOME/.config/kdeglobals"
    fi
  else
    cat > "$HOME/.config/kdeglobals" << EOF
[General]
font=Ubuntu Bold,11,-1,5,50,0,0,0,0,0
fixed=Ubuntu Mono Bold,11,-1,5,50,0,0,0,0,0

[Icons]
Theme=$theme

[KDE]
contrast=4
widgetStyle=qt6ct-style
EOF
  fi
  ok "Dolphin/KDE: $theme"

  # xsettingsd (se existir)
  if [ -f "$HOME/.xsettingsd" ]; then
    if grep -q "^Net/IconThemeName" "$HOME/.xsettingsd"; then
      sed -i "s|^Net/IconThemeName.*|Net/IconThemeName \"$theme\"|" "$HOME/.xsettingsd"
    else
      echo "Net/IconThemeName \"$theme\"" >> "$HOME/.xsettingsd"
    fi
    ok "xsettingsd: $theme"
  fi

  echo ""
  echo -e "  ${GREEN}${BOLD}✔ Icon theme \"$theme\" aplicado globalmente!${NC}"
  echo -e "  ${YELLOW}Reinicie os apps para ver as mudanças${NC}"
}

# ── Mostrar tema atual ───────────────────────────────────
show_current() {
  echo -e "\n  ${BOLD}Icon theme atual:${NC}\n"

  # GTK3
  if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    local gtk3=$(grep "^gtk-icon-theme-name=" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null | cut -d= -f2)
    info "GTK3: ${gtk3:-não configurado}"
  fi

  # GTK4
  if [ -f "$HOME/.config/gtk-4.0/settings.ini" ]; then
    local gtk4=$(grep "^gtk-icon-theme-name=" "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null | cut -d= -f2)
    info "GTK4: ${gtk4:-não configurado}"
  fi

  # Qt5
  if [ -f "$HOME/.config/qt5ct/qt5ct.conf" ]; then
    local qt5=$(grep "^icon_theme=" "$HOME/.config/qt5ct/qt5ct.conf" 2>/dev/null | head -1 | cut -d= -f2)
    info "Qt5:  ${qt5:-não configurado}"
  fi

  # Qt6
  if [ -f "$HOME/.config/qt6ct/qt6ct.conf" ]; then
    local qt6=$(grep "^icon_theme=" "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null | head -1 | cut -d= -f2)
    info "Qt6:  ${qt6:-não configurado}"
  fi

  # Dolphin
  if [ -f "$HOME/.config/kdeglobals" ]; then
    local dolphin=$(grep "^Theme=" "$HOME/.config/kdeglobals" 2>/dev/null | head -1 | cut -d= -f2)
    info "Dolphin: ${dolphin:-não configurado}"
  fi

  echo ""
}

# ── Menu principal ────────────────────────────────────────
clear
echo -e "${BLUE}${BOLD}"
echo "╔══════════════════════════════════════╗"
echo "║    🎨 Gerenciador de Ícones         ║"
echo "║    GTK3 + GTK4 + Qt5 + Qt6 + Dolphin║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

while true; do
  echo -e "  ${BOLD}Opções:${NC}"
  echo "    1) Listar ícones disponíveis"
  echo "    2) Mostrar tema atual"
  echo "    3) Aplicar tema"
  echo "    4) Sair"
  echo ""
  read -rp "  Selecione [1-4]: " opcao

  case $opcao in
    1)
      echo ""
      echo -e "  ${BOLD}Icon themes instalados:${NC}\n"
      themes_array=($(list_icon_themes))
      if [ ${#themes_array[@]} -eq 0 ]; then
        warn "Nenhum icon theme encontrado"
      else
        local idx=1
        for theme in "${themes_array[@]}"; do
          echo "    $idx) $theme"
          ((idx++))
        done
      fi
      echo ""
      ;;
    2)
      show_current
      ;;
    3)
      echo ""
      echo -e "  ${BOLD}Icon themes disponíveis:${NC}\n"
      themes_array=($(list_icon_themes))
      if [ ${#themes_array[@]} -eq 0 ]; then
        warn "Nenhum icon theme encontrado"
        continue
      fi

      local idx=1
      for theme in "${themes_array[@]}"; do
        echo "    $idx) $theme"
        ((idx++))
      done
      echo ""
      read -rp "  Número do tema: " num

      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#themes_array[@]} ]; then
        selected="${themes_array[$((num-1))]}"
        echo ""
        apply_icon_theme "$selected"
      else
        warn "Número inválido"
      fi
      echo ""
      ;;
    4)
      echo -e "\n  👋 Saindo.\n"
      break
      ;;
    *)
      warn "Opção inválida"
      ;;
  esac
done
