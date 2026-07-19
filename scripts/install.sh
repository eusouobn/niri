#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════╗
# ║  install.sh - Instalador Arch Linux (eusouobn)         ║
# ║  Versão moderna com suporte a Niri + Noctalia Shell    ║
# ╚══════════════════════════════════════════════════════════╝

# ── Cores ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'
NC='\033[0m'

title()  { clear; echo -e "\n${BLUE}${BOLD}╔══════════════════════════════════╗${NC}"; echo -e "${BLUE}${BOLD}║  $1${NC}"; echo -e "${BLUE}${BOLD}╚══════════════════════════════════╝${NC}\n"; }
info()   { echo -e "  ${CYAN}▸${NC} $1"; }
ok()     { echo -e "  ${GREEN}✔${NC} $1"; }
warn()   { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail()   { echo -e "  ${RED}✖${NC} $1"; exit 1; }
quote()  { echo -e "\n  ─────────────────────────────────────\n"; }

# ── Verificações iniciais ──────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo "❌ Execute com sudo: sudo bash install.sh"
  exit 1
fi

if ! command -v pacstrap &>/dev/null; then
  echo "❌ Execute este script no ambiente live do Arch ISO."
  exit 1
fi

# ── Configurar mirrors ────────────────────────────────────
info "Configurando mirrors..."

# Copiar mirrorlist do ISO se existir
if [ -f /etc/pacman.d/mirrorlist ]; then
  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
fi

# Usar reflector se disponível, senão usar mirrorlist padrão
if command -v reflector &>/dev/null; then
  reflector --country Brazil --protocol https --sort rate --latest 5 --save /etc/pacman.d/mirrorlist
  ok "Mirrors configurados via reflector"
else
  # Fallback: usar mirrors brasileiros
  cat > /etc/pacman.d/mirrorlist <<'EOF'
## Brasil
Server = https://archlinux-br.org/repos/$repo/os/$arch
Server = https://mirror.ufam.edu.br/archlinux/$repo/os/$arch
Server = https://arch.mirrorcamp.com.br/repos/$repo/os/$arch

## Global
Server = https://geo.mirror.pkgbuild.com/repos/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/repos/$repo/os/$arch
EOF
  ok "Mirrors configurados (fallback)"
fi

pacman -Syy

# ══════════════════════════════════════════════════════════
# 1. HOSTNAME
# ══════════════════════════════════════════════════════════
title "1/12 — HOSTNAME"
read -rp "  Hostname: " HOSTNAME
[ -z "$HOSTNAME" ] && fail "Hostname não pode ser vazio"

# ══════════════════════════════════════════════════════════
# 2. USUÁRIO
# ══════════════════════════════════════════════════════════
title "2/12 — USUÁRIO"
read -rp "  Nome de usuário: " USERNAME
[ -z "$USERNAME" ] && fail "Usuário não pode ser vazio"

# ══════════════════════════════════════════════════════════
# 3. DISCO DE INSTALAÇÃO
# ══════════════════════════════════════════════════════════
title "3/12 — DISCO DE INSTALAÇÃO"

DEVICES_LIST=$(lsblk -nd --output NAME | grep -E "sd|hd|vd|nvme|mmcblk")
echo -e "${BOLD}Dispositivos disponíveis:${NC}\n"

for disk in $DEVICES_LIST; do
  MODEL=$(lsblk -dno MODEL "/dev/$disk" 2>/dev/null | xargs)
  SERIAL=$(lsblk -dno SERIAL "/dev/$disk" 2>/dev/null | xargs)
  SIZE=$(lsblk -dno SIZE "/dev/$disk" 2>/dev/null | xargs)
  ROTA=$(lsblk -dno ROTA "/dev/$disk" 2>/dev/null)
  TYPE=$([ "$ROTA" = "0" ] && echo "SSD" || echo "HDD")
  PARTS=$(lsblk -no NAME "/dev/$disk" 2>/dev/null | tail -n +2 | wc -l)

  echo -e "  ${BOLD}$disk${NC}"
  echo "    Modelo:  $MODEL"
  echo "    Serial:  $SERIAL"
  echo "    Tamanho: $SIZE ($TYPE)"
  echo "    Partições: $PARTS"
  echo ""
done

PS3=$'\n  Selecione o disco: '
select INSTDISK in $DEVICES_LIST; do
  [ -n "$INSTDISK" ] && break
  echo "  Opção inválida"
done
ok "Disco selecionado: /dev/$INSTDISK"

# Detectar NVMe
if echo "$INSTDISK" | grep -q "nvme\|mmcblk"; then
  PART_PREFIX="p"
else
  PART_PREFIX=""
fi

# ══════════════════════════════════════════════════════════
# 4. SISTEMA DE ARQUIVOS
# ══════════════════════════════════════════════════════════
title "4/12 — SISTEMA DE ARQUIVOS"

PS3=$'\n  Selecione: '
select FILESYSTEM in ext4 btrfs f2fs xfs; do
  [ -n "$FILESYSTEM" ] && break
  echo "  Opção inválida"
done
ok "Filesystem: $FILESYSTEM"

# ══════════════════════════════════════════════════════════
# 5. HOME SEPARADA
# ══════════════════════════════════════════════════════════
title "5/12 — PARTIÇÃO /home SEPARADA"

SEPARATE_HOME="n"
PS3=$'\n  /home separada? '
select HOME_ANSWER in "Sim" "Não"; do
  case "$HOME_ANSWER" in
    Sim) SEPARATE_HOME="y"; break ;;
    Não) SEPARATE_HOME="n"; break ;;
  esac
