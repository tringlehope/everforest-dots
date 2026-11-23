#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    printf "\033[1;31m[Ошибка]\033[0m Не запускай скрипт от root (sudo) — он сам запросит пароль, когда понадобится.\n"
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
AUR_HELPER=""

C_RESET="\033[0m"
C_GREEN="\033[38;2;167;192;128m"
C_AQUA="\033[38;2;131;192;146m"
C_YELLOW="\033[38;2;219;188;127m"
C_RED="\033[38;2;230;126;128m"
C_FG="\033[38;2;211;198;170m"
C_MUTED="\033[38;2;133;146;137m"
C_BOLD="\033[1m"

cleanup_tty() {
    tput cnorm 2>/dev/null || printf "\033[?25h"
}
trap cleanup_tty EXIT

info()  { printf "${C_GREEN}${C_BOLD}[Everforest]${C_RESET} ${C_FG}%s${C_RESET}\n" "$1"; }
warn()  { printf "${C_YELLOW}${C_BOLD}[Внимание]${C_RESET} ${C_FG}%s${C_RESET}\n" "$1"; }
error() { printf "${C_RED}${C_BOLD}[Ошибка]${C_RESET} ${C_FG}%s${C_RESET}\n" "$1"; }
step()  { printf "\n${C_AQUA}${C_BOLD}==> %s${C_RESET}\n" "$1"; }

# Встроенный TUI: выбор одного пункта (результат в TUI_CHOICE)
tui_select() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local cur=0
    local key rest

    tput civis 2>/dev/null || printf "\033[?25l"
    printf "\n${C_GREEN}${C_BOLD}╭─ %s${C_RESET}\n" "$title"
    printf "${C_MUTED}│  ↑/↓ — навигация, Enter — выбрать${C_RESET}\n"

    while true; do
        for ((i = 0; i < count; i++)); do
            if [ "$i" -eq "$cur" ]; then
                printf "${C_GREEN}${C_BOLD}│  ❯ %s${C_RESET}\033[K\n" "${options[$i]}"
            else
                printf "${C_MUTED}│    ${C_FG}%s${C_RESET}\033[K\n" "${options[$i]}"
            fi
        done

        IFS= read -rsn1 key || true
        if [[ "$key" == $'\x1b' ]]; then
IFS= read -rsn2 -t 0.05 rest || true
key+="$rest"
fi

case "$key" in
$'\x1b[A'|k|K) ((cur = (cur - 1 + count) % count)) ;;
$'\x1b[B'|j|J) ((cur = (cur + 1) % count)) ;;
"") break ;;
esac
printf "\033[%dA" "$count"
done

printf "${C_GREEN}${C_BOLD}╰────────────────────────────────────────${C_RESET}\n"
tput cnorm 2>/dev/null || printf "\033[?25h"
TUI_CHOICE=$cur
}

# Встроенный TUI: множественный выбор чекбоксами (результат в массиве TUI_SELECTED)
tui_checklist() {
local title="$1"
shift
local options=("$@")
local count=${#options[@]}
local cur=0
local checked=()
local key rest

for ((i = 0; i < count; i++)); do checked[$i]=0; done

tput civis 2>/dev/null || printf "\033[?25l"
printf "\n${C_GREEN}${C_BOLD}╭─ %s${C_RESET}\n" "$title"
printf "${C_MUTED}│  ↑/↓ — навигация, Пробел — отметить, Enter — готово${C_RESET}\n"

while true; do
for ((i = 0; i < count; i++)); do
local mark="[ ]"
local mark_col="$C_MUTED"
if [ "${checked[$i]}" -eq 1 ]; then
mark="[✓]"
mark_col="$C_GREEN"
fi
if [ "$i" -eq "$cur" ]; then
printf "${C_GREEN}${C_BOLD}│  ❯ ${mark_col}%s ${C_FG}${C_BOLD}%s${C_RESET}\033[K\n" "$mark" "${options[$i]}"
else
printf "${C_MUTED}│    ${mark_col}%s ${C_FG}%s${C_RESET}\033[K\n" "$mark" "${options[$i]}"
fi
done

IFS= read -rsn1 key || true
if [[ "$key" == $'\x1b' ]]; then
IFS= read -rsn2 -t 0.05 rest || true
key+="$rest"
fi

case "$key" in
$'\x1b[A'|k|K) ((cur = (cur - 1 + count) % count)) ;;
$'\x1b[B'|j|J) ((cur = (cur + 1) % count)) ;;
" ")
if [ "${checked[$cur]}" -eq 1 ]; then checked[$cur]=0; else checked[$cur]=1; fi
;;
"") break ;;
esac
printf "\033[%dA" "$count"
done

