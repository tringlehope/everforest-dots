import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import "../components"
import ".."

PanelWindow {
    id: win
    property bool open: false
    property var wallpapers: []

    visible: card.scale > 0.05 || open
    exclusiveZone: -1
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"

    Process {
        id: scanProc
        command: ["sh", "-c", "find ~/Pictures/Wallpapers -maxdepth 2 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                win.wallpapers = lines.filter(l => l.length > 0);
            }
        }
    }

    onOpenChanged: if (open) scanProc.running = true

    MouseArea { anchors.fill: parent; onClicked: win.open = false }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 520
        height: 360
        radius: Theme.radiusCard
        color: Theme.bgSurface
        border.color: Theme.accent
        border.width: 3

        transformOrigin: Item.Center
        scale: win.open ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation {
                duration: win.open ? 260 : 160
                easing.type: win.open ? Easing.OutQuint : Easing.InQuad
            }
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Обои (~/Pictures/Wallpapers)"
                    font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: Theme.fg
                }
                Rectangle {
                    implicitWidth: 30; implicitHeight: 30; radius: closeW.containsMouse ? 8 : 15
                    color: closeW.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Text { anchors.centerIn: parent; text: "\uf00d"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.fgMuted }
                    MouseArea { id: closeW; anchors.fill: parent; hoverEnabled: true; onClicked: win.open = false }
                }
            }

            Text {
                visible: win.wallpapers.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: "Положи картинки (.png / .jpg / .webp)\nв папку ~/Pictures/Wallpapers"
                font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.fgMuted
            }

            GridView {
                visible: win.wallpapers.length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 158
                cellHeight: 104
                model: win.wallpapers

                delegate: Item {
                    required property string modelData
                    width: 158; height: 104

                    Rectangle {
                        anchors.fill: parent; anchors.margins: 4
                        radius: wM.containsMouse ? 10 : 14
                        color: Theme.bgPill
                        border.color: wM.containsMouse ? Theme.accentWarm : Theme.borderSubtle
                        border.width: 2
                        clip: true
                        Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                        ClippingRectangle {
                            anchors.fill: parent; anchors.margins: 2
                            radius: parent.radius - 2
                            color: "transparent"
                            Image {
                                anchors.fill: parent
                                source: "file://" + modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            id: wM
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                var p = modelData.replace(/'/g, "'\\''");
                                Quickshell.execDetached(["sh", "-c", "printf '%s' '" + p + "' > ~/.local/state/qs-wallpaper && pkill swaybg; swaybg -i '" + p + "' -m fill >/dev/null 2>&1 &"]);
                                win.open = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
