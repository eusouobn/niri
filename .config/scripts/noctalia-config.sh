#!/usr/bin/env bash
# noctalia-config.sh — Configuracao interativa do Noctalia (JSON)
set -uo pipefail

NOCTALIA_DIR="${HOME}/.config/noctalia"
CONFIG_FILE="${NOCTALIA_DIR}/settings.json"
ENV_FILE="${HOME}/.config/noctalia/env.conf"
GTK_SETTINGS="${HOME}/.config/gtk-3.0/settings.ini"
GTK4_SETTINGS="${HOME}/.config/gtk-4.0/settings.ini"

R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' B='\033[1;34m'
C='\033[1;36m' M='\033[1;35m' W='\033[1;37m' D='\033[0m'
BD='\033[1m'

header() {
    clear
    echo -e "${M}=======================================${D}"
    echo -e "${W}  ${BD}Noctalia Configurator${D}  — Terminal${D}"
    echo -e "${M}=======================================${D}"
    echo ""
}

info()    { echo -e "  ${G}[+]${D} $*"; }
warn()    { echo -e "  ${Y}[!]${D} $*"; }
err()     { echo -e "  ${R}[x]${D} $*"; }
press_enter() { echo ""; echo -en "  ENTER para voltar..."; read -r; }

ensure_dir() { mkdir -p "$NOCTALIA_DIR"; }

reload_shell() {
    info "Parando Noctalia..."
    # Matar todas as instancias do qs noctalia-shell
    pkill -f "qs -c noctalia-shell" 2>/dev/null
    sleep 1
    # Garantir que morreu
    if pgrep -f "qs -c noctalia-shell" >/dev/null 2>&1; then
        pkill -9 -f "qs -c noctalia-shell" 2>/dev/null
        sleep 0.5
    fi
    # Reiniciar
    niri msg action spawn -- qs -c noctalia-shell &
    disown
    sleep 1
    if pgrep -f "qs -c noctalia-shell" >/dev/null 2>&1; then
        info "Noctalia reiniciado!"
    else
        err "Falha ao reiniciar Noctalia"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  JSON HELPERS (via Python3)
# ══════════════════════════════════════════════════════════════════════════════
json_get() {
    python3 -c "
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
for k in sys.argv[2].split('.'): d = d[k]
print(d)
" "$1" "$2" 2>/dev/null
}

json_set() {
    local file="$1" key="$2" value="$3"
    python3 -c "
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
keys = sys.argv[2].split('.')
ref = d
for k in keys[:-1]:
    ref = ref[k]
val = sys.argv[3]
# Coerce types
if val in ('true', 'false'):
    val = val == 'true'
else:
    try: val = int(val)
    except ValueError:
        try: val = float(val)
        except ValueError: pass
ref[keys[-1]] = val
with open(sys.argv[1], 'w') as f: json.dump(d, f, indent=4)
" "$file" "$key" "$value"
}

do_backup() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local b="${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$b"
        info "Backup: $b"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  SELECAO INTERATIVA
# ══════════════════════════════════════════════════════════════════════════════
pick() {
    local prompt_text="$1"; shift
    local options=("$@")
    _CHOICE=""
    echo ""
    local idx=1
    for opt in "${options[@]}"; do
        echo -e "  ${G}${idx}${D}) ${opt}"
        ((idx++))
    done
    echo ""
    echo -en "  ${C}>${D} ${prompt_text}: "
    read -r _inp
    if [[ "$_inp" =~ ^[0-9]+$ ]] && (( _inp >= 1 && _inp <= ${#options[@]} )); then
        _CHOICE="${options[$((_inp-1))]}"
    else
        _CHOICE="${options[0]}"
    fi
}

pick_num() {
    local prompt_text="$1" default="$2" min="$3" max="$4"
    _CHOICE=""
    echo -en "  ${C}>${D} ${prompt_text} [$default]: "
    read -r _inp
    _inp="${_inp:-$default}"
    if [[ "$_inp" =~ ^[0-9.]+$ ]] && (( $(echo "$_inp >= $min && $_inp <= $max" | bc -l) )); then
        _CHOICE="$_inp"
    else
        _CHOICE="$default"
    fi
}

confirm() {
    echo -en "  ${C}>${D} $1 (s/N): "
    read -r _r
    [[ "$_r" =~ ^[sS]$ ]]
}

# ══════════════════════════════════════════════════════════════════════════════
#  GTK / ENV
# ══════════════════════════════════════════════════════════════════════════════
# Aplicar icon theme globalmente (GTK3+GTK4+Qt5+Qt6+env)
apply_icons_global() {
    local icon_theme="$1"

    # GTK3
    mkdir -p "$(dirname "$GTK_SETTINGS")"
    if [[ -f "$GTK_SETTINGS" ]] && grep -q "gtk-icon-theme-name" "$GTK_SETTINGS" 2>/dev/null; then
        sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=${icon_theme}/" "$GTK_SETTINGS"
    else
        printf "[Settings]\ngtk-icon-theme-name=%s\n" "$icon_theme" > "$GTK_SETTINGS"
    fi

    # GTK4
    mkdir -p "$(dirname "$GTK4_SETTINGS")"
    if [[ -f "$GTK4_SETTINGS" ]] && grep -q "gtk-icon-theme-name" "$GTK4_SETTINGS" 2>/dev/null; then
        sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=${icon_theme}/" "$GTK4_SETTINGS"
    else
        printf "[Settings]\ngtk-icon-theme-name=%s\n" "$icon_theme" > "$GTK4_SETTINGS"
    fi

    # Qt5
    local qt5_conf="${HOME}/.config/qt5ct/qt5ct.conf"
    mkdir -p "$(dirname "$qt5_conf")"
    if [[ -f "$qt5_conf" ]] && grep -q "icon_theme" "$qt5_conf" 2>/dev/null; then
        python3 -c "
import sys, re
lines = open(sys.argv[1]).readlines()
with open(sys.argv[1], 'w') as f:
    for l in lines:
        if re.match(r'^icon_theme\s*=', l):
            f.write('icon_theme = ' + sys.argv[2] + '\n')
        else:
            f.write(l)
" "$qt5_conf" "$icon_theme"
    else
        echo "icon_theme = ${icon_theme}" >> "$qt5_conf"
    fi
    info "Qt5 icon: $icon_theme"

    # Qt6
    local qt6_conf="${HOME}/.config/qt6ct/qt6ct.conf"
    mkdir -p "$(dirname "$qt6_conf")"
    if [[ -f "$qt6_conf" ]] && grep -q "icon_theme" "$qt6_conf" 2>/dev/null; then
        python3 -c "
import sys, re
lines = open(sys.argv[1]).readlines()
with open(sys.argv[1], 'w') as f:
    for l in lines:
        if re.match(r'^icon_theme\s*=', l):
            f.write('icon_theme = ' + sys.argv[2] + '\n')
        else:
            f.write(l)
" "$qt6_conf" "$icon_theme"
    else
        echo "icon_theme = ${icon_theme}" >> "$qt6_conf"
    fi
    info "Qt6 icon: $icon_theme"

    # Env vars
    ensure_dir
    cat > "$ENV_FILE" << ENV
# Noctalia — Variaveis de ambiente
export XCURSOR_SIZE=24
export ICON_THEME="${icon_theme}"
export QT_QPA_PLATFORMTHEME=qt6ct
ENV

    info "Icon global: $icon_theme (GTK3+GTK4+Qt5+Qt6)"
}

# Aplicar appearance completo (tema + ícones + fonte) em GTK3+GTK4+Qt5+Qt6+Dolphin+env+Firefox
apply_gtk_appearance() {
    local theme="$1" icon_theme="$2" font="$3" font_size="${4:-12}" qt_theme="${5:-}"

    # GTK3
    mkdir -p "$(dirname "$GTK_SETTINGS")"
    cat > "$GTK_SETTINGS" << EOF
[Settings]
gtk-theme-name=${theme}
gtk-icon-theme-name=${icon_theme}
gtk-font-name=${font} ${font_size}
gtk-application-prefer-dark-theme=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF
    ok "GTK3: tema=${theme} ícones=${icon_theme} fonte=${font}"

    # GTK4
    mkdir -p "$(dirname "$GTK4_SETTINGS")"
    cat > "$GTK4_SETTINGS" << EOF
[Settings]
gtk-theme-name=${theme}
gtk-icon-theme-name=${icon_theme}
gtk-font-name=${font} ${font_size}
gtk-application-prefer-dark-theme=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF
    ok "GTK4: tema=${theme} ícones=${icon_theme} fonte=${font}"

    # Qt5
    local qt5_conf="${HOME}/.config/qt5ct/qt5ct.conf"
    mkdir -p "$(dirname "$qt5_conf")"
    if [[ -f "$qt5_conf" ]]; then
        [[ -n "$qt_theme" ]] && sed -i "s/^style\s*=.*/style = ${qt_theme}/" "$qt5_conf" 2>/dev/null
        sed -i "s/^icon_theme\s*=.*/icon_theme = ${icon_theme}/" "$qt5_conf" 2>/dev/null
    else
        {
            echo "[Appearance]"
            [[ -n "$qt_theme" ]] && echo "style = ${qt_theme}"
            echo "icon_theme = ${icon_theme}"
        } > "$qt5_conf"
    fi
    ok "Qt5: tema=${qt_theme:-padrão} ícones=${icon_theme}"

    # Qt6
    local qt6_conf="${HOME}/.config/qt6ct/qt6ct.conf"
    mkdir -p "$(dirname "$qt6_conf")"
    if [[ -f "$qt6_conf" ]]; then
        [[ -n "$qt_theme" ]] && sed -i "s/^style\s*=.*/style = ${qt_theme}/" "$qt6_conf" 2>/dev/null
        sed -i "s/^icon_theme\s*=.*/icon_theme = ${icon_theme}/" "$qt6_conf" 2>/dev/null
    else
        {
            echo "[Appearance]"
            [[ -n "$qt_theme" ]] && echo "style = ${qt_theme}"
            echo "icon_theme = ${icon_theme}"
        } > "$qt6_conf"
    fi
    ok "Qt6: tema=${qt_theme:-padrão} ícones=${icon_theme}"

    # Dolphin/KDE (kdeglobals)
    mkdir -p "$HOME/.config"
    if [[ -f "$HOME/.config/kdeglobals" ]]; then
        if grep -q "^\[Icons\]" "$HOME/.config/kdeglobals"; then
            if grep -q "^Theme=" "$HOME/.config/kdeglobals"; then
                sed -i "s/^Theme=.*/Theme=${icon_theme}/" "$HOME/.config/kdeglobals"
            else
                sed -i "/^\[Icons\]/a Theme=${icon_theme}" "$HOME/.config/kdeglobals"
            fi
        else
            echo -e "\n[Icons]\nTheme=${icon_theme}" >> "$HOME/.config/kdeglobals"
        fi
    else
        cat > "$HOME/.config/kdeglobals" << EOF
[Icons]
Theme=${icon_theme}
EOF
    fi
    ok "Dolphin: ${icon_theme}"

    # environment.d (GTK_THEME)
    local env_d="${HOME}/.config/environment.d/10-kde-on-niri.conf"
    mkdir -p "$(dirname "$env_d")"
    if [[ -f "$env_d" ]]; then
        if grep -q "^GTK_THEME=" "$env_d" 2>/dev/null; then
            sed -i "s/^GTK_THEME=.*/GTK_THEME=${theme}/" "$env_d"
        else
            echo "GTK_THEME=${theme}" >> "$env_d"
        fi
    else
        echo "GTK_THEME=${theme}" > "$env_d"
    fi
    ok "environment.d: GTK_THEME=${theme}"

    # Firefox — force dark theme via user.js
    local ff_dir="${HOME}/.mozilla/firefox"
    if [[ -d "$ff_dir" ]]; then
        local ff_profile
        ff_profile=$(grep -l "Default" "$ff_dir/profiles.ini" 2>/dev/null | head -1)
        if [[ -n "$ff_profile" ]]; then
            local ff_userjs="${ff_profile%/*}/user.js"
        else
            ff_userjs=$(find "$ff_dir" -maxdepth 2 -name "prefs.js" 2>/dev/null | head -1)
            [[ -n "$ff_userjs" ]] && ff_userjs="${ff_userjs%/*}/user.js"
        fi
        if [[ -n "$ff_userjs" && -d "$(dirname "$ff_userjs")" ]]; then
            # Remover config anterior se existir
            [[ -f "$ff_userjs" ]] && sed -i '/user_pref("ui.systemUsesDarkTheme"/d' "$ff_userjs"
            [[ -f "$ff_userjs" ]] && sed -i '/user_pref("widget.content gtk-theme-override"/d' "$ff_userjs"
            cat >> "$ff_userjs" << FFEOF
// Forçado por noctalia-config.sh
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("widget.content gtk-theme-override", "${theme}");
FFEOF
            ok "Firefox: dark mode + tema GTK"
        fi
    fi
}

apply_env_vars() {
    local icon_th="$1" cursor_th="$2"
    ensure_dir
    cat > "$ENV_FILE" << ENV
# Noctalia — Variaveis de ambiente (source no hyprland.conf)
export XCURSOR_THEME="${cursor_th}"
export XCURSOR_SIZE=24
export ICON_THEME="${icon_th}"
export QT_QPA_PLATFORMTHEME=qt6ct
ENV
    info "Env salvo: $ENV_FILE"
}

# ══════════════════════════════════════════════════════════════════════════════
#  LISTAS
# ══════════════════════════════════════════════════════════════════════════════
FONTS_LIST=(
    "Ubuntu" "Ubuntu Bold" "Ubuntu Sans" "Ubuntu Sans Nerd Font"
    "Ubuntu Mono" "Ubuntu Mono Nerd Font"
    "sans-serif" "Inter" "JetBrains Mono"
    "JetBrains Mono Nerd Font" "Fira Code" "FiraCode Nerd Font"
    "Cascadia Code" "Cascadia Code Nerd Font"
    "0xProto Nerd Font" "Fantasque Sans Mono Nerd Font"
    "Space Mono Nerd Font" "Iosevka Nerd Font"
    "MesloLGS NF" "Maple Mono NF"
    "Source Code Pro" "Hack Nerd Font"
    "Overpass" "Geist Mono"
)

THEMES_LIST=(
    "Noctalia" "Catppuccin" "Dracula" "Gruvbox"
    "Nord" "Tokyo-Night" "Ayu" "Eldritch"
    "Kanagawa" "Rose Pine"
)

GTK_THEMES_LIST=(
    "adw-gtk3-dark" "adw-gtk3-light"
    "Orchis-Dark" "Orchis-Light"
    "Colloid-Dark" "Colloid-Light"
    "Catppuccin-Mocha-Standard-Dark" "Catppuccin-Mocha-Standard-Lite"
    "Dracula" "Nordic-Darker" "Tokyonight-Dark-BL"
)

QT_THEMES_LIST=(
    "adwaita-dark" "adwaita-light"
    "kvantum-dark" "kvantum"
    "breeze-dark" "breeze"
)

WEIGHT_LIST=(
    "Regular (padrao)"
    "Medium"
    "Semibold"
    "Bold"
    "Extrabold"
)

weight_to_pango() {
    case "$1" in
        *Medium*)   echo "medium" ;;
        *Semibold*) echo "semibold" ;;
        *Bold*)     echo "bold" ;;
        *Extrabold*) echo "ultrabold" ;;
        *)          echo "normal" ;;
    esac
}

