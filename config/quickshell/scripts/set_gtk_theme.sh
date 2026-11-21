#!/usr/bin/env bash
THEME="${1:-Everforest-BL-MB-Dark-Soft}"

rm -rf "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk-dark.css" "$HOME/.config/gtk-4.0/assets"

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
        if [ -e "$THEME_DIR/$item" ]; then
            ln -s "$THEME_DIR/$item" "$HOME/.config/gtk-4.0/$item"
        fi
    done
fi

for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    mkdir -p "$(dirname "$ini")"
    if [ -f "$ini" ]; then
        if grep -q '^gtk-theme-name=' "$ini"; then
            sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$THEME|" "$ini"
        else
            printf '\ngtk-theme-name=%s\n' "$THEME" >> "$ini"
        fi
    else
        printf '[Settings]\ngtk-theme-name=%s\n' "$ini" > "$ini"
    fi
done

gsettings set org.gnome.desktop.interface gtk-theme "$THEME" 2>/dev/null || true
if [ "$THEME" = "GTKAero" ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
fi

ICON_THEME="Gruvbox-Plus-Dark"
if [ "$THEME" = "GTKAero" ]; then
    for cand in "Windows 7 Aero" "AeroIcons"; do
        if [ -d "$HOME/.local/share/icons/$cand" ] || [ -d "$HOME/.icons/$cand" ]; then
            ICON_THEME="$cand"
            break
        fi
    done
fi
gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    if grep -q '^gtk-icon-theme-name=' "$ini" 2>/dev/null; then
        sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$ICON_THEME|" "$ini"
    else
        printf 'gtk-icon-theme-name=%s\n' "$ICON_THEME" >> "$ini"
    fi
done