done

if [ "$SEPARATE_HOME" = "y" ]; then
  echo ""
  echo -e "${BOLD}Dispositivos disponíveis:${NC}\n"

  for disk in $DEVICES_LIST; do
    MODEL=$(lsblk -dno MODEL "/dev/$disk" 2>/dev/null | xargs)
    SERIAL=$(lsblk -dno SERIAL "/dev/$disk" 2>/dev/null | xargs)
    SIZE=$(lsblk -dno SIZE "/dev/$disk" 2>/dev/null | xargs)
    ROTA=$(lsblk -dno ROTA "/dev/$disk" 2>/dev/null)
    TYPE=$([ "$ROTA" = "0" ] && echo "SSD" || echo "HDD")

    echo -e "  ${BOLD}$disk${NC}"
    echo "    Modelo:  $MODEL"
    echo "    Serial:  $SERIAL"
    echo "    Tamanho: $SIZE ($TYPE)"
    echo ""
  done

  PS3=$'\n  Disco para /home: '
  select HOMEDISK in $DEVICES_LIST; do
    [ -n "$HOMEDISK" ] && break
    echo "  Opção inválida"
  done

  if echo "$HOMEDISK" | grep -q "nvme\|mmcblk"; then
    HOME_PREFIX="p"
  else
    HOME_PREFIX=""
  fi

  PS3=$'\n  Formatar /home? '
  select FORMAT_HOME in "Sim" "Não"; do
    case "$FORMAT_HOME" in
      Sim) FORMAT_HOME="y"; break ;;
      Não) FORMAT_HOME="n"; break ;;
    esac
  done
fi

# ══════════════════════════════════════════════════════════
# 6. TIPO DE SWAP
# ══════════════════════════════════════════════════════════
title "6/12 — SWAP"

PS3=$'\n  Tipo de swap: '
select SWAPTYPE in "Arquivo" "ZRAM"; do
  [ -n "$SWAPTYPE" ] && break
done

if [ "$SWAPTYPE" = "Arquivo" ]; then
  RAM_SIZE=$(free -g | awk '/Mem:/{print $2}')
  if [ "$RAM_SIZE" -le 8 ]; then
    DEFAULT_SWAP=4
  else
    DEFAULT_SWAP=2
  fi
  read -rp "  Tamanho em GB [${DEFAULT_SWAP}]: " SWAP_SIZE
  SWAP_SIZE=${SWAP_SIZE:-$DEFAULT_SWAP}
  ok "Swap: ${SWAP_SIZE}GB em arquivo"