printf "${C_GREEN}${C_BOLD}╰────────────────────────────────────────${C_RESET}\n"
tput cnorm 2>/dev/null || printf "\033[?25h"

TUI_SELECTED=()
for ((i = 0; i < count; i++)); do
if [ "${checked[$i]}" -eq 1 ]; then
TUI_SELECTED+=("$i")
fi
done
}

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
if [ "$AUR_HELPER" = "yay" ]; then "$AUR_HELPER" -S --needed --noconfirm --answerclean None --answerdiff None --answeredit None "${aur_pkgs[@]}"; else "$AUR_HELPER" -S --needed --noconfirm --skipreview "${aur_pkgs[@]}"; fi
fi
}

backup_and_copy_configs() {
step "Копирование конфигов (хранится 1 последняя копия в $BACKUP_DIR)"
rm -rf "$HOME"/.config-backup-* 2>/dev/null || true
mkdir -p "$HOME/.config" \
        "$HOME/Pictures/Wallpapers/Everforest" \
        "$HOME/Pictures/Wallpapers/Catppuccin Macchiato" \
        "$HOME/Pictures/Wallpapers/Graphite" \
        "$HOME/Pictures/Wallpapers/Windows 7" \
        "$HOME/Pictures/Screenshots"

local backed_up=0
for d in hypr quickshell gtk-3.0 gtk-4.0 qt6ct kitty fish fontconfig; do
if [ -e "$REPO_DIR/config/$d" ]; then
if [ -e "$HOME/.config/$d" ]; then
mkdir -p "$BACKUP_DIR"
cp -a "$HOME/.config/$d" "$BACKUP_DIR/$d"
backed_up=1
fi
mkdir -p "$HOME/.config/$d"
if [ "$d" = "gtk-4.0" ]; then
rm -rf "$HOME/.config/gtk-4.0"/{assets,gtk.css,gtk-dark.css}
fi
cp -af "$REPO_DIR/config/$d/." "$HOME/.config/$d/"
fi
done

if [ -f "$REPO_DIR/config/starship.toml" ]; then
if [ -f "$HOME/.config/starship.toml" ]; then
mkdir -p "$BACKUP_DIR"
cp -a "$HOME/.config/starship.toml" "$BACKUP_DIR/starship.toml"
backed_up=1
fi
cp -af "$REPO_DIR/config/starship.toml" "$HOME/.config/starship.toml"
fi

if [ "$backed_up" -eq 0 ]; then
rmdir "$BACKUP_DIR" 2>/dev/null || true
else
info "Резервная копия старых конфигов: $BACKUP_DIR"
fi

if [ -d "$REPO_DIR/wallpapers" ]; then
cp -an "$REPO_DIR/wallpapers/." "$HOME/Pictures/Wallpapers/" 2>/dev/null || cp -af "$REPO_DIR/wallpapers/." "$HOME/Pictures/Wallpapers/"
fi
fc-cache -f >/dev/null 2>&1 || true
}

