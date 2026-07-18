#!/usr/bin/env bash
# Monitor configuration script for Niri (Wayland)
# Usage: monitor-config.sh [output-name]
set -euo pipefail

NIRI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

get_outputs_json() { niri msg -j outputs; }

list_outputs() {
  get_outputs_json | python3 -c "
import sys, json
for name in json.load(sys.stdin):
    print(name)
"
}

get_current_mode_str() {
  local output="$1"
  get_outputs_json | python3 -c "
import sys, json
data = json.load(sys.stdin)
o = data.get('$output', {})
modes = o.get('modes', [])
cm = o.get('current_mode', 0)
m = modes[cm]
print(str(m['width']) + 'x' + str(m['height']) + '@' + f\"{m['refresh_rate']/1000:.3f}\")
"
}

get_current_resolution() {
  get_current_mode_str "$1" | cut -d'@' -f1
}

get_output_logical() {
  get_outputs_json | python3 -c "
import sys, json
o = json.load(sys.stdin).get('$1', {})
l = o.get('logical', {})
print(json.dumps(l))
"
}

print_header() {
  local output="$1"
  local mode_str scale transform pos vrr
  mode_str=$(get_current_mode_str "$output")
  scale=$(get_output_logical "$output" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scale','?'))")
  transform=$(get_output_logical "$output" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transform','?'))")
  pos=$(get_output_logical "$output" | python3 -c "import sys,json; l=json.load(sys.stdin); print(f\"{l.get('x',0)},{l.get('y',0)}\")")
  vrr=$(get_outputs_json | python3 -c "import sys,json; o=json.load(sys.stdin).get('$output',{}); print('on' if o.get('vrr_enabled') else 'off')")

  echo ""
  echo "=== Monitor: $output ==="
  echo "  Modo:     $mode_str"
  echo "  Escala:   $scale"
  echo "  Rotacao:  $transform"
  echo "  Posicao:  $pos"
  echo "  VRR:      $vrr"
  echo ""
}

ask_number() {
  local prompt="$1" max="$2"
  local choice
  while true; do
    read -rp "$prompt" choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le "$max" ]; then
      echo "$choice"
      return 0
    fi
    echo "  Opcao invalida."
  done
}

menu_resolucao() {
  local output="$1"
  get_outputs_json | python3 -c "
import sys, json
data = json.load(sys.stdin)
o = data.get('$output', {})
modes = o.get('modes', [])
cm = o.get('current_mode', 0)
seen = set()
idx = 1
for i, m in enumerate(modes):
    name = str(m['width']) + 'x' + str(m['height']) + '@' + f\"{m['refresh_rate']/1000:.3f}\"
    if name not in seen:
        seen.add(name)
        tag = ' (atual)' if i == cm else ''
        print(f'  [{idx}] {name}{tag}')
        idx += 1
print(f'  [0] Voltar')
print(f'  Total: {idx - 1} modos')
"
  local total
  total=$(get_outputs_json | python3 -c "
import sys, json
data = json.load(sys.stdin)
o = data.get('$output', {})
modes = o.get('modes', [])
seen = set()
for m in modes:
    name = str(m['width']) + 'x' + str(m['height']) + '@' + f\"{m['refresh_rate']/1000:.3f}\"
    seen.add(name)
print(len(seen))
")
  local choice
  choice=$(ask_number "Escolha [0-$total]: " "$total")
  [ "$choice" = "0" ] && return 0

  local selected
  selected=$(get_outputs_json | python3 -c "
import sys, json
data = json.load(sys.stdin)
o = data.get('$output', {})
modes = o.get('modes', [])
seen = []
for m in modes:
    name = str(m['width']) + 'x' + str(m['height']) + '@' + f\"{m['refresh_rate']/1000:.3f}\"
    if name not in seen:
        seen.append(name)
print(seen[$choice - 1])
")
  niri msg output "$output" mode "$selected"
  echo "Resolucao alterada para: $selected"
}

menu_refresh_rate() {
  local output="$1"
  local resolution
  resolution=$(get_current_resolution "$output")

  get_outputs_json | python3 -c "
import sys, json
data = json.load(sys.stdin)
o = data.get('$output', {})
modes = o.get('modes', [])
cm = o.get('current_mode', 0)
res = '$resolution'
seen = []
for i, m in enumerate(modes):
    name = str(m['width']) + 'x' + str(m['height']) + '@' + f\"{m['refresh_rate']/1000:.3f}\"
    if name.startswith(res + '@') and name not in seen:
        seen.append(name)
        tag = ' (atual)' if i == cm else ''
        print(f'  [{len(seen)}] {name}{tag}')
print(f'  [0] Voltar')
print(f'  Total: {len(seen)}')
"
  local total
  total=$(get_outputs_json | python3 -c "
import sys, json
data = json.load(sys.stdin)
o = data.get('$output', {})
modes = o.get('modes', [])
res = '$resolution'
seen = set()
for m in modes:
    name = str(m['width']) + 'x' + str(m['height']) + '@' + f\"{m['refresh_rate']/1000:.3f}\"
    if name.startswith(res + '@'):
        seen.add(name)
print(len(seen))
")
  local choice
  choice=$(ask_number "Escolha [0-$total]: " "$total")
  [ "$choice" = "0" ] && return 0

  local selected
  selected=$(get_outputs_json | python3 -c "
import sys, json
data = json.load(sys.stdin)
o = data.get('$output', {})
modes = o.get('modes', [])
res = '$resolution'
seen = []
for m in modes:
    name = str(m['width']) + 'x' + str(m['height']) + '@' + f\"{m['refresh_rate']/1000:.3f}\"
    if name.startswith(res + '@') and name not in seen:
        seen.append(name)
print(seen[$choice - 1])
")
  niri msg output "$output" mode "$selected"
  echo "Refresh rate alterado para: $selected"
}

menu_scale() {
  local output="$1"
  local current
  current=$(get_output_logical "$output" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scale','1.0'))")

  local scales=("0.5" "0.75" "1.0" "1.25" "1.5" "2.0" "2.5" "3.0" "auto")
  for i in "${!scales[@]}"; do
    if [ "${scales[$i]}" = "$current" ]; then
      echo "  [$((i+1))] ${scales[$i]} (atual)"
    else
      echo "  [$((i+1))] ${scales[$i]}"
    fi
  done
  echo "  [0] Voltar"

  local choice
  choice=$(ask_number "Escolha [0-${#scales[@]}]: " "${#scales[@]}")
  [ "$choice" = "0" ] && return 0

  local selected="${scales[$((choice-1))]}"
  niri msg output "$output" scale "$selected"
  echo "Escala alterada para: $selected"
}

menu_transform() {
  local output="$1"
  local current
  current=$(get_output_logical "$output" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transform','normal'))")

  local transforms=("normal" "90" "180" "270" "flipped" "flipped-90" "flipped-180" "flipped-270")
  for i in "${!transforms[@]}"; do
    if [ "${transforms[$i]}" = "$current" ]; then
      echo "  [$((i+1))] ${transforms[$i]} (atual)"
    else
      echo "  [$((i+1))] ${transforms[$i]}"
    fi
  done
  echo "  [0] Voltar"

  local choice
  choice=$(ask_number "Escolha [0-${#transforms[@]}]: " "${#transforms[@]}")
  [ "$choice" = "0" ] && return 0

  local selected="${transforms[$((choice-1))]}"
  niri msg output "$output" transform "$selected"
  echo "Rotacao alterada para: $selected"
}

menu_position() {
  local output="$1"
  local current
  current=$(get_output_logical "$output" | python3 -c "import sys,json; l=json.load(sys.stdin); print(f\"{l.get('x',0)},{l.get('y',0)}\")")

  echo "  [1] auto (automatico)"
  echo "  [2] $current (atual)"
  echo "  [3] definir manualmente"
  echo "  [0] Voltar"

  local choice
  choice=$(ask_number "Escolha [0-3]: " 3)
  [ "$choice" = "0" ] && return 0

  case "$choice" in
    1) niri msg output "$output" position auto; echo "Posicao alterada para: auto" ;;
    2) echo "Posicao ja e: $current" ;;
    3)
      read -rp "Posicao X,Y (ex: 1920,0): " pos
      pos=$(echo "$pos" | tr -d ' ')
      niri msg output "$output" position set "$pos"
      echo "Posicao alterada para: $pos"
      ;;
  esac
}

menu_vrr() {
  local output="$1"
  local current
  current=$(get_outputs_json | python3 -c "
import sys, json
o = json.load(sys.stdin).get('$output', {})
print('on' if o.get('vrr_enabled') else 'off')
")

  if [ "$current" = "on" ]; then
    echo "  [1] on (atual)"
    echo "  [2] off"
  else
    echo "  [1] on"
    echo "  [2] off (atual)"
  fi
  echo "  [0] Voltar"

  local choice
  choice=$(ask_number "Escolha [0-2]: " 2)
  [ "$choice" = "0" ] && return 0

  local selected
  if [ "$choice" = "1" ]; then
    selected="on"
  else
    selected="off"
  fi
  niri msg output "$output" vrr "$selected"
  echo "VRR alterado para: $selected"
}

save_to_config() {
  local output="$1"
  local config="$NIRI_CONFIG"

  if [ ! -f "$config" ]; then
    echo "Config nao encontrado: $config"
    return 1
  fi

  read -rp "Salvar configuracao de \"$output\" no config? [s/N] " confirm
  if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
    echo "Cancelado."
    return 0
  fi

  cp "$config" "${config}.bak"

  get_outputs_json | python3 -c "
import sys, json, re

data = json.load(sys.stdin)
output_name = '$output'
config_path = '$config'

o = data.get(output_name, {})
modes = o.get('modes', [])
cm = o.get('current_mode', 0)
m = modes[cm] if cm < len(modes) else {}
log = o.get('logical', {})

mode_str = str(m.get('width','')) + 'x' + str(m.get('height','')) + '@' + f\"{m.get('refresh_rate',0)/1000:.3f}\"
scale = log.get('scale', 1.0)
transform = log.get('transform', 'normal').lower()
x = log.get('x', 0)
y = log.get('y', 0)

new_block = f'''output \"{output_name}\" {{
    mode \"{mode_str}\"

    scale {scale}

    transform \"{transform}\"
    position x={x} y={y}
}}'''

with open(config_path, 'r') as f:
    content = f.read()

pattern = r'output\s+\"' + re.escape(output_name) + r'\"\s*\{[^}]*\}'
match = re.search(pattern, content)

if match:
    content = content[:match.start()] + new_block + content[match.end():]
else:
    content = content.rstrip() + '\n\n' + new_block + '\n'

with open(config_path, 'w') as f:
    f.write(content)
"

  echo "Configuracao salva em $config (backup: ${config}.bak)"
}

main() {
  local output="${1:-}"
  if [ -z "$output" ]; then
    local outputs
    outputs=$(list_outputs)
    local count
    count=$(echo "$outputs" | grep -c . || true)
    if [ "$count" -eq 1 ]; then
      output="$outputs"
    elif [ "$count" -gt 1 ]; then
      echo "Monitores disponiveis:"
      local i=1
      while IFS= read -r line; do
        echo "  [$i] $line"
        i=$((i+1))
      done <<< "$outputs"
      local choice
      choice=$(ask_number "Escolha [1-$count]: " "$count") || exit 1
      output=$(echo "$outputs" | sed -n "${choice}p")
    else
      echo "Nenhum monitor detectado."
      exit 1
    fi
  fi

  while true; do
    print_header "$output"
    echo "  [1] Resolucao"
    echo "  [2] Refresh Rate"
    echo "  [3] Escala"
    echo "  [4] Rotacao"
    echo "  [5] Posicao"
    echo "  [6] VRR (Adaptive Sync)"
    echo "  [7] Salvar no config"
    echo "  [0] Sair"
    echo ""

    local choice
    read -rp "Opcao: " choice

    case "$choice" in
      1) menu_resolucao "$output" ;;
      2) menu_refresh_rate "$output" ;;
      3) menu_scale "$output" ;;
      4) menu_transform "$output" ;;
      5) menu_position "$output" ;;
      6) menu_vrr "$output" ;;
      7) save_to_config "$output" ;;
      0|q|Q) echo "Saindo."; break ;;
      *) echo "Opcao invalida." ;;
    esac

    echo ""
    read -rp "Pressione Enter para continuar..." _
  done
}

main "$@"
