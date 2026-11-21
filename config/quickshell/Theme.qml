pragma Singleton
import QtQuick

QtObject {
    property bool showFrame: true
    property string currentTheme: "everforest"

    readonly property var palettes: ({
        "everforest": {
            folder: "Everforest",
            bgFrame: "#232a2e", bgSurface: "#2d353b", bgPill: "#323c41", bgPillHover: "#3d484d", bgElevated: "#384348",
            fg: "#d3c6aa", fgMuted: "#859289", fgDim: "#56635f",
            accent: "#a7c080", accentWarm: "#dbbc7f", accentOn: "#232a2e", borderSubtle: "#475258", danger: "#e67e80",
            hyprActive: "a7c080", hyprInactive: "475258"
        },
        "catppuccin-macchiato": {
            folder: "Catppuccin Macchiato",
            bgFrame: "#181926", bgSurface: "#24273a", bgPill: "#363a4f", bgPillHover: "#494d64", bgElevated: "#3e4259",
            fg: "#cad3f5", fgMuted: "#a5adcb", fgDim: "#6e738d",
            accent: "#c6a0f6", accentWarm: "#eed49f", accentOn: "#181926", borderSubtle: "#494d64", danger: "#ed8796",
            hyprActive: "c6a0f6", hyprInactive: "494d64"
        },
        "graphite": {
            folder: "Graphite",
            bgFrame: "#181818", bgSurface: "#222222", bgPill: "#2e2e2e", bgPillHover: "#3a3a3a", bgElevated: "#333333",
            fg: "#e4e4e4", fgMuted: "#9a9a9a", fgDim: "#666666",
            accent: "#d4d4d4", accentWarm: "#b4b4b4", accentOn: "#181818", borderSubtle: "#3e3e3e", danger: "#e06c75",
            hyprActive: "d4d4d4", hyprInactive: "3e3e3e"
        }
    })

    readonly property var p: palettes[currentTheme] || palettes["everforest"]
    readonly property string wallpaperFolder: p.folder

    readonly property color bgFrame:      p.bgFrame
    readonly property color bgSurface:    p.bgSurface
    readonly property color bgPill:       p.bgPill
    readonly property color bgPillHover:  p.bgPillHover
    readonly property color bgElevated:   p.bgElevated

    readonly property color fg:           p.fg
    readonly property color fgMuted:      p.fgMuted
    readonly property color fgDim:        p.fgDim

    readonly property color accent:       p.accent
    readonly property color accentWarm:   p.accentWarm
    readonly property color accentOn:     p.accentOn
    readonly property color borderSubtle: p.borderSubtle
    readonly property color danger:       p.danger

    readonly property string fontFamily:  "Nunito"
    readonly property string monoFont:    "JetBrainsMono Nerd Font"
    readonly property string iconFont:    "JetBrainsMono Nerd Font"

    readonly property int frameThickness: 6
    readonly property int topBarHeight:   34
    readonly property int radiusWindow:   12
    readonly property int radiusCard:     18
    readonly property int radiusPill:     999

    readonly property int animFast:       150
    readonly property int animExpressive: 240
}
