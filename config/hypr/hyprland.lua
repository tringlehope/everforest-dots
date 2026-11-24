-- Модульный конфиг Hyprland (Everforest Dark Soft)

require("monitors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.on("hyprland.start", function ()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("sh -c 'w=$(cat ~/.local/state/qs-wallpaper 2>/dev/null); [ -n \"$w\" ] && [ -f \"$w\" ] || w=$(find ~/.local/share/wallpapers/Everforest -type f | sort | head -n1); [ -n \"$w\" ] && { mkdir -p ~/.local/state; printf %s \"$w\" > ~/.local/state/qs-wallpaper; exec swaybg -i \"$w\" -m fill; }'")
    hl.exec_cmd("~/.config/quickshell/scripts/qs_watchdog.sh")
end)

require("appearance")
require("workspaces")
require("binds")
require("autostart")

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
