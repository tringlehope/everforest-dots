#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
AUR_HELPER=""

info()  { printf '\033[1;32m[Everforest]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[Внимание]\033[0m %s\n' "$1"; }
error() { printf '\033[1;31m[Ошибка]\033[0m %s\n' "$1"; }

detect_aur_helper() {
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    fi
}

ensure_aur_helper() {
    detect_aur_helper
    if [ -n "$AUR_HELPER" ]; then
        return 0
    fi
    info "AUR-помощник не найден. Устанавливаю yay-bin..."
    sudo pacman -S --needed --noconfirm base-devel git
    local tmpdir
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
    (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    AUR_HELPER="yay"
}

install_pkg() {
    local pkg="$1"
    if pacman -Si "$pkg" &>/dev/null; then
        sudo pacman -S --needed --noconfirm "$pkg"
    else
        ensure_aur_helper
        "$AUR_HELPER" -S --needed --noconfirm "$pkg"
    fi
}

install_pkg_list() {
    local pac_pkgs=()
    local aur_pkgs=()
    for pkg in "$@"; do
        if pacman -Si "$pkg" &>/dev/null; then
            pac_pkgs+=("$pkg")
        else
            aur_pkgs+=("$pkg")
        fi
    done
    if [ "${#pac_pkgs[@]}" -gt 0 ]; then
        sudo pacman -S --needed --noconfirm "${pac_pkgs[@]}"
    fi
    if [ "${#aur_pkgs[@]}" -gt 0 ]; then
        ensure_aur_helper
        "$AUR_HELPER" -S --needed --noconfirm "${aur_pkgs[@]}"
    fi
}

backup_and_copy_configs() {
    info "Копирую конфиги (сохраняю 1 последнюю резервную копию в $BACKUP_DIR)..."
    rm -rf "$HOME"/.config-backup-* 2>/dev/null || true
    mkdir -p "$HOME/.config" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"
    local backed_up=0
    for d in hypr quickshell gtk-3.0 gtk-4.0 qt6ct ghostty fontconfig; do
        if [ -e "$REPO_DIR/config/$d" ]; then
            if [ -e "$HOME/.config/$d" ]; then
                mkdir -p "$BACKUP_DIR"
                cp -a "$HOME/.config/$d" "$BACKUP_DIR/$d"
                backed_up=1
            fi
            mkdir -p "$HOME/.config/$d"
            cp -af "$REPO_DIR/config/$d/." "$HOME/.config/$d/"
        fi
    done
    if [ "$backed_up" -eq 0 ]; then
        rmdir "$BACKUP_DIR" 2>/dev/null || true
    else
        info "Резервная копия старых конфигов: $BACKUP_DIR"
    fi
    fc-cache -f >/dev/null 2>&1 || true
}

setup_sddm() {
    local current_dm=""
    if [ -L /etc/systemd/system/display-manager.service ]; then
        current_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
    fi

    if [ -n "$current_dm" ]; then
        echo ""
        warn "Обнаружен активный менеджер входа: $current_dm"
        read -rp "Заменить его на SDDM с темой everforest-m3? [y/N]: " dm_ans
        if [[ ! "$dm_ans" =~ ^[YyДд]$ ]]; then
            info "Текущий менеджер входа ($current_dm) сохранён без изменений."
            return 0
        fi
        sudo systemctl disable "$current_dm" 2>/dev/null || true
    else
        echo ""
        read -rp "Менеджер входа не обнаружен. Установить и включить SDDM с темой everforest-m3? [Y/n]: " dm_ans
        if [[ "$dm_ans" =~ ^[NnНн]$ ]]; then
            info "Установка SDDM пропущена."
            return 0
        fi
    fi

    install_pkg_list sddm
    if [ -d "$REPO_DIR/sddm-theme/everforest-m3" ]; then
        sudo mkdir -p /usr/share/sddm/themes
        sudo rm -rf /usr/share/sddm/themes/everforest-m3
        sudo cp -a "$REPO_DIR/sddm-theme/everforest-m3" /usr/share/sddm/themes/everforest-m3
        sudo mkdir -p /etc/sddm.conf.d
        printf '[Theme]\nCurrent=everforest-m3\n' | sudo tee /etc/sddm.conf.d/everforest.conf >/dev/null
    fi
    sudo systemctl enable sddm.service
    info "SDDM настроен и включён."
}

echo "============================================"
echo "   Everforest Hyprland + Quickshell Setup"
echo "============================================"
echo "1) Установить (система + софт + конфиги)"
echo "2) Обновить   (только конфиги, шрифты, иконки)"
echo ""
read -rp "Выберите действие [1/2]: " MODE

if [ "$MODE" = "2" ]; then
    info "Режим обновления: ставлю только шрифты, иконки и тему..."
    install_pkg_list \
        adw-gtk-theme qt6ct nwg-look \
        noto-fonts noto-fonts-emoji ttf-nunito ttf-jetbrains-mono-nerd \
        gruvbox-plus-icon-theme ttf-material-symbols-variable-git bauh
    backup_and_copy_configs
    if [ -d /usr/share/sddm/themes/everforest-m3 ] && [ -d "$REPO_DIR/sddm-theme/everforest-m3" ]; then
        read -rp "Обновить тему SDDM (everforest-m3)? [y/N]: " sddm_upd
        if [[ "$sddm_upd" =~ ^[YyДд]$ ]]; then
            sudo rm -rf /usr/share/sddm/themes/everforest-m3
            sudo cp -a "$REPO_DIR/sddm-theme/everforest-m3" /usr/share/sddm/themes/everforest-m3
        fi
    fi
    info "Обновление завершено!"
    exit 0
fi

if [ "$MODE" != "1" ]; then
    error "Неверный выбор. Выход."
    exit 1
fi

info "Режим полной установки. Устанавливаю базовые пакеты и окружение..."
install_pkg_list \
    hyprland quickshell-git swaybg xdg-desktop-portal-hyprland hyprpolkitagent \
    ghostty nautilus file-roller unzip 7zip unrar \
    loupe showtime papers gst-libav gst-plugins-good \
    pipewire pipewire-pulse wireplumber playerctl \
    networkmanager bluez bluez-utils brightnessctl \
    grim slurp wl-clipboard cliphist wf-recorder ffmpeg \
    flatpak fuse2 adw-gtk-theme qt6ct nwg-look \
    noto-fonts noto-fonts-emoji ttf-nunito ttf-jetbrains-mono-nerd \
    gruvbox-plus-icon-theme ttf-material-symbols-variable-git

sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
sudo systemctl enable --now bluetooth.service 2>/dev/null || true


sudo mkdir -p /etc/polkit-1/rules.d
cat << 'PKRULE' | sudo tee /etc/polkit-1/rules.d/50-flatpak.rules >/dev/null
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.Flatpak.") === 0 && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
PKRULE

# Flathub и ассоциация .pkg.tar.zst для Nautilus
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
mkdir -p "$HOME/.local/share/mime/packages" "$HOME/.local/share/applications"
cat << 'MIME' > "$HOME/.local/share/mime/packages/alpm-pkg.xml"
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-alpm-package">
    <comment>Arch Linux package</comment>
    <glob pattern="*.pkg.tar.zst" weight="100"/>
    <glob pattern="*.pkg.tar.xz" weight="100"/>
  </mime-type>
</mime-info>
MIME
cat << 'DESK' > "$HOME/.local/share/applications/pkg-installer.desktop"
[Desktop Entry]
Name=Установить пакет (.pkg.tar.zst)
Comment=Установка локального пакета Arch Linux
Exec=ghostty -e bash -c 'sudo pacman -U "$1"; echo ""; read -rp "Нажмите Enter для закрытия..."' _ %f
Icon=system-software-install
Terminal=false
Type=Application
Categories=System;PackageManager;
MimeType=application/x-alpm-package;
NoDisplay=true
DESK
update-mime-database "$HOME/.local/share/mime" 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
xdg-mime default pkg-installer.desktop application/x-alpm-package 2>/dev/null || true


# Выбор браузера (можно ввести несколько цифр подряд, например 234)
echo ""
echo "Какой браузер установить? (можно несколько цифр подряд, например 234)"
echo "1. Firefox"
echo "2. Zen Browser"
echo "3. Chromium"
echo "4. Opera"
echo "0. Ничего"
read -rp "Выбор: " BR_ANS

BR_PKGS=()
if [[ "$BR_ANS" != *"0"* ]] && [ -n "$BR_ANS" ]; then
    for ((i=0; i<${#BR_ANS}; i++)); do
        case "${BR_ANS:$i:1}" in
            1) BR_PKGS+=("firefox") ;;
            2) BR_PKGS+=("zen-browser-bin") ;;
            3) BR_PKGS+=("chromium") ;;
            4) BR_PKGS+=("opera") ;;
        esac
    done
