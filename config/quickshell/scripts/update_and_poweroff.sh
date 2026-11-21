#!/usr/bin/env bash
set -euo pipefail

echo "==> [1/4] Обновление пакетов системы..."
if command -v yay &>/dev/null; then
    yay -Syu --noconfirm --answerdiff None --answerclean None --removemake
else
    sudo pacman -Syu --noconfirm
fi

echo "==> [2/4] Обновление конфигов из GitHub..."
REPO="$HOME/everforest-dots"
if [ -d "$REPO/.git" ]; then
    git -C "$REPO" pull --ff-only || echo "[!] Пропущен git pull (есть локальные изменения)"
    BACKUP="$HOME/.config-backup-auto"
    mkdir -p "$BACKUP"
    for d in hypr quickshell gtk-3.0 gtk-4.0 qt6ct ghostty fontconfig; do
        if [ -d "$REPO/config/$d" ]; then
            [ -d "$HOME/.config/$d" ] && mkdir -p "$BACKUP/$d" && cp -af "$HOME/.config/$d/." "$BACKUP/$d/"
            mkdir -p "$HOME/.config/$d"
            cp -af "$REPO/config/$d/." "$HOME/.config/$d/"
        fi
    done
    fc-cache -f >/dev/null 2>&1 || true
else
    echo "[!] Репозиторий $REPO не найден, пропускаю шаг конфигов."
fi

echo "==> [3/4] Удаление неиспользуемых зависимостей (сирот)..."
ORPHANS=$(pacman -Qtdq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    sudo pacman -Rns --noconfirm $ORPHANS
else
    echo "Неиспользуемых зависимостей не найдено."
fi

echo "==> [4/4] Очистка кэша пакетов..."
sudo pacman -Sc --noconfirm
rm -rf "$HOME/.cache/yay"/* 2>/dev/null || true

echo "==> Готово! Выключаю компьютер..."
