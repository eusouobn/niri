# Dotfiles — Niri + Noctalia Shell + Arch Linux

Configurações pessoais do meu ambiente Arch Linux. Perfeito para quem quer um Arch bonito, funcional e pronto para o dia a dia sem precisar configurar nada na mão.

## O que vem instalado

| Categoria | Programas |
|-----------|-----------|
| **Compositor** | Niri (Wayland, scrollável por workspaces) |
| **Shell/Gerenciador** | Noctalia Shell (barra, widgets, painéis) |
| **Terminal** | Kitty + Fish + JetBrainsMono Nerd Font |
| **Tema** | Escuro (adw-gtk3-dark, Breeze Dark) |
| **Login** | SDDM + sddm-astronaut-theme |
| **Navegador** | Firefox |
| **Arquivos** | Dolphin (KDE) |
| **Editor** | VS Code, Kate |
| **Áudio** | PipeWire + WirePlumber |
| **Bluetooth** | BlueZ + Blueman |
| **Firewall** | UFW + GUFW |
| **Cache KDE** | Hook pós-transação + environment.d |
| **Ícones** | Papirus-Dark |
| **Fontes** | Ubuntu Bold, Ubuntu Mono Nerd Bold |

## Para instalar

### 1. Tenha o Arch Linux instalado

Se ainda não instalou, use o `archinstall`:

```bash
archinstall
```

Durante a instalação:
- **Perfil**: selecione `xorg`
- **Driver**: escolha o da sua placa (`NVIDIA`, `AMD`, `Intel`, `VMware`)

Após reiniciar, faça login com seu usuário.

### 2. Rode o script de instalação

```bash
git clone https://github.com/eusouobn/niri
cd niri
bash install-niri.sh
```

Ou diretamente (sem clonar):

```bash
curl -sS https://raw.githubusercontent.com/eusouobn/niri/main/install-niri.sh | bash
```

**O script faz tudo sozinho:**

- Instala todos os pacotes (Niri, Noctalia Shell, Dolphin, Firefox, áudio, Bluetooth, firewall, etc.)
- Configura tema escuro, ícones e fontes
- Cria o wrapper do GUFW (para abrir o firewall em modo escuro sem erros)
- Configura SDDM com tema astronauta
- Ativa Bluetooth, áudio e serviços necessários
- No final pergunta se quer iniciar o SDDM ou reiniciar

## Atalhos do Niri

| Atalho | Ação |
|--------|------|
| `Mod+T` | Abrir terminal (Kitty) |
| `Mod+D` | Lançador de apps (Noctalia Shell) |
| `Mod+E` | Abrir Dolphin |
| `Mod+Q` | Fechar janela |
| `Mod+F` | Maximizar coluna |
| `Mod+Shift+F` | Tela cheia |
| `Mod+1` a `Mod+9` | Trocar de workspace |
| `Mod+H/J/K/L` | Navegar entre janelas |
| `Mod+Shift+E` | Sair do Niri |
| `Print` | Screenshot da tela |
| `Alt+Tab` | Alternar janelas recentes |

> `Mod` = tecla Super (a do Windows/Comando)

## Estrutura do projeto

```
niri/
├── install-niri.sh                   ← Script de instalação completo
├── .config/
│   ├── niri/config.kdl               ← Config do compositor
│   ├── noctalia/                      ← Tema e settings do Noctalia Shell
│   ├── fish/                          ← Config do Fish shell
│   ├── kitty/                         ← Config do terminal Kitty
│   ├── fastfetch/                     ← Info do sistema
│   ├── gtk-3.0/ gtk-4.0/             ← Tema escuro do GTK
│   ├── qt5ct/ qt6ct/                  ← Tema escuro do Qt
│   ├── nwg-look/                      ← Config do seletor de temas
│   ├── environment.d/                 ← Variáveis de ambiente para systemd
│   └── scripts/                       ← Scripts de screenshots e monitores
├── .local/
│   └── bin/gufw                       ← Wrapper do firewall
├── etc/
│   ├── pacman.d/hooks/kde-cache.hook  ← Hook pós-transação do pacman
│   └── udisks2/mount_options.conf    ← Escrita síncrona para USB
└── README.md
```

## Dicas

- **Atualizar o sistema**: `sudo pacman -Syu`
- **Instalar programas do AUR**: `yay -S nome-do-pacote`
- **Swap**: Criado automaticamente durante a instalação (4GB)
- **Otimização de I/O**: Aplicada automaticamente (scheduler + dirty pages)
- **Mudar tema de ícones**: `nwg-look`