else
  RAM_SIZE=$(free -g | awk '/Mem:/{print $2}')
  if [ "$RAM_SIZE" -le 8 ]; then
    DEFAULT_SWAP=4
  else
    DEFAULT_SWAP=2
  fi
  read -rp "  Tamanho em GB [${DEFAULT_SWAP}]: " SWAP_SIZE
  SWAP_SIZE=${SWAP_SIZE:-$DEFAULT_SWAP}
  ok "Swap: ${SWAP_SIZE}GB em ZRAM"
fi

# ══════════════════════════════════════════════════════════
# 7. DRIVER DE VÍDEO
# ══════════════════════════════════════════════════════════
title "7/12 — DRIVER DE VÍDEO"

# Auto-detectar GPU
GPU_INFO=$(lspci | grep -i "vga\|3d\|display" 2>/dev/null || true)
HAS_NVIDIA=$(echo "$GPU_INFO" | grep -ci nvidia || true)
HAS_AMD=$(echo "$GPU_INFO" | grep -ci "amd\|radeon" || true)
HAS_INTEL=$(echo "$GPU_INFO" | grep -ci intel || true)

if [ "$HAS_NVIDIA" -gt 0 ]; then
  echo -e "  ${BOLD}NVIDIA detectada!${NC}"
  echo ""
  echo "  Driver recomendado para Wayland/Niri:"
  echo "    1) Nvidia-Open  (recomendado — open-source)"
  echo "    2) Nvidia       (proprietário clássico)"
  echo "    3) Nouveau      (open-source genérico)"
  echo "    4) Outro driver"
  echo ""

  PS3=$'\n  Selecione: '
  select GPU_CHOICE in "Nvidia-Open" "Nvidia" "Nouveau" "Outro"; do
    [ -n "$GPU_CHOICE" ] && break
  done

  if [ "$GPU_CHOICE" = "Outro" ]; then
    echo ""
    echo "  Drivers disponíveis: AMDGPU, ATI, INTEL, Nouveau, Nvidia, Nvidia-Open, VMware"
    PS3=$'\n  Driver: '
    select VIDEODRIVER in AMDGPU ATI INTEL Nouveau Nvidia Nvidia-Open VMware; do
      [ -n "$VIDEODRIVER" ] && break
    done
  else
    VIDEODRIVER="$GPU_CHOICE"
  fi
else
  echo -e "  GPU: ${GPU_INFO%% *}"
  echo ""

  if [ "$HAS_AMD" -gt 0 ]; then
    echo "  AMD detectada — driver recomendado: AMDGPU"
  elif [ "$HAS_INTEL" -gt 0 ]; then
    echo "  Intel detectada — driver recomendado: INTEL"
  fi
  echo ""

  PS3=$'\n  Driver: '
  select VIDEODRIVER in AMDGPU ATI INTEL Nouveau Nvidia Nvidia-Open VMware; do
    [ -n "$VIDEODRIVER" ] && break
  done
fi

ok "Driver: $VIDEODRIVER"

# GPU secundária (notebooks híbridos)
echo ""
echo "  Possui GPU dedicada + integrada? (Optimus/híbrido)"
PS3=$'\n  GPU secundária: '
select SECVID in NENHUM AMDGPU ATI INTEL Nouveau Nvidia Nvidia-Open VMware; do
  [ -n "$SECVID" ] && break
done

# ══════════════════════════════════════════════════════════
# 8. INTERFACE GRÁFICA
# ══════════════════════════════════════════════════════════
title "8/12 — INTERFACE GRÁFICA"

echo -e "  ${BOLD}Desktop Environments:${NC}"
echo "    1) Budgie      5) LXDE      9) XFCE"
echo "    2) Cinnamon     6) LXQT"
echo "    3) Deepin       7) MATE"
echo "    4) GNOME        8) Plasma"
echo ""
echo -e "  ${BOLD}Window Managers:${NC}"
echo "    10) Niri + Noctalia Shell (Wayland)"
echo ""

PS3=$'\n  Selecione: '
select DE in Budgie Cinnamon Deepin GNOME LXDE LXQT MATE Plasma XFCE "Niri"; do
  [ -n "$DE" ] && break
done

# ══════════════════════════════════════════════════════════
# 9. SERVIDOR DE ÁUDIO
# ══════════════════════════════════════════════════════════
title "9/12 — SERVIDOR DE ÁUDIO"