fi
if [ "${#BR_PKGS[@]}" -gt 0 ]; then
    info "Устанавливаю браузер(ы): ${BR_PKGS[*]}"
    install_pkg_list "${BR_PKGS[@]}"
fi

# Выбор офисного пакета
echo ""
echo "Какой офисный пакет установить?"
echo "1. OnlyOffice"
echo "2. LibreOffice"
echo "0. Ничего"
read -rp "Выбор: " OFF_ANS

OFF_PKGS=()
if [[ "$OFF_ANS" != *"0"* ]] && [ -n "$OFF_ANS" ]; then
    for ((i=0; i<${#OFF_ANS}; i++)); do
        case "${OFF_ANS:$i:1}" in
            1) OFF_PKGS+=("onlyoffice-bin") ;;
            2) OFF_PKGS+=("libreoffice-fresh") ;;
        esac
    done
fi
if [ "${#OFF_PKGS[@]}" -gt 0 ]; then
    info "Устанавливаю офис: ${OFF_PKGS[*]}"
    install_pkg_list "${OFF_PKGS[@]}"
fi

# Средства обхода блокировок
echo ""
echo "Поставить ли средства обхода блокировок?"
echo "0. Ничего (пока в разработке)"
read -rp "Выбор [0]: " BYPASS_ANS

backup_and_copy_configs
setup_sddm

echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/pacman" | sudo tee /etc/sudoers.d/everforest-update >/dev/null
sudo chmod 440 /etc/sudoers.d/everforest-update
info "Готово! Все файлы и настройки установлены безопасно."