# Mapear peso para valor Qt (weight qtct)
weight_to_qt() {
    case "$1" in
        400)          echo "50" ;;
        500)          echo "57" ;;
        600)          echo "63" ;;
        700)          echo "75" ;;
        800)          echo "81" ;;
        *Medium*)     echo "57" ;;
        *Semibold*)   echo "63" ;;
        *Bold*)       echo "75" ;;
        *Extrabold*)  echo "81" ;;
        *)            echo "50" ;;
    esac
}

# Mapeamento fonte proporcional -> mono equivalente
mono_map() {
    case "$1" in
        *Ubuntu*|Ubuntu*)       echo "Ubuntu Mono" ;;
        *Inter*|Inter*)         echo "JetBrains Mono" ;;
        *Overpass*|Overpass*)   echo "Source Code Pro" ;;
        *Fira*Sans*)            echo "Fira Code" ;;
        *Geist*)                echo "Geist Mono" ;;
        *Maple*)                echo "Maple Mono NF" ;;
        *Meslo*)                echo "MesloLGS NF" ;;
        *Space*)                echo "Space Mono Nerd Font" ;;
        *Fantasque*)            echo "Fantasque Sans Mono Nerd Font" ;;
        *Cascadia*|*Fira*Code*|*0xProto*|*Hack*|*Iosevka*|*Source*Code*|*JetBrains*|*Maple*|*Meslo*|*Space*Mono*|*mono*|*Mono*|*Nerd*)
                                echo "$1" ;;
        *)                      echo "monospace" ;;
    esac
}

