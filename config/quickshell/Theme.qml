pragma Singleton
import QtQuick

QtObject {
    property bool showFrame: true
    property string panelStyle: "frame" // "frame" | "panel" | "bubbles"
    property bool dockPinned: false
    property string currentTheme: "everforest"
    readonly property bool isWin7: currentTheme === "win7"

    function r(val) { return isWin7 ? 0 : val; }

    readonly property var palettes: ({
        "everforest": {
            folder: "Everforest",
            bgFrame: "#232a2e", bgSurface: "#2d353b", bgPill: "#323c41", bgPillHover: "#3d484d", bgElevated: "#384348",
            fg: "#d3c6aa", fgMuted: "#859289", fgDim: "#56635f",
            accent: "#a7c080", accentWarm: "#dbbc7f", accentOn: "#232a2e", borderSubtle: "#475258", danger: "#e67e80",
            hyprActive: "a7c080", hyprInactive: "475258", gtkTheme: "Everforest-BL-MB-Dark-Soft"
        },
        "catppuccin-macchiato": {
            folder: "Catppuccin Macchiato",
            bgFrame: "#181926", bgSurface: "#24273a", bgPill: "#363a4f", bgPillHover: "#494d64", bgElevated: "#3e4259",
            fg: "#cad3f5", fgMuted: "#a5adcb", fgDim: "#6e738d",
            accent: "#c6a0f6", accentWarm: "#8aadf4", accentOn: "#181926", borderSubtle: "#494d64", danger: "#ed8796",
            hyprActive: "c6a0f6", hyprInactive: "494d64", gtkTheme: "Catppuccin-BL-MB-Dark-Macchiato"
        },
        "graphite": {
            folder: "Graphite",
            bgFrame: "#181818", bgSurface: "#222222", bgPill: "#2e2e2e", bgPillHover: "#3a3a3a", bgElevated: "#333333",
            fg: "#e4e4e4", fgMuted: "#9a9a9a", fgDim: "#666666",
            accent: "#d4d4d4", accentWarm: "#b4b4b4", accentOn: "#181818", borderSubtle: "#3e3e3e", danger: "#e06c75",
            hyprActive: "d4d4d4", hyprInactive: "3e3e3e", gtkTheme: "Graphite-Dark"
        },
        "win7": {
            folder: "Windows 7",
            bgFrame: "#99dceeff", bgSurface: "#b8eaf4fc", bgPill: "#99c4e0f7", bgPillHover: "#cc96cbf5", bgElevated: "#cc7cbcf2",
            fg: "#101c28", fgMuted: "#344e68", fgDim: "#56728d",
            accent: "#2b8ae6", accentWarm: "#3399ff", accentOn: "#ffffff", borderSubtle: "#ccffffff", danger: "#d9384a",
            hyprActive: "66b8ff", hyprInactive: "aacce6", gtkTheme: "GTKAero"
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

    readonly property int frameThickness: isWin7 ? 0 : 6
    readonly property int topBarHeight:   38
    readonly property int radiusWindow:   isWin7 ? 0 : 12
    readonly property int radiusCard:     isWin7 ? 0 : 18
    readonly property int radiusPill:     isWin7 ? 0 : 999

    readonly property int animFast:       150
    readonly property int animExpressive: 240
}
