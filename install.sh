#!/usr/bin/env bash
# ============================================================
#  Probin's Arch Linux Bootstrap Script
#  Run after a fresh Arch install (with base + networking done)
#
#  Usage:
#    git clone git@github.com:pro0o/.dotconfigfiles.git ~/dotfiles
#    cd ~/dotfiles && chmod +x install.sh && ./install.sh
# ============================================================

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; }

# -----------------------------------------------------------
# 0. PREREQUISITE CHECKS
# -----------------------------------------------------------
info "Running prerequisite checks..."

FAIL=0

# Must not be root
if [[ "$EUID" -eq 0 ]]; then
    error "Don't run as root. Run as your normal user (sudo is used internally)."
    FAIL=1
fi

# sudo access
if ! sudo -n true 2>/dev/null; then
    warn "sudo password required..."
    if ! sudo true; then
        error "sudo access required. Make sure your user is in the sudoers file."
        FAIL=1
    fi
fi

# Internet
if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    error "No internet. Connect to wifi/ethernet first."
    FAIL=1
fi

# git
if ! command -v git &>/dev/null; then
    error "git not found. Run: sudo pacman -S git"
    FAIL=1
fi

# SSH access to GitHub (ssh may not exist yet on fresh install)
if command -v ssh &>/dev/null; then
    if ! ssh -T -o ConnectTimeout=5 git@github.com 2>&1 | grep -q "successfully authenticated"; then
        warn "GitHub SSH not configured. You may need it to push changes later."
        warn "  Generate key:  ssh-keygen -t ed25519"
        warn "  Add to GitHub: cat ~/.ssh/id_ed25519.pub"
    fi
else
    warn "ssh not found — will be available after packages install."
fi

if [[ "$FAIL" -eq 1 ]]; then
    error "Fix the above issues and re-run."
    exit 1
fi

info "All checks passed."
echo ""

# -----------------------------------------------------------
# 1. PACMAN PACKAGES
# -----------------------------------------------------------
info "Updating system..."
sudo pacman -Syu --noconfirm

info "Installing pacman packages..."
grep -v '^#\|^$' "$DOTFILES/pkglist-pacman.txt" | sudo pacman -S --needed --noconfirm -

# GPU drivers (auto-detect)
if lspci 2>/dev/null | grep -qi nvidia; then
    info "NVIDIA GPU detected — installing GPU drivers..."
    grep -v '^#\|^$' "$DOTFILES/pkglist-gpu-nvidia-intel.txt" | sudo pacman -S --needed --noconfirm -
else
    warn "No NVIDIA GPU detected — skipping GPU driver packages."
    warn "  If you have AMD, install mesa vulkan-radeon manually."
fi

# -----------------------------------------------------------
# 2. YAY (AUR helper)
# -----------------------------------------------------------
if ! command -v yay &>/dev/null; then
    info "Installing yay..."
    YAY_TMP="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$YAY_TMP/yay"
    (cd "$YAY_TMP/yay" && makepkg -si --noconfirm)
    rm -rf "$YAY_TMP"
else
    info "yay already installed, skipping."
fi

# -----------------------------------------------------------
# 3. AUR PACKAGES
# -----------------------------------------------------------
info "Installing AUR packages..."
grep -v '^#\|^$' "$DOTFILES/pkglist-aur.txt" | yay -S --needed --noconfirm -

# -----------------------------------------------------------
# 4. CHANGE DEFAULT SHELL TO ZSH
# -----------------------------------------------------------
if [[ "$SHELL" != */zsh ]]; then
    info "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
else
    info "Shell already zsh."
fi

# -----------------------------------------------------------
# 5. SYMLINK DOTFILES
# -----------------------------------------------------------
info "Symlinking dotfiles..."

symlink() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Backing up existing $dst -> ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -sf "$src" "$dst"
    info "  $dst -> $src"
}

# Shell
symlink "$DOTFILES/zsh/.zshrc"              "$HOME/.zshrc"

# i3
symlink "$DOTFILES/i3/config"               "$HOME/.config/i3/config"

# Alacritty (config + bundled themes)
symlink "$DOTFILES/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
symlink "$DOTFILES/alacritty/themes"         "$HOME/.config/alacritty/themes"

# Tmux
symlink "$DOTFILES/tmux/.tmux.conf"         "$HOME/.tmux.conf"

# Polybar
symlink "$DOTFILES/polybar/config.ini"      "$HOME/.config/polybar/config.ini"