# Aplicar fonte globalmente (GTK3+GTK4+Qt5+Qt6+fontconfig+Noctalia)
apply_font_global() {
    local font="$1" weight_pango="$2" font_size="${3:-12}"
    local mono_font
    mono_font=$(mono_map "$font")

    # Noctalia JSON
    if [[ -f "$CONFIG_FILE" ]]; then
        json_set "$CONFIG_FILE" "ui.fontDefault" "$font"
    fi

    # GTK3
    mkdir -p "$(dirname "$GTK_SETTINGS")"
    if [[ -f "$GTK_SETTINGS" ]] && grep -q "gtk-font-name" "$GTK_SETTINGS" 2>/dev/null; then
        sed -i "s/^gtk-font-name=.*/gtk-font-name=${font} ${font_size}/" "$GTK_SETTINGS"
    else
        printf "[Settings]\ngtk-font-name=%s %s\n" "$font" "$font_size" > "$GTK_SETTINGS"
    fi

    # GTK4
    mkdir -p "$(dirname "$GTK4_SETTINGS")"
    if [[ -f "$GTK4_SETTINGS" ]] && grep -q "gtk-font-name" "$GTK4_SETTINGS" 2>/dev/null; then
        sed -i "s/^gtk-font-name=.*/gtk-font-name=${font} ${font_size}/" "$GTK4_SETTINGS"
    else
        printf "[Settings]\ngtk-font-name=%s %s\n" "$font" "$font_size" > "$GTK4_SETTINGS"
    fi

    # Qt5
    local qt5_conf="${HOME}/.config/qt5ct/qt5ct.conf"
    if [[ -f "$qt5_conf" ]]; then
        local qt_weight
        qt_weight=$(weight_to_qt "$weight_pango")
        local qt5_general="\"${font},${font_size},-1,5,${qt_weight},0,0,0,0,0\""
        local qt5_fixed="\"${mono_font},${font_size},-1,5,${qt_weight},0,0,0,0,0\""
        python3 -c "
import sys, re
lines = open(sys.argv[1]).readlines()
with open(sys.argv[1], 'w') as f:
    for l in lines:
        if re.match(r'^general\s*=', l):
            f.write('general = ' + sys.argv[2] + '\n')
        elif re.match(r'^fixed\s*=', l):
            f.write('fixed = ' + sys.argv[3] + '\n')
        else:
            f.write(l)
" "$qt5_conf" "$qt5_general" "$qt5_fixed"
        info "Qt5 fonte: $font ($qt_weight)"
    fi

    # Qt6
    local qt6_conf="${HOME}/.config/qt6ct/qt6ct.conf"
    if [[ -f "$qt6_conf" ]]; then
        local qt_weight
        qt_weight=$(weight_to_qt "$weight_pango")
        local qt6_general="\"${font},${font_size},-1,5,${qt_weight},0,0,0,0,0,0,0,0,0,0,1,,0,0\""
        local qt6_fixed="\"${mono_font},${font_size},-1,5,${qt_weight},0,0,0,0,0,0,0,0,0,0,1,,0,0\""
        python3 -c "
import sys, re
lines = open(sys.argv[1]).readlines()
with open(sys.argv[1], 'w') as f:
    for l in lines:
        if re.match(r'^general\s*=', l):
            f.write('general = ' + sys.argv[2] + '\n')
        elif re.match(r'^fixed\s*=', l):
            f.write('fixed = ' + sys.argv[3] + '\n')
        else:
            f.write(l)
" "$qt6_conf" "$qt6_general" "$qt6_fixed"
        info "Qt6 fonte: $font ($qt_weight)"
    fi

    # Fontconfig (peso)
    apply_font_weight "$font" "$weight_pango"

    info "Fonte global: $font (mono: $mono_font)"
}

