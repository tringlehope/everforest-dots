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

ICON_THEME="Gruvbox-Plus-Dark"
if [ "$THEME" = "GTKAero" ]; then
    for cand in "Windows 7 Aero" "AeroIcons" "Windows-7" "Win2-7"; do
        if [ -d "$HOME/.local/share/icons/$cand" ] || [ -d "$HOME/.icons/$cand" ] || [ -d "/usr/share/icons/$cand" ]; then
            ICON_THEME="$cand"
            break
        fi
    done
fi

for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    mkdir -p "$(dirname "$ini")"
    if [ -f "$ini" ]; then
        grep -q '^gtk-theme-name=' "$ini" && sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$THEME|" "$ini" || printf '\ngtk-theme-name=%s\n' "$THEME" >> "$ini"
        grep -q '^gtk-icon-theme-name=' "$ini" && sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$ICON_THEME|" "$ini" || printf 'gtk-icon-theme-name=%s\n' "$ICON_THEME" >> "$ini"
    else
        printf '[Settings]\ngtk-theme-name=%s\ngtk-icon-theme-name=%s\n' "$THEME" "$ICON_THEME" > "$ini"
    fi
done

QT6CT="$HOME/.config/qt6ct/qt6ct.conf"
OLD_QT_ICON=""
if [ -f "$QT6CT" ]; then
    OLD_QT_ICON="$(grep '^icon_theme=' "$QT6CT" | cut -d= -f2)"
    if grep -q '^icon_theme=' "$QT6CT"; then
        sed -i "s|^icon_theme=.*|icon_theme=$ICON_THEME|" "$QT6CT"
    else
        sed -i "/^\[Appearance\]/a icon_theme=$ICON_THEME" "$QT6CT"
    fi
fi

gsettings set org.gnome.desktop.interface gtk-theme "$THEME" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
if [ "$THEME" = "GTKAero" ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
fi

if [ "$OLD_QT_ICON" != "$ICON_THEME" ] && pgrep -x qs >/dev/null; then
    (sleep 0.2; pkill -x qs; sleep 0.2; nohup qs > /tmp/qs.log 2>&1 &) &
fi

KITTY_THEME="everforest"
case "$THEME" in
    Catppuccin-*) KITTY_THEME="catppuccin-macchiato" ;;
    Graphite-*)   KITTY_THEME="graphite" ;;
    GTKAero)      KITTY_THEME="win7" ;;
    *)            KITTY_THEME="everforest" ;;
esac
if [ -f "$HOME/.config/kitty/themes/$KITTY_THEME.conf" ]; then
    cp -f "$HOME/.config/kitty/themes/$KITTY_THEME.conf" "$HOME/.config/kitty/current-theme.conf"
    pkill -USR1 -x kitty 2>/dev/null || true
fi
