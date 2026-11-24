#!/usr/bin/env bash
set -euo pipefail

echo "==> [1/4] Обновление пакетов системы..."
if ! sudo -n pacman -Syu --noconfirm; then
    echo "[Ошибка] Не удалось обновить пакеты без пароля (проверь /etc/sudoers.d/everforest-update)."
    exit 1
fi

if command -v yay &>/dev/null; then
    AUR_UPDATES=$(yay -Qua 2>/dev/null || true)
    if [ -n "$AUR_UPDATES" ]; then
        echo "==> Обновление AUR-пакетов..."
        yay -Sua --noconfirm --sudoflags "-n" --answerdiff None --answerclean None --answeredit None --removemake || echo "[!] Обновление AUR пропущено (требуется ввод пароля в терминале)."
    fi
fi

echo "==> [2/4] Обновление конфигов из GitHub..."
REPO="$HOME/.local/share/everforest-dots"
[ -d "$HOME/everforest-dots/.git" ] && [ ! -d "$REPO/.git" ] && REPO="$HOME/everforest-dots"
if [ -d "$REPO/.git" ]; then
    git -C "$REPO" pull --ff-only || echo "[!] Пропущен git pull (есть локальные изменения)"
    BACKUP="$HOME/.config-backup-auto"
    mkdir -p "$BACKUP"
    for d in hypr quickshell gtk-3.0 gtk-4.0 qt6ct kitty fish fontconfig; do
        if [ -d "$REPO/config/$d" ]; then
            [ -d "$HOME/.config/$d" ] && mkdir -p "$BACKUP/$d" && cp -af "$HOME/.config/$d/." "$BACKUP/$d/"
            mkdir -p "$HOME/.config/$d"
            cp -af "$REPO/config/$d/." "$HOME/.config/$d/"
        fi
    done
    if [ -f "$REPO/config/starship.toml" ]; then
        cp -af "$REPO/config/starship.toml" "$HOME/.config/starship.toml"
    fi
    if [ -d "$REPO/wallpapers" ]; then
        mkdir -p "$HOME/.local/share/wallpapers"
        cp -an "$REPO/wallpapers/." "$HOME/.local/share/wallpapers/" 2>/dev/null || true
    fi
    for _hf in everforest-dots yay; do
        grep -qxF "$_hf" "$HOME/.hidden" 2>/dev/null || printf "%s
" "$_hf" >> "$HOME/.hidden"
    done
    if [ -d "$REPO/themes" ]; then
        mkdir -p "$HOME/.local/share/themes"
        cp -af "$REPO/themes/." "$HOME/.local/share/themes/"
    fi
    fc-cache -f >/dev/null 2>&1 || true
else
    echo "[!] Репозиторий $REPO не найден, пропускаю шаг конфигов."
fi

echo "==> [3/4] Удаление неиспользуемых зависимостей (сирот)..."
ORPHANS=$(pacman -Qtdq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    sudo -n pacman -Rns --noconfirm $ORPHANS
else
    echo "Неиспользуемых зависимостей не найдено."
fi

echo "==> [4/4] Очистка кэша пакетов..."
sudo -n pacman -Sc --noconfirm
rm -rf "$HOME/.cache/yay"/* 2>/dev/null || true

echo "==> Готово! Выключаю компьютер..."
