#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    printf "[1;31m[Ошибка][0m Не запускай скрипт от root (sudo) — он сам запросит пароль, когда понадобится.
"
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
AUR_HELPER=""
SUDO_KEEPALIVE_PID=""

C_RESET="[0m"
C_GREEN="[38;2;167;192;128m"
C_AQUA="[38;2;131;192;146m"
C_YELLOW="[38;2;219;188;127m"
C_RED="[38;2;230;126;128m"
C_FG="[38;2;211;198;170m"
C_MUTED="[38;2;133;146;137m"
C_BOLD="[1m"

start_sudo_keepalive() {
    sudo -v
    while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
}

cleanup_tty() {
    tput cnorm 2>/dev/null || printf "[?25h"
    [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup_tty EXIT

if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    setfont cyr-sun16 2>/dev/null || setfont UniCyr_8x16 2>/dev/null || setfont ter-v16n 2>/dev/null || true
fi

info()  { printf "${C_GREEN}${C_BOLD}[Everforest]${C_RESET} ${C_FG}%s${C_RESET}
" "$1"; }
warn()  { printf "${C_YELLOW}${C_BOLD}[Внимание]${C_RESET} ${C_FG}%s${C_RESET}
" "$1"; }
error() { printf "${C_RED}${C_BOLD}[Ошибка]${C_RESET} ${C_FG}%s${C_RESET}
" "$1"; }
step()  { printf "
${C_AQUA}${C_BOLD}==> %s${C_RESET}
" "$1"; }

tui_select() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local cur=0
    local key rest

    tput civis 2>/dev/null || printf "[?25l"
    printf "
${C_GREEN}${C_BOLD}╭─ %s${C_RESET}
" "$title"
    printf "${C_MUTED}│  ↑/↓ — навигация, Enter — выбрать${C_RESET}
"

    while true; do
        for ((i = 0; i < count; i++)); do
            if [ "$i" -eq "$cur" ]; then
                printf "${C_GREEN}${C_BOLD}│  ❯ %s${C_RESET}[K
" "${options[$i]}"
            else
                printf "${C_MUTED}│    ${C_FG}%s${C_RESET}[K
" "${options[$i]}"
            fi
        done

        IFS= read -rsn1 key || true
        if [[ "$key" == $'' ]]; then
            IFS= read -rsn2 -t 0.05 rest || true
            key+="$rest"
        fi

        case "$key" in
            $'[A'|$'OA'|k|K) cur=$(( (cur - 1 + count) % count )) ;;
            $'[B'|$'OB'|j|J) cur=$(( (cur + 1) % count )) ;;
            "") break ;;
        esac
        printf "[%dA" "$count"
    done

    printf "${C_GREEN}${C_BOLD}╰────────────────────────────────────────${C_RESET}
"
    tput cnorm 2>/dev/null || printf "[?25h"
    TUI_CHOICE=$cur
}

tui_checklist() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local cur=0
    local checked=()
    local key rest

    for ((i = 0; i < count; i++)); do checked[$i]=0; done

    tput civis 2>/dev/null || printf "[?25l"
    printf "
${C_GREEN}${C_BOLD}╭─ %s${C_RESET}
" "$title"
    printf "${C_MUTED}│  ↑/↓ — навигация, Пробел — отметить, Enter — готово${C_RESET}
"

    while true; do
        for ((i = 0; i < count; i++)); do
            local mark="[ ]"
            local mark_col="$C_MUTED"
            if [ "${checked[$i]}" -eq 1 ]; then
                mark="[✓]"
                mark_col="$C_GREEN"
            fi
            if [ "$i" -eq "$cur" ]; then
                printf "${C_GREEN}${C_BOLD}│  ❯ ${mark_col}%s ${C_FG}${C_BOLD}%s${C_RESET}[K
" "$mark" "${options[$i]}"
            else
                printf "${C_MUTED}│    ${mark_col}%s ${C_FG}%s${C_RESET}[K
" "$mark" "${options[$i]}"
            fi
        done

        IFS= read -rsn1 key || true
        if [[ "$key" == $'' ]]; then
            IFS= read -rsn2 -t 0.05 rest || true
            key+="$rest"
        fi

        case "$key" in
            $'[A'|$'OA'|k|K) cur=$(( (cur - 1 + count) % count )) ;;
            $'[B'|$'OB'|j|J) cur=$(( (cur + 1) % count )) ;;
            " ")
                if [ "${checked[$cur]}" -eq 1 ]; then checked[$cur]=0; else checked[$cur]=1; fi
                ;;
            "") break ;;
        esac
        printf "[%dA" "$count"
    done

    printf "${C_GREEN}${C_BOLD}╰────────────────────────────────────────${C_RESET}