PS3=$'\n  Selecione: '
select AUDIO in Pipewire Pulseaudio; do
  [ -n "$AUDIO" ] && break
done

# ══════════════════════════════════════════════════════════
# 10. KERNEL
# ══════════════════════════════════════════════════════════
title "10/12 — KERNEL"

PS3=$'\n  Selecione: '
select KERNEL in linux linux-zen linux-lts linux-hardened; do
  [ -n "$KERNEL" ] && break
done

# ══════════════════════════════════════════════════════════
# 11. CONFIRMAÇÃO
# ══════════════════════════════════════════════════════════
title "11/12 — CONFIRMAÇÃO"

echo -e "${BOLD}Resumo da instalação:${NC}\n"
echo "  Hostname:    $HOSTNAME"
echo "  Usuário:     $USERNAME"
echo "  Disco:       /dev/$INSTDISK"
echo "  Filesystem:  $FILESYSTEM"
echo "  Home:        $([ "$SEPARATE_HOME" = "y" ] && echo "/dev/$HOMEDISK ($FORMAT_HOME)" || echo "No root")"
echo "  Swap:        ${SWAP_SIZE} GB ($SWAPTYPE)"
echo "  Vídeo:       $VIDEODRIVER + $SECVID"
echo "  Desktop:     $DE"
echo "  Áudio:       $AUDIO"
echo "  Kernel:      $KERNEL"
echo ""
echo -e "  ${RED}${BOLD}⚠ ATENÇÃO: O disco /dev/$INSTDISK será APAGADO!${NC}"
echo ""

read -rp "  Confirmar instalação? (s/N): " CONFIRM
[ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ] && fail "Instalação cancelada"

# ══════════════════════════════════════════════════════════
# 12. INSTALAÇÃO
# ══════════════════════════════════════════════════════════
title "12/12 — INSTALANDO"

# ── Particionamento ────────────────────────────────────────
info "Particionando /dev/$INSTDISK..."

if [ -d /sys/firmware/efi ]; then
  info "Sistema EFI detectado"

  parted /dev/$INSTDISK mklabel gpt -s
  parted /dev/$INSTDISK mkpart primary fat32 1MiB 513MiB -s
  parted /dev/$INSTDISK set 1 esp on

  # Root
  parted /dev/$INSTDISK mkpart primary $FILESYSTEM 513MiB 100% -s

  # Formatar boot
  mkfs.fat -F32 /dev/${INSTDISK}${PART_PREFIX}1
  ok "Boot: /dev/${INSTDISK}${PART_PREFIX}1 (FAT32)"

  # Formatar root
  case $FILESYSTEM in
    ext4)  mkfs.ext4 -F /dev/${INSTDISK}${PART_PREFIX}2 ;;
    btrfs) mkfs.btrfs -f /dev/${INSTDISK}${PART_PREFIX}2 ;;
    f2fs)  mkfs.f2fs -f /dev/${INSTDISK}${PART_PREFIX}2 ;;
    xfs)   mkfs.xfs -f /dev/${INSTDISK}${PART_PREFIX}2 ;;
  esac
  ok "Root: /dev/${INSTDISK}${PART_PREFIX}2 ($FILESYSTEM)"

  # Montar
  mount /dev/${INSTDISK}${PART_PREFIX}2 /mnt
  mkdir -p /mnt/boot
  mount /dev/${INSTDISK}${PART_PREFIX}1 /mnt/boot

else
  info "Sistema Legacy detectado"

  parted /dev/$INSTDISK mklabel msdos -s
  parted /dev/$INSTDISK mkpart primary $FILESYSTEM 1MiB 100% -s
  parted /dev/$INSTDISK set 1 boot on

  # Formatar root
  case $FILESYSTEM in
    ext4)  mkfs.ext4 -F /dev/${INSTDISK}${PART_PREFIX}1 ;;
    btrfs) mkfs.btrfs -f /dev/${INSTDISK}${PART_PREFIX}1 ;;
    f2fs)  mkfs.f2fs -f /dev/${INSTDISK}${PART_PREFIX}1 ;;
    xfs)   mkfs.xfs -f /dev/${INSTDISK}${PART_PREFIX}1 ;;
  esac
  ok "Root: /dev/${INSTDISK}${PART_PREFIX}1 ($FILESYSTEM)"

  mount /dev/${INSTDISK}${PART_PREFIX}1 /mnt