ICONS_LIST=(
    "Papirus" "Papirus-Dark" "Papirus-Light"
    "Tela" "Tela-dark" "Tela-light"
    "Colloid" "Colloid-dark" "Colloid-light"
    "Kana" "Kana-dark" "Breeze" "Breeze-Dark"
    "Numix" "Surfn" "Yaru"
)

CURSORS_LIST=(
    "Bibata-Modern-Ice" "Bibata-Modern-Classic"
    "Bibata-Original-Classic" "Oreo-White" "Oreo-Black"
    "Catppuccin-Mocha-Teal" "Catppuccin-Mocha-Blue"
    "Phinger-cursors" "WhiteSur" "Breeze" "Adwaita"
)

apply_font_weight() {
    local font_family="$1"
    local weight_pango="$2"
    local fc_dir="${HOME}/.config/fontconfig"
    mkdir -p "$fc_dir"

    cat > "${fc_dir}/fonts.conf" << FC
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>${font_family}</family>
    <prefer>
      <font>
        <family>${font_family}</family>
        <weight>${weight_pango}</weight>
      </font>
    </prefer>
  </alias>

  <!-- Forcar bold em todos os apps GTK -->
  <match target="font">
    <test name="family" compare="contains">
      <string>${font_family}</string>
    </test>
    <edit name="weight" mode="assign" binding="strong">
      <const>${weight_pango}</const>
    </edit>
  </match>
</fontconfig>
FC

    fc-cache -f 2>/dev/null
    info "Fontconfig atualizado: ${font_family} weight=${weight_pango}"
}

# ══════════════════════════════════════════════════════════════════════════════
#  MENUS
# ══════════════════════════════════════════════════════════════════════════════

maybe_reload() {
    echo ""
    if confirm "Recarregar shell agora?"; then
        reload_shell
    else
        info "Pressione 'r' no menu principal para recarregar."
    fi
}

menu_font() {
    header
    echo -e "${W}${BD}  FONTES DISPONIVEIS:${D}"
    pick "Selecione a fonte" "${FONTS_LIST[@]}"
    local font="$_CHOICE"
    info "Fonte: $font"

    echo ""
    echo -e "${W}${BD}  PESO DA FONTE:${D}"
    pick "Peso" "${WEIGHT_LIST[@]}"
    local weight="$_CHOICE"
    local weight_pango=$(weight_to_pango "$weight")
    info "Peso: $weight ($weight_pango)"

    ensure_dir
    do_backup
    apply_font_global "$font" "$weight_pango"
    maybe_reload
}

menu_theme() {
    header
    echo -e "${W}${BD}  COLOR SCHEMES:${D}"
    pick "Selecione o scheme" "${THEMES_LIST[@]}"
    local th="$_CHOICE"
    info "Scheme: $th"
    ensure_dir
    do_backup
    json_set "$CONFIG_FILE" "colorSchemes.predefinedScheme" "$th"
    info "Scheme atualizado!"
    maybe_reload
}

menu_theme_mode() {
    header
    echo -e "${W}${BD}  MODO DO TEMA:${D}"
    pick "Modo" "dark" "light" "auto"
    local mode="$_CHOICE"
    info "Modo: $mode"
    ensure_dir
    do_backup
    if [[ "$mode" == "dark" ]]; then
        json_set "$CONFIG_FILE" "colorSchemes.darkMode" "true"
    else
        json_set "$CONFIG_FILE" "colorSchemes.darkMode" "false"
    fi
    info "Modo atualizado!"
    maybe_reload
}

