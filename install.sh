#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. Обновление системы и установка базовых утилит ==="
sudo pacman -Syu --needed --noconfirm git base-devel python

if ! command -v yay >/dev/null 2>&1; then
    echo "=== Установка yay (AUR) ==="
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
    (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

echo "=== 2. Установка Hyprland, Wayland, аудио, сети и SDDM ==="
sudo pacman -S --needed --noconfirm \
    hyprland xdg-desktop-portal-hyprland qt5-wayland qt6-wayland \
    hyprpolkitagent swaybg sddm xorg-server \
    pipewire pipewire-pulse pipewire-alsa wireplumber playerctl \
    networkmanager bluez bluez-utils \
    brightnessctl grim slurp wl-clipboard wf-recorder

echo "=== 3. Установка шрифтов, тем и Quickshell ==="
sudo pacman -S --needed --noconfirm \
    adw-gtk-theme qt6ct nwg-look \
    noto-fonts noto-fonts-emoji ttf-nunito ttf-jetbrains-mono-nerd

yay -S --needed --noconfirm \
    quickshell-git ttf-material-symbols-variable-git gruvbox-plus-icon-theme

echo "=== 4. Опциональные программы ==="
ask_install() {
    read -rp "Установить $1? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

OPT_PKGS=()
AUR_OPT=()
ask_install "Ghostty (терминал)"        && OPT_PKGS+=(ghostty)
ask_install "Nautilus (файлы)"          && OPT_PKGS+=(nautilus)
ask_install "Firefox (браузер)"         && OPT_PKGS+=(firefox)
ask_install "Telegram Desktop"          && OPT_PKGS+=(telegram-desktop)
ask_install "Vesktop (Discord, AUR)"    && AUR_OPT+=(vesktop-bin)

if [ ${#OPT_PKGS[@]} -gt 0 ]; then
    sudo pacman -S --needed --noconfirm "${OPT_PKGS[@]}"
fi
if [ ${#AUR_OPT[@]} -gt 0 ]; then
    yay -S --needed --noconfirm "${AUR_OPT[@]}"
fi

if ask_install "Драйверы и фиксы для VMware (open-vm-tools + software render)"; then
    sudo pacman -S --needed --noconfirm open-vm-tools
    sudo systemctl enable vmtoolsd
    grep -q "AQ_NO_ATOMIC" /etc/environment || sudo tee -a /etc/environment << 'ENVEOF'
WLR_RENDERER_ALLOW_SOFTWARE=1
LIBGL_ALWAYS_SOFTWARE=1
AQ_NO_ATOMIC=1
ENVEOF
fi

echo "=== 5. Копирование конфигов, обоев и темы SDDM ==="
mkdir -p ~/.config ~/.local/state ~/Pictures/Wallpapers ~/.themes
cp -r "$REPO_DIR/config/"* ~/.config/
[ -d "$REPO_DIR/themes" ] && cp -r "$REPO_DIR/themes/"* ~/.themes/ 2>/dev/null || true
chmod +x ~/.config/hypr/scroll-drag.sh 2>/dev/null || true

sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
sudo cp -r "$REPO_DIR/sddm-theme/everforest-m3" /usr/share/sddm/themes/
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null << 'SDDMEOF'
[Theme]
Current=everforest-m3
SDDMEOF

gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || true
gsettings set org.gnome.desktop.interface icon-theme 'Gruvbox-Plus-Dark' || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.interface font-name 'Nunito 10' || true

fc-cache -fv >/dev/null

echo "=== 6. Включение системных сервисов ==="
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable sddm

echo "Готово! Перезагрузи систему командой: sudo reboot"
