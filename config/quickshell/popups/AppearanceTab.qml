import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: root

    function setFrameMode(enabled) {
        Theme.showFrame = enabled;
        Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.local/state && printf '%s' '" + (enabled ? "1" : "0") + "' > ~/.local/state/qs-frame-mode"]);
    }

    function setTheme(themeId) {
        if (!Theme.palettes[themeId]) return;
        Theme.currentTheme = themeId;
        var pal = Theme.palettes[themeId];
        Quickshell.execDetached(["sh", "-c", "mkdir -p ~/.local/state && printf '%s' '" + themeId + "' > ~/.local/state/qs-theme"]);
        var isW7 = (themeId === "win7");
        var hlCmd = isW7
            ? "hl.config({ general = { border_size = 2, col = { active_border = 'rgb(" + pal.hyprActive + ")', inactive_border = 'rgb(" + pal.hyprInactive + ")' } }, decoration = { rounding = 0, active_opacity = 0.86, inactive_opacity = 0.78, blur = { enabled = true, size = 12, passes = 4, vibrancy = 0.25 } } })"
            : "hl.config({ general = { border_size = 4, col = { active_border = 'rgb(" + pal.hyprActive + ")', inactive_border = 'rgb(" + pal.hyprInactive + ")' } }, decoration = { rounding = 12, active_opacity = 1.0, inactive_opacity = 1.0, blur = { enabled = false } } })";
        Quickshell.execDetached(["hyprctl", "eval", hlCmd]);
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/scripts/set_gtk_theme.sh", pal.gtkTheme]);

        var folder = pal.folder.replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "w=$(find \"$HOME/Pictures/Wallpapers/" + folder + "\" -maxdepth 2 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) | sort | head -n1); if [ -n \"$w\" ]; then printf '%s' \"$w\" > ~/.local/state/qs-wallpaper && pkill swaybg; swaybg -i \"$w\" -m fill >/dev/null 2>&1 & fi"]);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Text {
            text: "Оформление (тема и папка обоев)"
            font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.ExtraBold; color: Theme.fgMuted
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Repeater {
                model: [
                    { id: "everforest",       name: "Everforest",       bg: "#2d353b", acc: "#a7c080", warm: "#dbbc7f" },
                    { id: "catppuccin-macchiato", name: "Catppuccin Macchiato", bg: "#24273a", acc: "#c6a0f6", warm: "#8aadf4" },
                    { id: "graphite",         name: "Graphite",         bg: "#222222", acc: "#d4d4d4", warm: "#9a9a9a" },
                    { id: "win7",             name: "Windows 7",        bg: "#dceeff", acc: "#2b8ae6", warm: "#3399ff" }
                ]

                delegate: Rectangle {
                    id: themeCard
                    required property var modelData
                    readonly property bool isActive: Theme.currentTheme === modelData.id

                    Layout.fillWidth: true
                    implicitHeight: 96
                    radius: themeM.pressed ? 12 : (themeM.containsMouse ? 14 : 18)
                    scale: themeM.pressed ? 0.94 : (themeM.containsMouse ? 1.04 : 1.0)
                    color: isActive ? Theme.bgElevated : Theme.bgPill
                    border.color: isActive ? Theme.accent : Theme.borderSubtle
                    border.width: isActive ? 3 : 1

                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    MouseArea {
                        id: themeM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setTheme(themeCard.modelData.id)
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6
                            Rectangle { width: 22; height: 22; radius: 11; color: themeCard.modelData.bg; border.color: "#555"; border.width: 1 }
                            Rectangle { width: 22; height: 22; radius: 11; color: themeCard.modelData.acc }
                            Rectangle { width: 22; height: 22; radius: 11; color: themeCard.modelData.warm }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: themeCard.modelData.name
                            font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.ExtraBold
                            color: themeCard.isActive ? Theme.accent : Theme.fg
                        }
                    }
                }
            }
        }

        Text {
            text: "Стиль панели и краёв экрана"
            font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.ExtraBold; color: Theme.fgMuted
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Вариант 1: Панель с рамками
            Rectangle {
                id: cardFrame
                scale: btnMa_1.pressed ? 0.94 : (btnMa_1.containsMouse ? 1.04 : 1.0)
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                readonly property bool isActive: Theme.showFrame
                Layout.fillWidth: true
                implicitHeight: 170
                radius: 18
                color: isActive ? Theme.bgElevated : Theme.bgPill
                border.color: isActive ? Theme.accent : Theme.borderSubtle
                border.width: isActive ? 3 : 1

                MouseArea {
                    id: btnMa_1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: root.setFrameMode(true)
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: 12
                        color: Theme.bgSurface
                        border.color: Theme.bgFrame
                        border.width: 6

                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: 22
                            color: Theme.bgFrame
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                Rectangle { width: 34; height: 10; radius: 5; color: Theme.accentWarm }
                                Item { Layout.fillWidth: true }
                                Rectangle { width: 22; height: 10; radius: 5; color: Theme.bgPillHover }
                                Item { Layout.fillWidth: true }
                                Rectangle { width: 30; height: 10; radius: 5; color: Theme.bgPillHover }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Панель с рамками"
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.ExtraBold
                        color: cardFrame.isActive ? Theme.accent : Theme.fg
                    }
                }
            }

            // Вариант 2: Только пузыри
            Rectangle {
                id: cardBubbles
                scale: btnMa_2.pressed ? 0.94 : (btnMa_2.containsMouse ? 1.04 : 1.0)
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                readonly property bool isActive: !Theme.showFrame
                Layout.fillWidth: true
                implicitHeight: 170
                radius: 18
                color: isActive ? Theme.bgElevated : Theme.bgPill
                border.color: isActive ? Theme.accent : Theme.borderSubtle
                border.width: isActive ? 3 : 1

                MouseArea {
                    id: btnMa_2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: root.setFrameMode(false)
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: 12
                        color: Theme.bgSurface
                        border.color: Theme.borderSubtle
                        border.width: 1

                        RowLayout {
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                            Rectangle { width: 34; height: 12; radius: 6; color: Theme.accentWarm }
                            Item { Layout.fillWidth: true }
                            Rectangle { width: 24; height: 12; radius: 6; color: Theme.bgPillHover }
                            Item { Layout.fillWidth: true }
                            Rectangle { width: 30; height: 12; radius: 6; color: Theme.bgPillHover }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Theme.isWin7 ? "Квадратная панель" : "Только пузыри"
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.ExtraBold
                        color: cardBubbles.isActive ? Theme.accent : Theme.fg
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
