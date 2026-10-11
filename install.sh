#!/usr/bin/env bash
set -euo pipefail

# arch-niri installer
# Symlinks rice/ and dotfiles/ into ~/.config, copies the wallpaper,
# and installs the required packages.

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="$HOME"
CONFIG_DIR="$USER_HOME/.config"
WALLPAPER_DIR="$USER_HOME/wallpapers"

# ── Packages ─────────────────────────────────────────────────────────
PACMAN_PKGS=(
    niri
    waybar
    swaybg
    swayidle
    mako
    alacritty
    fuzzel
    ranger
    zathura
    zathura-pdf-mupdf
    mpv
    ueberzugpp
    playerctl
    pipewire
    wireplumber
    brightnessctl
    zsh
    zsh-syntax-highlighting
    zsh-autosuggestions
    cava
    cliphist
    wl-clipboard
    pacman-contrib
)

AUR_PKGS=(
    swaylock-effects
)

# ── Helpers ──────────────────────────────────────────────────────────
info()  { printf '\033[1;32m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }

link_config() {
    local src="$1" dest="$2"
    if [ -L "$dest" ]; then
        rm "$dest"
    elif [ -e "$dest" ]; then
        warn "Backing up existing $dest → ${dest}.bak"
        mv "$dest" "${dest}.bak"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    info "Linked $dest → $src"
}

# ── Install packages ─────────────────────────────────────────────────
info "Installing pacman packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

if command -v yay &>/dev/null; then
    info "Installing AUR packages (yay)..."
    yay -S --needed --noconfirm "${AUR_PKGS[@]}"
elif command -v paru &>/dev/null; then
    info "Installing AUR packages (paru)..."
    paru -S --needed --noconfirm "${AUR_PKGS[@]}"
else
    warn "No AUR helper found (yay/paru). Install manually: ${AUR_PKGS[*]}"
fi

# ── Rice configs (niri, waybar, swaylock, mako, ranger, zathura, mpv) ─
for app in niri waybar swaylock mako ranger zathura mpv; do
    link_config "$REPO_DIR/rice/.config/$app" "$CONFIG_DIR/$app"
done

# ── Dotfiles (alacritty, fuzzel, ueberzugpp) ─────────────────────────
for app in alacritty fuzzel ueberzugpp; do
    link_config "$REPO_DIR/dotfiles/.config/$app" "$CONFIG_DIR/$app"
done

# ── Shell ─────────────────────────────────────────────────────────────
link_config "$REPO_DIR/dotfiles/.zshrc" "$USER_HOME/.zshrc"
if [ "$(basename "$SHELL")" != "zsh" ]; then
    info "Changing default shell to zsh..."
    chsh -s "$(command -v zsh)"
fi

# ── Wallpaper ─────────────────────────────────────────────────────────
mkdir -p "$WALLPAPER_DIR"
if [ ! -f "$WALLPAPER_DIR/green.jpg" ]; then
    cp "$REPO_DIR/assets/wallpapers/green.jpg" "$WALLPAPER_DIR/green.jpg"
    info "Copied wallpaper to $WALLPAPER_DIR/green.jpg"
else
    info "Wallpaper already exists at $WALLPAPER_DIR/green.jpg"
fi

# ── Patch YOUR_USER placeholders ──────────────────────────────────────
NIRI_CFG="$CONFIG_DIR/niri/config.kdl"
LOCK_CFG="$CONFIG_DIR/swaylock/config"
if grep -q 'YOUR_USER' "$NIRI_CFG" 2>/dev/null; then
    sed -i "s|/home/YOUR_USER|$USER_HOME|g" "$NIRI_CFG"
    info "Patched niri config with your home path"
fi
if grep -q 'YOUR_USER' "$LOCK_CFG" 2>/dev/null; then
    sed -i "s|/home/YOUR_USER|$USER_HOME|g" "$LOCK_CFG"
    info "Patched swaylock config with your home path"
fi

# ── Reminder ─────────────────────────────────────────────────────────
WEATHER_SH="$CONFIG_DIR/waybar/scripts/weather.sh"
if grep -q 'YOUR_CITY' "$WEATHER_SH" 2>/dev/null; then
    warn "Edit $WEATHER_SH and replace YOUR_CITY with your location for weather"
fi

CAVA_MIC="$CONFIG_DIR/waybar/scripts/cava-mic.sh"
CAVA_AUDIO="$CONFIG_DIR/waybar/scripts/cava-audio.sh"
if grep -q 'source = auto' "$CAVA_MIC" 2>/dev/null; then
    warn "For split cava, edit $CAVA_MIC and $CAVA_AUDIO with your PulseAudio source names (pactl list short sources)"
fi

# ── Done ──────────────────────────────────────────────────────────────
info "Done. Log out and start a niri session to see the setup."
info "For GPU passthrough, see passthrough/README.md"