menu_wallpaper() {
    header
    echo -e "${W}${BD}  DIRETORIO DE WALLPAPERS:${D}"
    echo ""
    echo -e "  ${G}1${D}) ~/Pictures/Wallpapers"
    echo -e "  ${G}2${D}) ~/Pictures/wallpapers"
    echo -e "  ${G}3${D}) ~/Wallpapers"
    echo -e "  ${G}4${D}) ~/Pictures"
    echo -e "  ${G}5${D}) Customizado..."
    echo ""
    echo -en "  ${C}>${D} Selecione (1-5): "
    read -r _wchoice
    local wdir
    case "${_wchoice:-1}" in
        2) wdir="~/Pictures/wallpapers" ;;
        3) wdir="~/Wallpapers" ;;
        4) wdir="~/Pictures" ;;
        5) echo -en "  ${C}>${D} Caminho: "; read -r wdir ;;
        *) wdir="~/Pictures/Wallpapers" ;;
    esac
    info "Wallpaper dir: $wdir"
    ensure_dir
    do_backup
    json_set "$CONFIG_FILE" "wallpaper.directory" "$wdir"
    info "Wallpaper dir atualizado!"
    maybe_reload
}

menu_corner() {
    header
    echo -e "${W}${BD}  ARREDONDAMENTO DOS CANTOS:${D}"
    pick "Raio" "1.0  (padrao)" "0.0  (quadrado)" "0.5  (leve)" "1.5  (mais)" "2.0  (extra)"
    local cr=$(echo "$_CHOICE" | grep -oP '^[0-9.]+')
    info "Raio: $cr"
    ensure_dir
    do_backup
    json_set "$CONFIG_FILE" "general.radiusRatio" "$cr"
    info "Raio atualizado!"
    maybe_reload
}

menu_anim() {
    header
    echo -e "${W}${BD}  ANIMACOES:${D}"
    pick "Velocidade" "1.0  (padrao)" "0.5  (lento)" "0.75 (moderado)" "1.5  (rapido)" "2.0  (extra rapido)" "Desligar animacoes"
    if [[ "$_CHOICE" == "Desligar animacoes" ]]; then
        ensure_dir
        do_backup
        json_set "$CONFIG_FILE" "general.animationDisabled" "true"
        info "Animacoes desligadas!"
    else
        local spd=$(echo "$_CHOICE" | grep -oP '^[0-9.]+')
        info "Velocidade: $spd"
        ensure_dir
        do_backup
        json_set "$CONFIG_FILE" "general.animationDisabled" "false"
        json_set "$CONFIG_FILE" "general.animationSpeed" "$spd"
        info "Animacao: $spd"
    fi
    maybe_reload
}

menu_transparency() {
    header
    echo -e "${W}${BD}  TRANSPARENCIA DOS PAINEIS:${D}"
    pick "Modo" "solid  (opaco)" "soft   (leve)" "glass  (vidro)"
    local tr=$(echo "$_CHOICE" | awk '{print $1}')
    local opacity
    case "$tr" in
        solid) opacity="1.0" ;;
        soft)  opacity="0.85" ;;
        glass) opacity="0.6" ;;
        *)     opacity="1.0" ;;
    esac
    info "Transparencia: $tr ($opacity)"
    ensure_dir
    do_backup
    json_set "$CONFIG_FILE" "bar.backgroundOpacity" "$opacity"
    json_set "$CONFIG_FILE" "ui.panelBackgroundOpacity" "$opacity"
    info "Transparencia atualizada!"
    maybe_reload
}

menu_icon_theme() {
    header
    echo -e "${W}${BD}  ICON THEMES:${D}"
    pick "Selecione" "${ICONS_LIST[@]}"
    ensure_dir
    do_backup
    apply_icons_global "$_CHOICE"
    maybe_reload
}

menu_appearance() {
    header
    echo -e "${W}${BD}  APPEARANCE (TEMAS + ÍCONES + FONTE)${D}"
    echo ""

    echo -e "${W}${BD}  TEMA GTK:${D}"
    pick "Tema" "${GTK_THEMES_LIST[@]}"
    local theme="$_CHOICE"
    info "Tema: $theme"

    echo ""
    echo -e "${W}${BD}  TEMA QT (Dolphin, qBittorrent, etc):${D}"
    pick "Tema Qt" "${QT_THEMES_LIST[@]}"
    local qt_theme="$_CHOICE"
    info "Tema Qt: $qt_theme"

    echo ""
    echo -e "${W}${BD}  ICON THEME:${D}"
    pick "Ícones" "${ICONS_LIST[@]}"
    local icons="$_CHOICE"
    info "Ícones: $icons"

    echo ""
    echo -e "${W}${BD}  FONTE:${D}"
    pick "Fonte" "${FONTS_LIST[@]}"
    local font="$_CHOICE"
    info "Fonte: $font"

    echo ""
    echo -e "${W}${BD}  TAMANHO DA FONTE:${D}"
    pick_num "Tamanho" "12" "8" "24"
    local size="$_CHOICE"
    info "Tamanho: $size"

    echo ""
    echo -e "${W}${BD}  RESUMO:${D}"
    echo ""
    echo -e "  Tema GTK:   ${G}${theme}${D}"
    echo -e "  Tema Qt:    ${G}${qt_theme}${D}"
    echo -e "  Ícones:     ${G}${icons}${D}"
    echo -e "  Fonte:      ${G}${font}${D}"
    echo -e "  Tamanho:    ${G}${size}${D}"
    echo ""

    if confirm "Aplicar appearance?"; then
        ensure_dir
        do_backup
        apply_gtk_appearance "$theme" "$icons" "$font" "$size" "$qt_theme"
        echo ""
        info "Appearance aplicado!"
        maybe_reload
    fi
}

menu_cursor() {
    header
    echo -e "${W}${BD}  CURSOR THEMES:${D}"
    pick "Selecione" "${CURSORS_LIST[@]}"
    ensure_dir
    local current_icon=""
    [[ -f "$ENV_FILE" ]] && current_icon=$(grep "^export ICON_THEME=" "$ENV_FILE" 2>/dev/null | cut -d= -f2)
    cat > "$ENV_FILE" << ENV
# Noctalia — Variaveis de ambiente
export XCURSOR_THEME="${_CHOICE}"
export XCURSOR_SIZE=24
export ICON_THEME="${current_icon}"
export QT_QPA_PLATFORMTHEME=qt6ct
ENV
    info "Cursor: $_CHOICE"
    maybe_reload
}

