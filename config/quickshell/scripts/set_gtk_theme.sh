#!/usr/bin/env bash
THEME="${1:-Everforest-BL-MB-Dark-Soft}"

gsettings set org.gnome.desktop.interface gtk-theme "$THEME" 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    mkdir -p "$(dirname "$ini")"
    if [ -f "$ini" ]; then
        if grep -q '^gtk-theme-name=' "$ini"; then
            sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$THEME|" "$ini"
        else
            printf '\ngtk-theme-name=%s\n' "$THEME" >> "$ini"
        fi
    else
        printf '[Settings]\ngtk-theme-name=%s\ngtk-application-prefer-dark-theme=1\n' "$THEME" > "$ini"
    fi
done

THEME_DIR=""
for base in "$HOME/.themes" "$HOME/.local/share/themes" "/usr/share/themes"; do
    if [ -d "$base/$THEME/gtk-4.0" ]; then
        THEME_DIR="$base/$THEME/gtk-4.0"
        break
    fi
done

if [ -n "$THEME_DIR" ]; then
    mkdir -p "$HOME/.config/gtk-4.0"
    for item in gtk.css gtk-dark.css assets; do
        rm -rf "$HOME/.config/gtk-4.0/$item"
        if [ -e "$THEME_DIR/$item" ]; then
            ln -s "$THEME_DIR/$item" "$HOME/.config/gtk-4.0/$item"
        fi
    done
fi
