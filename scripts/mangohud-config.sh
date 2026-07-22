#!/usr/bin/env bash
# mangohud-config.sh — Gera MangoHud.conf com CPU e GPU detectados automaticamente
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
info() { echo -e "  ${CYAN}→${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

CONF_DIR="$HOME/.config/MangoHud"
CONF_FILE="$CONF_DIR/MangoHud.conf"

# ── Detectar CPU ──────────────────────────────────────────
detect_cpu() {
    local cpu_name
    cpu_name=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//' || echo "Unknown CPU")
    echo "$cpu_name"
}

# ── Detectar GPU ──────────────────────────────────────────
detect_gpu() {
    local gpu_name="Unknown GPU"

    # Tentar via lspci
    if command -v lspci &>/dev/null; then
        gpu_name=$(lspci | grep -iE "vga|3d|display" | head -1 | sed 's/.*: //')
    fi

    # Se NVIDIA, pegar o nome completo via nvidia-smi
    if echo "$gpu_name" | grep -qi "nvidia" && command -v nvidia-smi &>/dev/null; then
        local nvidia_name
        nvidia_name=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | head -1)
        [[ -n "$nvidia_name" ]] && gpu_name="$nvidia_name"
    fi

    # Se AMD, tentar via /sys/class/drm
    if echo "$gpu_name" | grep -qi "amd\|ati\|radeon"; then
        local amdgpu_name
        amdgpu_name=$(cat /sys/class/drm/card*/device/uevent 2>/dev/null | grep "PCI_ID" | head -1)
        # Manter o nome do lspci que já é bom para AMD
    fi

    echo "$gpu_name"
}

# ── Extrair nome curto para o HUD ────────────────────────
short_name() {
    local full_name="$1"
    # NVIDIA: "NVIDIA Corporation GeForce GTX 1650" → "GTX 1650"
    if echo "$full_name" | grep -qi "nvidia"; then
        echo "$full_name" | grep -oiP "GeForce\s+\K[^\]\(]+" | sed 's/ *$//' || echo "$full_name"
        return
    fi
    # AMD: "Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 [Radeon RX 9060 XT]" → "RX 9060 XT"
    if echo "$full_name" | grep -qi "amd\|ati\|radeon"; then
        echo "$full_name" | grep -oiP "(Radeon|GeForce)\s+\K[^\]\(]+" | sed 's/ *$//' || echo "$full_name"
        return
    fi
    # Intel
    if echo "$full_name" | grep -qi "intel"; then
        echo "$full_name" | grep -oiP "Intel\s+\K.*" || echo "$full_name"
        return
    fi
    echo "$full_name"
}

# ── Detectar resolução e ajustar font_size ────────────────
detect_font_size() {
    local height=1080
    # Tentar via wlr-randr (Wayland)
    if command -v wlr-randr &>/dev/null; then
        height=$(wlr-randr 2>/dev/null | grep -oP '\d+x\K\d+' | sort -rn | head -1)
    # Tentar via xrandr (XWayland)
    elif command -v xrandr &>/dev/null; then
        height=$(xrandr 2>/dev/null | grep '\*' | grep -oP '\d+x\K\d+' | sort -rn | head -1)
    fi
    height=${height:-1080}

    # Calcular font_size proporcional à resolução vertical
    # 2160p (4K) = 58, 1440p = 38, 1080p = 28
    local font_size
    if [ "$height" -ge 2000 ]; then
        font_size=58
    elif [ "$height" -ge 1300 ]; then
        font_size=38
    elif [ "$height" -ge 700 ]; then
        font_size=28
    else
        font_size=22
    fi

    echo "$font_size"
}

# ── Extrair nome curto do CPU ─────────────────────────────
cpu_short_name() {
    local full="$1"
    # AMD: "AMD Ryzen 5 7500F 6-Core Processor" → "7500F"
    if echo "$full" | grep -qi "amd\|ryzen"; then
        echo "$full" | grep -oiP "Ryzen\s+\d+\s+\K\S+" | head -1
        return
    fi
    # Intel Core: "Intel(R) Core(TM) i5-10400F" → "i5 10400F"
    if echo "$full" | grep -qi "core"; then
        local model
        model=$(echo "$full" | grep -oiP "i[3579]-\S+" | head -1)
        if [ -n "$model" ]; then
            echo "$model" | sed 's/-/ /'
            return
        fi
    fi
    # Intel Ultra: "Intel(R) Core(TM) Ultra 9 285K" → "Ultra 9 285K"
    if echo "$full" | grep -qi "ultra"; then
        echo "$full" | grep -oiP "Ultra\s+\d+\s+\S+" | head -1
        return
    fi
    # Fallback: retorna tudo menos "Processor" e sufixos
    echo "$full" | sed 's/([^(]*)//g' | sed 's/ Processor//' | sed 's/ [0-9]*-Core.*//' | xargs
}

# ── Main ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  MangoHud Config Generator${NC}"
echo ""

CPU_FULL=$(detect_cpu)
GPU_FULL=$(detect_gpu)
GPU_SHORT=$(short_name "$GPU_FULL")

CPU_SHORT=$(cpu_short_name "$CPU_FULL")
FONT_SIZE=$(detect_font_size)

info "CPU: ${BOLD}$CPU_FULL${NC}"
info "GPU: ${BOLD}$GPU_FULL${NC}"
info "CPU short: $CPU_SHORT"
info "GPU short: $GPU_SHORT"
info "Resolução detectada: font_size=${FONT_SIZE}"
echo ""

# ── Gerar config ──────────────────────────────────────────
mkdir -p "$CONF_DIR"

cat > "$CONF_FILE" << EOF
################### Auto-gerado por mangohud-config.sh ###################
legacy_layout=false
custom_text_center=Arch Linux

#hud_compact
table_columns=3
background_alpha=0.6
round_corners=10
background_color=000000
cellpadding_y=-0.085
font_size=58
font_scale=1.0
font_file=/home/bn/.fonts/Ubuntu/Ubuntu-Bold.ttf
text_color=FFFFFF
position=top-left
toggle_hud=Shift_R+F12

# GPU
gpu_text=${GPU_SHORT}
gpu_stats
gpu_core_clock

# CPU
cpu_text=${CPU_SHORT}
cpu_stats
cpu_mhz

# RAM
vram
vram_color=C26693
ram
ram_color=C26693

# FPS
fps
fps_metrics=avg
reset_fps_metrics=F3
gpu_name
wine
wine_color=EB5B5B
frame_timing
fps_limit_method=early
toggle_fps_limit=F1
show_fps_limit
fps_limit=60,0,163

# Custom text
custom_text=
custom_text=Kernel:
exec=uname -r

output_folder=${HOME}
autostart_log=0
log_interval=100
toggle_logging=F2
EOF

ok "Config gerada em: $CONF_FILE"
echo ""
echo -e "  ${BOLD}CPU:${NC} $CPU_SHORT"
echo -e "  ${BOLD}GPU:${NC} $GPU_SHORT"
echo ""
info "Reinicie um jogo para ver as mudanças"