"
    tput cnorm 2>/dev/null || printf "[?25h"

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
        if [ "$AUR_HELPER" = "yay" ]; then
            "$AUR_HELPER" -S --needed --noconfirm --answerclean None --answerdiff None --answeredit None "${aur_pkgs[@]}"
        else
            "$AUR_HELPER" -S --needed --noconfirm --skipreview "${aur_pkgs[@]}"
        fi
    fi
}

backup_and_copy_configs() {
    local is_update="${1:-0}"
    step "Копирование конфигов (хранится 1 последняя копия в $BACKUP_DIR)"
    rm -rf "$HOME"/.config-backup-* 2>/dev/null || true
    mkdir -p "$HOME/.config"         "$HOME/.local/share/wallpapers/Everforest"         "$HOME/.local/share/wallpapers/Catppuccin Macchiato"         "$HOME/.local/share/wallpapers/Graphite"         "$HOME/.local/share/wallpapers/Windows 7"         "$HOME/Скриншоты"         "$HOME/.local/state"

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

    if [ "$is_update" != "1" ] && [ -d "$REPO_DIR/wallpapers" ]; then
        cp -rn "$REPO_DIR/wallpapers/." "$HOME/.local/share/wallpapers/" 2>/dev/null || cp -an "$REPO_DIR/wallpapers/." "$HOME/.local/share/wallpapers/" 2>/dev/null || true
    fi

    if [ ! -s "$HOME/.local/state/qs-wallpaper" ]; then
        local first_wp
        first_wp="$(find "$HOME/.local/share/wallpapers/Everforest" -maxdepth 2 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort | head -n1 || true)"
        [ -n "$first_wp" ] && printf "%s" "$first_wp" > "$HOME/.local/state/qs-wallpaper"
    fi

    if [ -d "$REPO_DIR/themes" ]; then
        mkdir -p "$HOME/.local/share/themes"
        cp -af "$REPO_DIR/themes/." "$HOME/.local/share/themes/"
    fi
    chmod +x "$HOME/.config/quickshell/scripts/"*.sh "$HOME/.config/hypr/"*.sh 2>/dev/null || true
    "$HOME/.config/quickshell/scripts/set_gtk_theme.sh" "Everforest-BL-MB-Dark-Soft" >/dev/null 2>&1 || true

    for _hf in everforest-dots yay; do
        grep -qxF "$_hf" "$HOME/.hidden" 2>/dev/null || printf "%s
" "$_hf" >> "$HOME/.hidden"
    done
    fc-cache -f >/dev/null 2>&1 || true
}

setup_sddm() {
    local current_dm=""
    if [ -L /etc/systemd/system/display-manager.service ]; then
        current_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
    fi

    if [ -n "$current_dm" ]; then
        warn "Обнаружен активный менеджер входа: $current_dm"
        tui_select "Заменить $current_dm на SDDM с темой everforest-m3?"             "Нет, оставить текущий ($current_dm)"             "Да, заменить на SDDM + everforest-m3"
        if [ "$TUI_CHOICE" -ne 1 ]; then
            info "Текущий менеджер входа ($current_dm) сохранён."
            return 0
        fi
        sudo systemctl disable "$current_dm" 2>/dev/null || true
    else
        tui_select "Установить экран входа SDDM с темой everforest-m3?"             "Да, установить и включить SDDM"             "Нет, пропустить"
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
        printf "[Theme]
Current=everforest-m3
" | sudo tee /etc/sddm.conf.d/everforest.conf >/dev/null
    fi
    sudo systemctl enable sddm.service
    info "SDDM настроен и включён."
}

clear
printf "${C_GREEN}${C_BOLD}"
printf "╔══════════════════════════════════════════════╗
"
printf "║     Everforest Hyprland + Quickshell Setup   ║
"
printf "╚══════════════════════════════════════════════╝
"
printf "${C_RESET}"

tui_select "Выберите режим работы"     "Полная установка (система + софт + конфиги)"     "Обновление (только конфиги, шрифты, иконки)"     "Выход"

if [ "$TUI_CHOICE" -eq 2 ]; then
    info "Выход без изменений."
    exit 0
fi

start_sudo_keepalive

if [ "$TUI_CHOICE" -eq 1 ]; then
    step "Обновление шрифтов, иконок, темы и конфигов"
    install_pkg_list         adw-gtk-theme qt6ct qt5-wayland nwg-look less         noto-fonts noto-fonts-emoji ttf-nunito ttf-jetbrains-mono-nerd         gruvbox-plus-icon-theme ttf-material-symbols-variable-git
    backup_and_copy_configs 1
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