setup_sddm() {
local current_dm=""
if [ -L /etc/systemd/system/display-manager.service ]; then
current_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
fi

if [ -n "$current_dm" ]; then
warn "Обнаружен активный менеджер входа: $current_dm"
tui_select "Заменить $current_dm на SDDM с темой everforest-m3?" \
            "Нет, оставить текущий ($current_dm)" \
            "Да, заменить на SDDM + everforest-m3"
if [ "$TUI_CHOICE" -ne 1 ]; then
info "Текущий менеджер входа ($current_dm) сохранён."
return 0
fi
sudo systemctl disable "$current_dm" 2>/dev/null || true
else
tui_select "Установить экран входа SDDM с темой everforest-m3?" \
            "Да, установить и включить SDDM" \
            "Нет, пропустить"
if [ "$TUI_CHOICE" -ne 0 ]; then
info "Установка SDDM пропущена."
return 0
fi
fi

install_pkg_list sddm
if [ -d "$REPO_DIR/sddm-theme/everforest-m3" ]; then
sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
sudo rm -rf /usr/share/sddm/themes/everforest-m3
sudo cp -a "$REPO_DIR/sddm-theme/everforest-m3" /usr/share/sddm/themes/everforest-m3
printf "[Theme]\nCurrent=everforest-m3\n" | sudo tee /etc/sddm.conf.d/everforest.conf >/dev/null
fi
sudo systemctl enable sddm.service
info "SDDM настроен и включён."
}

clear
printf "${C_GREEN}${C_BOLD}"
printf "╔══════════════════════════════════════════════╗\n"
printf "║     Everforest Hyprland + Quickshell Setup   ║\n"
printf "╚══════════════════════════════════════════════╝\n"
printf "${C_RESET}"

tui_select "Выберите режим работы" \
    "Полная установка (система + софт + конфиги)" \
    "Обновление (только конфиги, шрифты, иконки)" \
    "Выход"

if [ "$TUI_CHOICE" -eq 2 ]; then
info "Выход без изменений."
exit 0
fi

if [ "$TUI_CHOICE" -eq 1 ]; then
step "Обновление шрифтов, иконок, темы и конфигов"
install_pkg_list \
        adw-gtk-theme qt6ct qt5-wayland nwg-look \
        noto-fonts noto-fonts-emoji ttf-nunito ttf-jetbrains-mono-nerd \
        gruvbox-plus-icon-theme ttf-material-symbols-variable-git
backup_and_copy_configs
if [ -d /usr/share/sddm/themes/everforest-m3 ] && [ -d "$REPO_DIR/sddm-theme/everforest-m3" ]; then
tui_select "Обновить тему SDDM (everforest-m3)?" "Нет" "Да, обновить"
if [ "$TUI_CHOICE" -eq 1 ]; then
sudo rm -rf /usr/share/sddm/themes/everforest-m3
sudo cp -a "$REPO_DIR/sddm-theme/everforest-m3" /usr/share/sddm/themes/everforest-m3
fi
fi
info "Готово! Обновление завершено."
exit 0
fi

# Выбор приложений через TUI до начала установки
BR_MAP=("firefox" "zen-browser-bin" "chromium" "opera")
tui_checklist "Какие браузеры установить?" \
    "Firefox" \
    "Zen Browser (AUR)" \
    "Chromium" \
    "Opera"
BR_PKGS=()
for idx in "${TUI_SELECTED[@]}"; do
BR_PKGS+=("${BR_MAP[$idx]}")
done

tui_select "Какой офисный пакет установить?" \
    "OnlyOffice (AUR)" \
    "LibreOffice Fresh" \
    "Ничего не ставить"
OFF_PKGS=()
case "$TUI_CHOICE" in
0) OFF_PKGS+=("onlyoffice-bin") ;;
1) OFF_PKGS+=("libreoffice-fresh") ;;
esac

step "1/4 Установка базового окружения и утилит"

BYPASS_HAPP=0
BYPASS_ZAPRET=0
tui_checklist "Средства обхода блокировок (опционально):"     "Happ (VPN-клиент, AUR)"     "Zapret (обход DPI, Snowy-Fluffy)"
for _idx in "${TUI_SELECTED[@]}"; do
    case "$_idx" in
        0) BYPASS_HAPP=1 ;;
        1) BYPASS_ZAPRET=1 ;;
    esac