# ── Status ──────────────────────────────────────────────────────────────────────
menu_status() {
    header
    echo -e "${W}${BD}  STATUS ATUAL:${D}"
    echo ""
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "  ${G}Config:${D} $CONFIG_FILE"
        echo -e "  Fonte Noctalia: ${C}$(json_get "$CONFIG_FILE" "ui.fontDefault")${D}"
    fi
    if [[ -f "$GTK_SETTINGS" ]]; then
        local gt=$(grep "^gtk-theme-name" "$GTK_SETTINGS" 2>/dev/null | cut -d= -f2)
        local gf=$(grep "^gtk-font-name" "$GTK_SETTINGS" 2>/dev/null | cut -d= -f2)
        local gi=$(grep "^gtk-icon-theme-name" "$GTK_SETTINGS" 2>/dev/null | cut -d= -f2)
        [[ -n "$gt" ]] && echo -e "  Tema GTK:       ${C}${gt}${D}"
        [[ -n "$gf" ]] && echo -e "  Fonte GTK:      ${C}${gf}${D}"
        [[ -n "$gi" ]] && echo -e "  Icon GTK:       ${C}${gi}${D}"
    fi
    local qt5_conf="${HOME}/.config/qt5ct/qt5ct.conf"
    if [[ -f "$qt5_conf" ]]; then
        local qf=$(grep "^general=" "$qt5_conf" 2>/dev/null | head -1 | sed 's/^general=//' | tr -d '"')
        local qi=$(grep "^icon_theme=" "$qt5_conf" 2>/dev/null | head -1 | sed 's/^icon_theme=//')
        [[ -n "$qf" ]] && echo -e "  Fonte Qt5:      ${C}${qf}${D}"
        [[ -n "$qi" ]] && echo -e "  Icon Qt5:       ${C}${qi}${D}"
    fi
    local qt6_conf="${HOME}/.config/qt6ct/qt6ct.conf"
    if [[ -f "$qt6_conf" ]]; then
        local qf6=$(grep "^general=" "$qt6_conf" 2>/dev/null | head -1 | sed 's/^general=//' | tr -d '"')
        local qi6=$(grep "^icon_theme=" "$qt6_conf" 2>/dev/null | head -1 | sed 's/^icon_theme=//')
        [[ -n "$qf6" ]] && echo -e "  Fonte Qt6:      ${C}${qf6}${D}"
        [[ -n "$qi6" ]] && echo -e "  Icon Qt6:       ${C}${qi6}${D}"
    fi
    if [[ -f "$CONFIG_FILE" ]]; then
        local dm=$(json_get "$CONFIG_FILE" "colorSchemes.darkMode")
        [[ "$dm" == "True" || "$dm" == "true" ]] && dm="dark" || dm="light"
        echo -e "  Modo tema:      ${C}${dm}${D}"
        echo -e "  Scheme:         ${C}$(json_get "$CONFIG_FILE" "colorSchemes.predefinedScheme")${D}"
        echo -e "  Wallpaper dir:  ${C}$(json_get "$CONFIG_FILE" "wallpaper.directory")${D}"
        echo -e "  Raio cantos:    ${C}$(json_get "$CONFIG_FILE" "general.radiusRatio")${D}"
        echo -e "  Vel anim:       ${C}$(json_get "$CONFIG_FILE" "general.animationSpeed")${D}"
        local ad=$(json_get "$CONFIG_FILE" "general.animationDisabled")
        [[ "$ad" == "True" || "$ad" == "true" ]] && echo -e "  Animacoes:      ${R}desligadas${D}"
        echo -e "  Transparencia:  ${C}$(json_get "$CONFIG_FILE" "bar.backgroundOpacity")${D}"
        echo -e "  Barra:          ${C}$(json_get "$CONFIG_FILE" "bar.position")${D}"
        echo -e "  Dock:           ${C}$(json_get "$CONFIG_FILE" "dock.enabled")${D}"
    else
        warn "Config nao encontrado: $CONFIG_FILE"
    fi
    if [[ -f "$ENV_FILE" ]]; then
        local cur=$(grep "XCURSOR_THEME" "$ENV_FILE" 2>/dev/null | cut -d= -f2 | tr -d '"')
        [[ -n "$cur" ]] && echo -e "  Cursor:         ${C}${cur}${D}"
    fi
    local fc_weight=$(grep -A2 'family>' "${HOME}/.config/fontconfig/fonts.conf" 2>/dev/null | grep 'weight>' | head -1 | sed 's/.*<weight>//' | sed 's/<.*//' || echo "normal")
    [[ -n "$fc_weight" ]] && echo -e "  Peso fonte:     ${C}${fc_weight}${D}"
    press_enter
}

menu_export() {
    header
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${W}${BD}  CONTEUDO DO CONFIG:${D}"
        echo ""
        cat "$CONFIG_FILE"
    else
        warn "Config nao encontrado"
    fi
    press_enter
}