fi

# ── Home separada ──────────────────────────────────────────
if [ "$SEPARATE_HOME" = "y" ]; then
  info "Configurando /home separada..."

  if [ "$FORMAT_HOME" = "y" ]; then
    parted /dev/$HOMEDISK mklabel gpt -s
    parted /dev/$HOMEDISK mkpart primary $FILESYSTEM 1MiB 100% -s

    case $FILESYSTEM in
      ext4)  mkfs.ext4 -F /dev/${HOMEDISK}${HOME_PREFIX}1 ;;
      btrfs) mkfs.btrfs -f /dev/${HOMEDISK}${HOME_PREFIX}1 ;;
      f2fs)  mkfs.f2fs -f /dev/${HOMEDISK}${HOME_PREFIX}1 ;;
      xfs)   mkfs.xfs -f /dev/${HOMEDISK}${HOME_PREFIX}1 ;;
    esac
    ok "Home: /dev/${HOMEDISK}${HOME_PREFIX}1 ($FILESYSTEM)"
  fi

  mkdir -p /mnt/home
  mount /dev/${HOMEDISK}${HOME_PREFIX}1 /mnt/home
  ok "/home montada"
fi

# ── Swap ───────────────────────────────────────────────────
info "Configurando swap..."

if [ "$SWAPTYPE" = "Arquivo" ]; then
  if [ "$FILESYSTEM" = "btrfs" ]; then
    truncate -s 0 /mnt/swapfile
    chattr +C /mnt/swapfile
    btrfs property set /mnt/swapfile compression ""
    fallocate -l ${SWAP_SIZE}G /mnt/swapfile
  else
    fallocate -l ${SWAP_SIZE}G /mnt/swapfile
  fi
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
  ok "Swap em arquivo: ${SWAP_SIZE}GB (será ativado no boot)"
else
  echo "zram" > /mnt/etc/modules-load.d/zram.conf
  echo "options zram num_devices=1" > /mnt/etc/modprobe.d/zram.conf
  echo "KERNEL==\"zram0\", ATTR{disksize}=\"${SWAP_SIZE}G\" RUN=\"/usr/bin/mkswap /dev/zram0\", TAG+=\"systemd\"" > /mnt/etc/udev/rules.d/99-zram.rules
  ok "Swap ZRAM: ${SWAP_SIZE}GB"
fi

# ── pacstrap ───────────────────────────────────────────────
info "Instalando sistema base..."

pacstrap /mnt base $KERNEL ${KERNEL}-headers linux-firmware \
  btrfs-progs dosfstools e2fsprogs f2fs-tools xfsprogs \
  --noconfirm

ok "Sistema base instalado"

# ── fstab ──────────────────────────────────────────────────
genfstab -U /mnt > /mnt/etc/fstab

# Adicionar swap no fstab (depois do genfstab)
if [ "$SWAPTYPE" = "Arquivo" ]; then
  echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
else
  echo "/dev/zram0 none swap defaults 0 0" >> /mnt/etc/fstab
fi

ok "fstab gerado"

# ── Inside chroot ──────────────────────────────────────────
info "Configurando sistema..."

# Timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt timedatectl set-timezone America/Sao_Paulo
arch-chroot /mnt timedatectl set-ntp true

# Locale
echo "pt_BR.UTF-8 UTF-8" > /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=pt_BR.UTF-8" > /mnt/etc/locale.conf

# Hostname
echo "$HOSTNAME" > /mnt/etc/hostname
echo "127.0.0.1 localhost.localdomain localhost" > /mnt/etc/hosts
echo "::1 localhost.localdomain localhost" >> /mnt/etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /mnt/etc/hosts

# Mirrors + parallel downloads
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
sed -i 's/#ParallelDownloads/ParallelDownloads/' /mnt/etc/pacman.conf

# Multilib
sed -i '/\[multilib\]/,/Include/s/^#//' /mnt/etc/pacman.conf

