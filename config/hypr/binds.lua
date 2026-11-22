local mainMod     = "SUPER"
local terminal    = "ghostty"
local fileManager = "nautilus"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

hl.bind("SUPER + W", hl.dsp.exec_cmd("qs ipc call launcher toggle"))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "r-1" }))

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,   hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Управление лентой Niri (scrolling) для Razer Basilisk V3
hl.bind(mainMod .. " + mouse_left",  hl.dsp.layout("move -col"))
hl.bind(mainMod .. " + mouse_right", hl.dsp.layout("move +col"))

-- Плавное перетаскивание ленты зажатием Super + колёсико (средняя кнопка)
hl.bind(mainMod .. " + mouse:274", hl.dsp.exec_cmd("~/.config/hypr/scroll-drag.sh"))
hl.bind(mainMod .. " + mouse:274", hl.dsp.exec_cmd("touch /tmp/hypr-scroll-stop"), { release = true })

-- Роллер громкости (Aula F75 и мультимедиа-клавиши)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && qs ipc call osd volume"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && qs ipc call osd volume"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && qs ipc call osd volume"),     { locked = true })

-- Скриншот / запись области экрана
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("qs ipc call capture start"))

hl.bind(mainMod .. " + Tab",   hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