# ══════════════════════════════════════════════════════════════════════════════
#  SETUP COMPLETO
# ══════════════════════════════════════════════════════════════════════════════
menu_full_setup() {
    header
    echo -e "${W}${BD}  CONFIGURACAO COMPLETA${D}"
    echo ""
    echo -en "  ENTER para comecar..."; read -r

    header; echo -e "${W}${BD}  PASSO 1/8 — FONTE${D}"
    pick "Fonte" "${FONTS_LIST[@]}"; local font="$_CHOICE"
    info "Fonte: $font"; sleep 0.3

    header; echo -e "${W}${BD}  PASSO 2/8 — PESO DA FONTE${D}"
    pick "Peso" "${WEIGHT_LIST[@]}"
    local weight="$_CHOICE"
    local fw=$(weight_to_pango "$weight")
    info "Peso: $weight ($fw)"; sleep 0.3

    header; echo -e "${W}${BD}  PASSO 3/8 — MODO DO TEMA${D}"
    pick "Modo" "dark" "light" "auto"; local tmode="$_CHOICE"
    info "Modo: $tmode"; sleep 0.3

    header; echo -e "${W}${BD}  PASSO 4/8 — COLOR SCHEME${D}"
    pick "Scheme" "${THEMES_LIST[@]}"; local tbuiltin="$_CHOICE"
    info "Scheme: $tbuiltin"; sleep 0.3

    header; echo -e "${W}${BD}  PASSO 5/8 — DIRETORIO DE WALLPAPER${D}"
    pick "Diretorio" "~/Pictures/Wallpapers" "~/Pictures/wallpapers" "~/Wallpapers" "~/Pictures"
    local wdir="$_CHOICE"
    info "Dir: $wdir"; sleep 0.3

    header; echo -e "${W}${BD}  PASSO 6/8 — ARREDONDAMENTO DOS CANTOS${D}"
    pick "Raio" "1.0  (padrao)" "0.0  (quadrado)" "0.5  (leve)" "1.5  (mais)" "2.0  (extra)"
    local cr=$(echo "$_CHOICE" | grep -oP '^[0-9.]+')
    info "Raio: $cr"; sleep 0.3

    header; echo -e "${W}${BD}  PASSO 7/8 — VELOCIDADE DAS ANIMACOES${D}"
    pick "Velocidade" "1.0  (padrao)" "0.5  (lento)" "0.75 (moderado)" "1.5  (rapido)" "2.0  (extra rapido)"
    local asp=$(echo "$_CHOICE" | grep -oP '^[0-9.]+')
    info "Velocidade: $asp"; sleep 0.3

    header; echo -e "${W}${BD}  PASSO 8/8 — TRANSPARENCIA${D}"
    pick "Modo" "soft  (leve)" "solid (opaco)" "glass (vidro)"
    local trans=$(echo "$_CHOICE" | awk '{print $1}')
    local opacity
    case "$trans" in
        solid) opacity="1.0" ;;
        soft)  opacity="0.85" ;;
        glass) opacity="0.6" ;;
        *)     opacity="1.0" ;;
    esac
    info "Transparencia: $trans ($opacity)"; sleep 0.3

    # Resumo
    header
    echo -e "${W}${BD}  RESUMO:${D}"
    echo ""
    echo -e "  Fonte:            ${G}${font}${D}"
    echo -e "  Peso:             ${G}${weight} (${fw})${D}"
    echo -e "  Modo tema:        ${G}${tmode}${D}"
    echo -e "  Color scheme:     ${G}${tbuiltin}${D}"
    echo -e "  Wallpaper dir:    ${G}${wdir}${D}"
    echo -e "  Raio cantos:      ${G}${cr}${D}"
    echo -e "  Vel anim:         ${G}${asp}${D}"
    echo -e "  Transparencia:    ${G}${trans} ($opacity)${D}"
    echo ""

    if confirm "Aplicar?"; then
        ensure_dir
        do_backup

        apply_font_global "$font" "$fw"

        if [[ "$tmode" == "dark" ]]; then
            json_set "$CONFIG_FILE" "colorSchemes.darkMode" "true"
        else
            json_set "$CONFIG_FILE" "colorSchemes.darkMode" "false"
        fi
        json_set "$CONFIG_FILE" "colorSchemes.predefinedScheme" "$tbuiltin"
        json_set "$CONFIG_FILE" "wallpaper.directory" "$wdir"
        json_set "$CONFIG_FILE" "general.radiusRatio" "$cr"
        json_set "$CONFIG_FILE" "general.animationSpeed" "$asp"
        json_set "$CONFIG_FILE" "bar.backgroundOpacity" "$opacity"
        json_set "$CONFIG_FILE" "ui.panelBackgroundOpacity" "$opacity"

        echo ""
        if confirm "Configurar icon theme tambem (GTK+Qt)?"; then
            pick "Icon Theme" "${ICONS_LIST[@]}"
            apply_icons_global "$_CHOICE"

            pick "Cursor Theme" "${CURSORS_LIST[@]}"
            local cur="$_CHOICE"
            local ci=""
            [[ -f "$ENV_FILE" ]] && ci=$(grep "^export ICON_THEME=" "$ENV_FILE" 2>/dev/null | cut -d= -f2)
            sed -i "s/^export XCURSOR_THEME=.*/export XCURSOR_THEME=\"${cur}\"/" "$ENV_FILE" 2>/dev/null
            if ! grep -q "export XCURSOR_THEME" "$ENV_FILE" 2>/dev/null; then
                echo "export XCURSOR_THEME=\"${cur}\"" >> "$ENV_FILE"
            fi
            info "Cursor: $cur"
        fi

        echo ""
        info "Tudo pronto!"
        if confirm "Recarregar shell agora?"; then
            reload_shell
        else
            info "Facas logout/login ou pressione 'r' no menu principal."
        fi
    fi
    press_enter
}

# ══════════════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        header
        echo -e "  ${W}${BD}Opcoes:${D}"
        echo ""
        echo -e "  ${G}1${D})  Configuracao completa (passo a passo)"
        echo ""
        echo -e "  ${M}--- Config Rapida (Noctalia) ---${D}"
        echo -e "  ${G}2${D})  Mudar fonte"
        echo -e "  ${G}3${D})  Mudar color scheme"
        echo -e "  ${G}4${D})  Mudar modo (dark/light/auto)"
        echo -e "  ${G}5${D})  Mudar diretorio de wallpaper"
        echo -e "  ${G}6${D})  Mudar raio dos cantos"
        echo -e "  ${G}7${D})  Mudar velocidade de animacao"
        echo -e "  ${G}8${D})  Mudar transparencia"
        echo ""
        echo -e "  ${M}--- GTK / Appearance ---${D}"
        echo -e "  ${G}9${D})  Appearance completo (tema+ícones+fonte)"
        echo -e "  ${G}10${D}) Mudar icon theme (só ícones)"
        echo -e "  ${G}11${D}) Mudar cursor theme"
        echo ""
        echo -e "  ${M}--- Outros ---${D}"
        echo -e "  ${G}s${D})  Ver status atual"
        echo -e "  ${G}e${D})  Exportar config (ver JSON)"
        echo -e "  ${G}r${D})  Recarregar shell"
        echo -e "  ${G}q${D})  Sair"
        echo ""
        echo -en "  ${C}>${D} Opcao: "
        read -r opt

        case "$opt" in
            1)  menu_full_setup ;;
            2)  menu_font ;;
            3)  menu_theme ;;
            4)  menu_theme_mode ;;
            5)  menu_wallpaper ;;
            6)  menu_corner ;;
            7)  menu_anim ;;
            8)  menu_transparency ;;
            9)  menu_appearance ;;
            10) menu_icon_theme ;;
            11) menu_cursor ;;
            s|S) menu_status ;;
            e|E) menu_export ;;
            r|R) reload_shell; press_enter ;;
            q|Q) echo ""; info "Ate mais!"; exit 0 ;;
            *)  warn "Opcao invalida"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════════════════════