# Pacotes essenciais
arch-chroot /mnt pacman -Sy --noconfirm \
  git nano wget sudo pacman-contrib reflector \
  networkmanager dhcpcd iwd usbutils base-devel \
  noto-fonts noto-fonts-emoji

# User
arch-chroot /mnt useradd -m -G wheel "$USERNAME"

# Groups
arch-chroot /mnt groupadd -r autologin 2>/dev/null || true
arch-chroot /mnt usermod -G wheel,autologin "$USERNAME"

# Sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers

# ── Driver de vídeo ────────────────────────────────────────
info "Instalando driver de vídeo..."

case "$VIDEODRIVER" in
  Nvidia)
    arch-chroot /mnt pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils
    ;;
  Nvidia-Open)
    arch-chroot /mnt pacman -S --noconfirm nvidia-open nvidia-utils lib32-nvidia-utils
    ;;
  *)
    DRIVER_LOWER=$(echo "$VIDEODRIVER" | tr '[:upper:]' '[:lower:]')
    arch-chroot /mnt pacman -S --noconfirm "xf86-video-$DRIVER_LOWER"
    ;;
esac

# Vulkan
case "$VIDEODRIVER" in
  AMDGPU|ATI)
    arch-chroot /mnt pacman -S --noconfirm \
      vulkan-radeon vulkan-mesa-layers libva-mesa-driver \
      lib32-mesa lib32-vulkan-radeon lib32-vulkan-mesa-layers \
      lib32-libva-mesa-driver mesa-demos mesa-utils
    ;;
  INTEL)
    arch-chroot /mnt pacman -S --noconfirm \
      vulkan-intel vulkan-mesa-layers libva-intel-driver \
      lib32-mesa lib32-vulkan-intel lib32-vulkan-mesa-layers \
      lib32-libva-intel-driver mesa-demos mesa-utils
    ;;
  Nvidia|Nvidia-Open)
    arch-chroot /mnt pacman -S --noconfirm \
      nvidia-utils lib32-nvidia-utils vulkan-icd-loader lib32-vulkan-icd-loader
    ;;
esac

# ── DE/WM ──────────────────────────────────────────────────
info "Instalando $DE..."

# Pacotes base (comuns a todos)
BASE_PKGS="networkmanager network-manager-applet"
AUDIO_PKGS_PIPewire="pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber"
AUDIO_PKGS_Pulse="pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-jack"

if [ "$AUDIO" = "Pipewire" ]; then
  BASE_PKGS="$BASE_PKGS $AUDIO_PKGS_PIPewire"
else
  BASE_PKGS="$BASE_PKGS $AUDIO_PKGS_Pulse"
  arch-chroot /mnt systemctl enable pulseaudio.service pulseaudio.socket 2>/dev/null || true
fi

case "$DE" in
  Budgie)
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS \
      budgie-desktop gnome-terminal nautilus
    arch-chroot /mnt systemctl enable lightdm NetworkManager
    ;;
  Cinnamon)
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS \
      cinnamon
    arch-chroot /mnt systemctl enable lightdm NetworkManager
    ;;
  Deepin)
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS \
      deepin
    arch-chroot /mnt systemctl enable lightdm NetworkManager
    ;;
  GNOME)
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS \
      gnome gnome-tweaks
    arch-chroot /mnt systemctl enable gdm NetworkManager
    ;;
  LXDE)
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS \
      lxde-gtk3
    arch-chroot /mnt systemctl enable lightdm NetworkManager
    ;;
  LXQT)
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS \
      lxqt
    arch-chroot /mnt systemctl enable sddm NetworkManager
    ;;
  MATE)
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS \
      mate mate-extra
    arch-chroot /mnt systemctl enable lightdm NetworkManager
    ;;
  Plasma)
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS \
      plasma konsole dolphin sddm
    arch-chroot /mnt systemctl enable sddm NetworkManager
    ;;
  XFCE)
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS \
      xfce4 thunar xfce4-pulseaudio-plugin
    arch-chroot /mnt systemctl enable lightdm NetworkManager
    ;;
  Niri)
    # Niri será instalado após reboot via install-niri.sh
    arch-chroot /mnt pacman -S --noconfirm $BASE_PKGS
    arch-chroot /mnt systemctl enable NetworkManager

    # Copiar scripts para o sistema instalado
    info "Copiando scripts para /mnt..."
    mkdir -p /mnt/root/scripts

    # Copiar install-niri.sh do repo (se disponível)
    if [ -f /root/scripts/install-niri.sh ]; then
      cp /root/scripts/install-niri.sh /mnt/root/scripts/
      ok "install-niri.sh copiado"
    fi

    # Copiar optimize-io.sh se disponível
    if [ -f /root/scripts/optimize-io.sh ]; then
      cp /root/scripts/optimize-io.sh /mnt/root/scripts/
      ok "optimize-io.sh copiado"
    fi

    warn "Após reiniciar, execute: sudo bash ~/scripts/install-niri.sh"
    ;;
