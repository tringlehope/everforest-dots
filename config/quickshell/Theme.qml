pragma Singleton
import QtQuick

QtObject {
    readonly property color bgFrame:      "#232a2e"
    readonly property color bgSurface:    "#2d353b"
    readonly property color bgPill:       "#323c41"
    readonly property color bgPillHover:  "#3d484d"
    readonly property color bgElevated:   "#384348"

    readonly property color fg:           "#d3c6aa"
    readonly property color fgMuted:      "#859289"
    readonly property color fgDim:        "#56635f"

    readonly property color accent:       "#a7c080"
    readonly property color accentWarm:   "#dbbc7f"
    readonly property color accentOn:     "#232a2e"
    readonly property color borderSubtle: "#475258"
    readonly property color danger:       "#e67e80"

    readonly property string fontFamily:  "Inter"
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
