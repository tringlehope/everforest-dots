#!/usr/bin/env bash
MODE="${1:-0}"
mkdir -p "$HOME/.local/state"
printf "%s" "$MODE" > "$HOME/.local/state/qs-window-mode"

if ! hyprctl plugin list 2>/dev/null | grep -q "hyprbars"; then
    hyprctl plugin load /usr/lib/libhyprbars.so >/dev/null 2>&1 || true
fi

hyprctl keyword plugin:hyprbars:bar_height 28 >/dev/null 2>&1 || true
hyprctl keyword plugin:hyprbars:bar_color "rgb(232a2e)" >/dev/null 2>&1 || true
hyprctl keyword plugin:hyprbars:col.text "rgb(d3c6aa)" >/dev/null 2>&1 || true
hyprctl keyword plugin:hyprbars:bar_text_size 12 >/dev/null 2>&1 || true
hyprctl keyword plugin:hyprbars:bar_text_font "Nunito" >/dev/null 2>&1 || true
hyprctl keyword plugin:hyprbars:bar_button_padding 8 >/dev/null 2>&1 || true
hyprctl keyword plugin:hyprbars:bar_padding 10 >/dev/null 2>&1 || true
hyprctl keyword plugin:hyprbars:bar_precedence_over_border true >/dev/null 2>&1 || true

hyprctl keyword plugin:hyprbars:hyprbars-button "rgb(e67e80), 14, ×, hyprctl dispatch killactive" >/dev/null 2>&1 || true
hyprctl keyword plugin:hyprbars:hyprbars-button "rgb(dbbc7f), 14, □, hyprctl dispatch fullscreen 1" >/dev/null 2>&1 || true
hyprctl keyword plugin:hyprbars:hyprbars-button "rgb(a7c080), 14, _, hyprctl dispatch movetoworkspacesilent special:minimized" >/dev/null 2>&1 || true

if [ "$MODE" = "1" ]; then
    hyprctl eval "hl.config({ general = { layout = 'dwindle' }, input = { follow_mouse = 0 } })" >/dev/null 2>&1 || true
    hyprctl keyword unbind SUPER,W >/dev/null 2>&1 || true
    hyprctl keyword windowrule "match:float 0, hyprbars:no_bar off" >/dev/null 2>&1 || true
    hyprctl eval "hl.window_rule({ name = 'wm-float-all', match = { class = '.*' }, float = true })" >/dev/null 2>&1 || true
    hyprctl clients -j | python3 -c "import sys,json,subprocess
for c in json.load(sys.stdin):
    if not c.get('floating') and c.get('address'):
        subprocess.run(['hyprctl','dispatch','setfloating','address:'+c['address']], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
" 2>/dev/null || true
else
    hyprctl reload >/dev/null 2>&1 || true
    if ! hyprctl plugin list 2>/dev/null | grep -q "hyprbars"; then
        hyprctl plugin load /usr/lib/libhyprbars.so >/dev/null 2>&1 || true
    fi
    hyprctl keyword plugin:hyprbars:bar_height 28 >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:bar_color "rgb(232a2e)" >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:col.text "rgb(d3c6aa)" >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:bar_text_size 12 >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:bar_text_font "Nunito" >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:bar_button_padding 8 >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:bar_padding 10 >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:bar_precedence_over_border true >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:hyprbars-button "rgb(e67e80), 14, ×, hyprctl dispatch killactive" >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:hyprbars-button "rgb(dbbc7f), 14, □, hyprctl dispatch fullscreen 1" >/dev/null 2>&1 || true
    hyprctl keyword plugin:hyprbars:hyprbars-button "rgb(a7c080), 14, _, hyprctl dispatch movetoworkspacesilent special:minimized" >/dev/null 2>&1 || true
    hyprctl keyword windowrule "match:float 0, hyprbars:no_bar on" >/dev/null 2>&1 || true
fi