esac

# ── Bluetooth ──────────────────────────────────────────────
if lsusb | grep -qi bluetooth; then
  info "Bluetooth detectado, instalando..."
  BLUETOOTH_PKGS="bluez bluez-utils"
  [ "$DE" != "Plasma" ] && [ "$DE" != "LXQT" ] && BLUETOOTH_PKGS="$BLUETOOTH_PKGS blueman"
  arch-chroot /mnt pacman -S --noconfirm $BLUETOOTH_PKGS
  arch-chroot /mnt systemctl enable bluetooth
fi

# ── GRUB ───────────────────────────────────────────────────
info "Instalando GRUB..."

arch-chroot /mnt pacman -S --noconfirm grub

if [ -d /sys/firmware/efi ]; then
  arch-chroot /mnt pacman -S --noconfirm efibootmgr
  arch-chroot /mnt grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot \
    --bootloader-id=Arch
else
  arch-chroot /mnt grub-install \
    --target=i386-pc \
    /dev/$INSTDISK
fi

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
ok "GRUB instalado"

# ── Otimizações ────────────────────────────────────────────
info "Aplicando otimizações..."

# I/O Scheduler
cat > /mnt/etc/udev/rules.d/60-ioscheduler.rules <<'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF

# Dirty pages
cat > /mnt/etc/sysctl.d/99-desktop-io.conf <<'EOF'
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
vm.dirty_writeback_centisecs = 300
vm.dirty_expire_centisecs = 1500
vm.dirty_ratio_bytes = 134217728
vm.page-cluster = 3
vm.vfs_cache_pressure = 50
EOF

# USB sync
cat > /mnt/etc/udev/rules.d/99-udisks2-usb_mount.rules <<'EOF'
SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", ENV{UDISKS_MOUNT_OPTIONS_DEFAULTS}+="sync", ENV{UDISKS_MOUNT_OPTIONS_ALLOW}+="sync"
EOF

# FreeType
cat > /mnt/etc/profile.d/freetype2.sh <<'EOF'
export FREETYPE_PROPERTIES="truetype:interpreter-version=40"
EOF

# TRIM para SSDs
if lsblk -d -o ROTA | grep -q "^0$"; then
  arch-chroot /mnt systemctl enable fstrim.timer
fi

# Disable wait-online
arch-chroot /mnt systemctl disable NetworkManager-wait-online.service 2>/dev/null || true

ok "Otimizações aplicadas"

# ── User dirs ──────────────────────────────────────────────
arch-chroot /mnt xdg-user-dirs-update 2>/dev/null || true

# ── Senhas ─────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}${BOLD}Defina as senhas:${NC}"
echo -e "  ${CYAN}▸${NC} Senha do usuário $USERNAME:"
arch-chroot /mnt passwd "$USERNAME"

echo -e "  ${CYAN}▸${NC} Senha do root:"
arch-chroot /mnt passwd

# ── Concluído ──────────────────────────────────────────────
clear
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║        INSTALAÇÃO CONCLUÍDA!             ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  Reinicie o sistema: ${BOLD}reboot${NC}"
echo ""

if [ "$DE" = "Niri" ]; then
  echo -e "  ${YELLOW}Após reiniciar:${NC}"
  echo -e "  1. Faça login como $USERNAME"
  echo -e "  2. Execute: ${BOLD}sudo bash ~/scripts/install-niri.sh${NC}"
  echo ""
fi

echo ""