done

install_pkg_list \
    hyprland quickshell-git swaybg xdg-desktop-portal-hyprland hyprpolkitagent \
    kitty fish starship nautilus file-roller unzip 7zip unrar \
    loupe showtime papers gst-libav gst-plugins-good \
    pipewire pipewire-pulse wireplumber playerctl \
    networkmanager bluez bluez-utils \
    grim slurp wl-clipboard cliphist wf-recorder ffmpeg \
    flatpak fuse2 adw-gtk-theme qt6ct qt5-wayland nwg-look \
    noto-fonts noto-fonts-emoji ttf-nunito ttf-jetbrains-mono-nerd \
    gruvbox-plus-icon-theme ttf-material-symbols-variable-git

if [ "${#BR_PKGS[@]}" -gt 0 ]; then
step "2/4 Установка выбранных браузеров: ${BR_PKGS[*]}"
install_pkg_list "${BR_PKGS[@]}"
fi

if [ "${#OFF_PKGS[@]}" -gt 0 ]; then
step "3/4 Установка офисного пакета: ${OFF_PKGS[*]}"
install_pkg_list "${OFF_PKGS[@]}"
fi

step "4/4 Настройка сервисов, тем и ассоциаций"
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
Exec=kitty -e bash -c 'sudo pacman -U "$1"; echo ""; read -rp "Нажмите Enter для закрытия..."' _ %f
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



# Тема GTKAero + AeroIcons для режима Windows 7
mkdir -p "$HOME/.local/share/themes" "$HOME/.local/share/icons"
if [ ! -d "$HOME/.local/share/themes/GTKAero" ]; then
git clone --depth 1 https://github.com/User738git/GTKAero.git "$HOME/.local/share/themes/GTKAero" 2>/dev/null || true
if [ -f "$HOME/.local/share/themes/GTKAero/AeroIcons.tar.gz" ]; then
tar -xzf "$HOME/.local/share/themes/GTKAero/AeroIcons.tar.gz" -C "$HOME/.local/share/icons/" 2>/dev/null || true
fi
fi

# Ассоциации файлов по умолчанию
for m in image/png image/jpeg image/webp image/gif image/svg+xml; do xdg-mime default org.gnome.Loupe.desktop "$m" 2>/dev/null || true; done
for m in video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo; do xdg-mime default org.gnome.Showtime.desktop "$m" 2>/dev/null || true; done
for m in application/pdf image/vnd.djvu; do xdg-mime default org.gnome.Papers.desktop "$m" 2>/dev/null || true; done
for m in application/zip application/x-tar application/gzip application/x-7z-compressed application/x-rar application/x-xz application/x-bzip2 application/zstd; do xdg-mime default org.gnome.FileRoller.desktop "$m" 2>/dev/null || true; done

backup_and_copy_configs

if [ "${BYPASS_HAPP:-0}" -eq 1 ]; then
    info "Устанавливаю Happ (happ-desktop-bin из AUR)..."
    install_pkg_list happ-desktop-bin
fi

if [ "${BYPASS_ZAPRET:-0}" -eq 1 ]; then
    info "Запускаю установщик Zapret..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/Snowy-Fluffy/zapret.installer/refs/heads/main/installer.sh)" || warn "Установка Zapret пропущена или завершилась с ошибкой."
fi

setup_sddm

if command -v fish >/dev/null 2>&1; then
sudo chsh -s "$(command -v fish)" "$USER" 2>/dev/null || true
fi

echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/pacman" | sudo tee /etc/sudoers.d/everforest-update >/dev/null
sudo chmod 440 /etc/sudoers.d/everforest-update

printf "\n${C_GREEN}${C_BOLD}Готово! Всё установлено, перезайди в сессию или перезагрузи ПК.${C_RESET}\n"