BR_MAP=("firefox" "zen-browser-bin" "chromium" "opera")
tui_checklist "Какие браузеры установить?"     "Firefox"     "Zen Browser (AUR)"     "Chromium"     "Opera"
BR_PKGS=()
for idx in "${TUI_SELECTED[@]}"; do
    BR_PKGS+=("${BR_MAP[$idx]}")
done

tui_select "Какой офисный пакет установить?"     "OnlyOffice (AUR)"     "LibreOffice Fresh"     "Ничего не ставить"
OFF_PKGS=()
case "$TUI_CHOICE" in
    0) OFF_PKGS+=("onlyoffice-bin") ;;
    1) OFF_PKGS+=("libreoffice-fresh") ;;
esac

BYPASS_HAPP=0
BYPASS_ZAPRET=0
tui_checklist "Средства обхода блокировок (опционально):"     "Happ (VPN-клиент, AUR)"     "Zapret (обход DPI, Snowy-Fluffy)"
for _idx in "${TUI_SELECTED[@]}"; do
    case "$_idx" in
        0) BYPASS_HAPP=1 ;;
        1) BYPASS_ZAPRET=1 ;;
    esac
done

step "0/4 Обновление системы (pacman -Syu)"
sudo pacman -Syu --noconfirm

step "1/4 Установка базового окружения и утилит"
install_pkg_list     hyprland quickshell-git swaybg xdg-desktop-portal-hyprland hyprpolkitagent     kitty fish starship less nautilus file-roller unzip 7zip unrar     loupe showtime papers foliate decibels     gnome-text-editor gnome-calculator gnome-disk-utility baobab gnome-clocks gnome-system-monitor     gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpegthumbnailer webp-pixbuf-loader     gvfs gvfs-mtp ntfs-3g     pipewire pipewire-pulse wireplumber playerctl     networkmanager bluez bluez-utils     grim slurp wl-clipboard cliphist wf-recorder ffmpeg     flatpak fuse2 adw-gtk-theme qt6ct qt5-wayland nwg-look     noto-fonts noto-fonts-emoji ttf-nunito ttf-jetbrains-mono-nerd     gruvbox-plus-icon-theme ttf-material-symbols-variable-git

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
systemctl --user enable --now mpris-proxy.service 2>/dev/null || true

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

mkdir -p "$HOME/.local/share/themes" "$HOME/.local/share/icons"
if [ ! -d "$HOME/.local/share/themes/GTKAero" ]; then
    git clone --depth 1 https://github.com/User738git/GTKAero.git "$HOME/.local/share/themes/GTKAero" 2>/dev/null || true
    if [ -f "$HOME/.local/share/themes/GTKAero/AeroIcons.tar.gz" ]; then
        tar -xzf "$HOME/.local/share/themes/GTKAero/AeroIcons.tar.gz" -C "$HOME/.local/share/icons/" 2>/dev/null || true
    fi
fi

for m in image/png image/jpeg image/webp image/gif image/svg+xml; do xdg-mime default org.gnome.Loupe.desktop "$m" 2>/dev/null || true; done
for m in video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo; do xdg-mime default org.gnome.Showtime.desktop "$m" 2>/dev/null || true; done
for m in audio/mpeg audio/flac audio/ogg audio/wav audio/mp4 audio/x-wav; do xdg-mime default org.gnome.Decibels.desktop "$m" 2>/dev/null || true; done
for m in application/pdf image/vnd.djvu; do xdg-mime default org.gnome.Papers.desktop "$m" 2>/dev/null || true; done
for m in application/epub+zip application/x-fictionbook+xml; do xdg-mime default com.github.johnfactotum.Foliate.desktop "$m" 2>/dev/null || true; done
for m in application/zip application/x-tar application/gzip application/x-7z-compressed application/x-rar application/x-xz application/x-bzip2 application/zstd; do xdg-mime default org.gnome.FileRoller.desktop "$m" 2>/dev/null || true; done

backup_and_copy_configs 0

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

if [ "$REPO_DIR" = "$HOME/everforest-dots" ]; then
    mkdir -p "$HOME/.local/share"
    rm -rf "$HOME/.local/share/everforest-dots"
    mv "$REPO_DIR" "$HOME/.local/share/everforest-dots"
    info "Репозиторий перенесён в ~/.local/share/everforest-dots"
fi

printf "
${C_GREEN}${C_BOLD}Готово! Всё установлено, перезайди в сессию или перезагрузи ПК.${C_RESET}
"