# sxhkd
symlink "$DOTFILES/sxhkd/sxhkdrc"          "$HOME/.config/sxhkd/sxhkdrc"

# VS Code keybindings
symlink "$DOTFILES/vscode/keybindings.json" "$HOME/.config/Code/User/keybindings.json"

# -----------------------------------------------------------
# 6. GIT CONFIG
# -----------------------------------------------------------
info "Setting up git config..."
git config --global user.name "pro0o"
git config --global user.email "pp48041721@student.ku.edu.np"

# -----------------------------------------------------------
# 7. ZINIT (ZSH plugin manager) — auto-installs on first zsh load
#    but we pre-clone for faster first boot
# -----------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    info "Pre-installing zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
else
    info "Zinit already installed."
fi

# -----------------------------------------------------------
# 8. NVM (Node Version Manager) — before npm tools that need node
# -----------------------------------------------------------
NVM_DIR="$HOME/.nvm"
NVM_VERSION="v0.40.1"
if [[ ! -d "$NVM_DIR" ]]; then
    info "Installing nvm $NVM_VERSION..."
    NVM_SCRIPT="$(mktemp)"
    curl -o "$NVM_SCRIPT" "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh"
    NVM_CHECKSUM="$(sha256sum "$NVM_SCRIPT" | awk '{print $1}')"
    info "  nvm install script checksum: $NVM_CHECKSUM"
    info "  Verify at: https://github.com/nvm-sh/nvm/releases/tag/$NVM_VERSION"
    bash "$NVM_SCRIPT"
    rm -f "$NVM_SCRIPT"
else
    info "nvm already installed."
fi

# -----------------------------------------------------------
# 9. BUN
# -----------------------------------------------------------
if ! command -v bun &>/dev/null; then
    info "Installing bun..."
    BUN_SCRIPT="$(mktemp)"
    curl -fsSL -o "$BUN_SCRIPT" https://bun.sh/install
    BUN_CHECKSUM="$(sha256sum "$BUN_SCRIPT" | awk '{print $1}')"
    info "  bun install script checksum: $BUN_CHECKSUM"
    info "  Verify at: https://bun.sh/install"
    bash "$BUN_SCRIPT"
    rm -f "$BUN_SCRIPT"
else
    info "bun already installed."
fi

# -----------------------------------------------------------
# 10. TMUX PLUGIN MANAGER (TPM)
# -----------------------------------------------------------
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
    info "Installing tmux plugin manager..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
    info "TPM already installed."
fi

# -----------------------------------------------------------
# 11. ENABLE SERVICES
# -----------------------------------------------------------
info "Enabling system services..."

sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now docker 2>/dev/null || true
sudo systemctl enable --now tlp 2>/dev/null || true
sudo systemctl enable --now lightdm 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true

# Add user to docker group
if ! id -nG "$USER" | grep -qw docker; then
    info "Adding $USER to docker group..."
    sudo usermod -aG docker "$USER"
fi

# -----------------------------------------------------------
# 12. POWERLEVEL10K — symlink existing config
# -----------------------------------------------------------
if [[ -f "$DOTFILES/zsh/.p10k.zsh" ]]; then
    symlink "$DOTFILES/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
elif [[ -f "$HOME/.p10k.zsh" ]]; then
    info "p10k config exists at ~/.p10k.zsh (run 'p10k configure' to reconfigure)"
fi

# -----------------------------------------------------------
# 13. WALLPAPER
# -----------------------------------------------------------
if [[ -f "$DOTFILES/wallpaper/main.jpeg" ]]; then
    info "Setting up wallpaper..."
    mkdir -p "$HOME/Pictures"
    cp "$DOTFILES/wallpaper/main.jpeg" "$HOME/Pictures/main.jpeg"
else
    warn "No wallpaper found in dotfiles repo."
fi

# -----------------------------------------------------------
# 14. CONDA INIT (if miniconda installed via AUR in step 3)
# -----------------------------------------------------------
if [[ -d "$HOME/miniconda3" ]]; then
    info "Miniconda found — run 'conda init zsh' after first zsh launch if needed."
fi

# -----------------------------------------------------------
# DONE
# -----------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot (or log out and back in)"
echo "  2. First zsh launch will auto-install plugins"
echo "  3. In tmux, press Prefix + I to install tmux plugins"
echo "  4. Run 'p10k configure' if prompt looks off"
echo ""