#  CLI MODE
# ══════════════════════════════════════════════════════════════════════════════
cli_mode() {
    case "${1:-}" in
        --font)
            ensure_dir
            do_backup
            local fw="${3:-normal}"
            # Converter nome do peso pra pango se necessário
            case "$fw" in
                400|500|600|700|800) ;; # já é pango
                normal)  fw="400" ;;
                medium)  fw="500" ;;
                semibold) fw="600" ;;
                bold)    fw="700" ;;
                extrabold) fw="800" ;;
            esac
            apply_font_global "${2:-sans-serif}" "$fw"
            ;;
        --theme)
            ensure_dir
            do_backup
            json_set "$CONFIG_FILE" "colorSchemes.predefinedScheme" "${2:-Noctalia}"
            info "Scheme: ${2:-Noctalia}"
            ;;
        --mode)
            ensure_dir
            do_backup
            if [[ "${2:-dark}" == "dark" ]]; then
                json_set "$CONFIG_FILE" "colorSchemes.darkMode" "true"
            else
                json_set "$CONFIG_FILE" "colorSchemes.darkMode" "false"
            fi
            info "Modo: ${2:-dark}"
            ;;
        --wallpaper)
            ensure_dir
            do_backup
            json_set "$CONFIG_FILE" "wallpaper.directory" "${2:-~/Pictures/Wallpapers}"
            info "Wallpaper dir: ${2:-~/Pictures/Wallpapers}"
            ;;
        --anim-speed)
            ensure_dir
            do_backup
            if [[ "${2:-}" == "off" || "${2:-}" == "0" ]]; then
                json_set "$CONFIG_FILE" "general.animationDisabled" "true"
                info "Animacoes desligadas"
            else
                json_set "$CONFIG_FILE" "general.animationDisabled" "false"
                json_set "$CONFIG_FILE" "general.animationSpeed" "${2:-1.0}"
                info "Anim speed: ${2:-1.0}"
            fi
            ;;
        --corner-radius)
            ensure_dir
            do_backup
            json_set "$CONFIG_FILE" "general.radiusRatio" "${2:-1.0}"
            info "Corner radius: ${2:-1.0}"
            ;;
        --icon-theme)
            ensure_dir
            do_backup
            apply_icons_global "${2:-Papirus}"
            ;;
        --appearance)
            ensure_dir
            do_backup
            local theme="${2:-adw-gtk3-dark}"
            local icons="${3:-Papirus-Dark}"
            local font="${4:-Ubuntu Bold}"
            local size="${5:-12}"
            local qt_theme="${6:-adwaita-dark}"
            apply_gtk_appearance "$theme" "$icons" "$font" "$size" "$qt_theme"
            ;;
        --cursor)
            apply_env_vars "" "${2:-Bibata-Modern-Ice}"
            ;;
        --status)
            if [[ -f "$CONFIG_FILE" ]]; then
                echo "Fonte:          $(json_get "$CONFIG_FILE" "ui.fontDefault")"
                echo "Scheme:         $(json_get "$CONFIG_FILE" "colorSchemes.predefinedScheme")"
                echo "Dark mode:      $(json_get "$CONFIG_FILE" "colorSchemes.darkMode")"
                echo "Wallpaper dir:  $(json_get "$CONFIG_FILE" "wallpaper.directory")"
                echo "Corner radius:  $(json_get "$CONFIG_FILE" "general.radiusRatio")"
                echo "Anim speed:     $(json_get "$CONFIG_FILE" "general.animationSpeed")"
                local ad=$(json_get "$CONFIG_FILE" "general.animationDisabled")
                [[ "$ad" == "True" || "$ad" == "true" ]] && echo "Animacoes:      DESLIGADAS"
                echo "Bar opacity:    $(json_get "$CONFIG_FILE" "bar.backgroundOpacity")"
                echo "Bar position:   $(json_get "$CONFIG_FILE" "bar.position")"
                echo "Dock enabled:   $(json_get "$CONFIG_FILE" "dock.enabled")"
            else
                err "Config nao encontrado: $CONFIG_FILE"
            fi
            ;;
        --help|-h)
            cat << HELP
Uso: noctalia-config.sh [OPCAO] [VALOR]

  Sem argumentos              Menu interativo
  --font <fonte> [peso]       Definir fonte global (GTK+Qt+Noctalia)
  --theme <scheme>             Definir color scheme
  --mode <dark|light>          Definir modo
  --wallpaper <dir>            Definir diretorio de wallpapers
  --anim-speed <vel|off>       Velocidade (0.5-2.0) ou "off" pra desligar
  --corner-radius <raio>       Raio dos cantos (0.0-2.0)
  --icon-theme <nome>          Definir icon global (GTK+Qt)
  --appearance <tema> <ícones> <fonte> <tamanho> <tema-qt>
                               Definir appearance completo (GTK+Qt+ícones+fonte)
  --cursor <nome>              Definir cursor
  --status                     Ver config
  --help                       Ajuda

Schemes: Noctalia Catppuccin Dracula Gruvbox Nord Tokyo-Night Ayu Eldritch Kanagawa Rose Pine
Icon themes: Papirus Papirus-Dark Papirus-Light Tela Colloid Kana Breeze Numix
Cursors: Bibata-Modern-Ice Bibata-Modern-Classic Catppuccin-Mocha-Teal Phinger-cursors WhiteSur
HELP
            ;;
        *)
            main_menu
            ;;
    esac
}

# ── Entry Point ─────────────────────────────────────────────────────────────────
if [[ $# -gt 0 ]]; then
    cli_mode "$@"
else
    main_menu
fi
