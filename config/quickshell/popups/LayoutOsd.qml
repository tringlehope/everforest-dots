import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: osd
    property bool showing: false
    property string currentLayout: "EN"
    property bool initialized: false

    visible: osdTrans.y > -90 || showing
    exclusiveZone: -1
    anchors { top: true; right: true }
    margins.top: Theme.topBarHeight + 8
    margins.right: (Theme.showFrame && !Theme.isWin7 && !Theme.dockPinned ? Theme.frameThickness : 0) + 125
    implicitWidth: 196
    implicitHeight: 72
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"
    mask: Region {}

    Timer {
        id: hideTimer
        interval: 1100
        onTriggered: osd.showing = false
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                var data = String(event.data || "").toLowerCase();
                var next = (data.indexOf("rus") !== -1 || data.indexOf("ру") !== -1) ? "RU" : "EN";
                if (!osd.initialized) {
                    osd.currentLayout = next;
                    osd.initialized = true;
                    return;
                }
                osd.currentLayout = next;
                osd.showing = true;
                hideTimer.restart();
            }
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 184
        height: 54
        radius: Theme.r(18)
        color: Theme.bgSurface
        border.color: Theme.accent
        border.width: 3

        scale: osd.showing ? 1.0 : 0.92
        Behavior on scale {
            NumberAnimation {
                duration: osd.showing ? 180 : 120
                easing.type: osd.showing ? Easing.OutQuint : Easing.InQuad
            }
        }
        transform: Translate {
            id: osdTrans
            y: osd.showing ? 0 : -96
            Behavior on y {
                NumberAnimation {
                    duration: osd.showing ? 180 : 120
                    easing.type: osd.showing ? Easing.OutQuint : Easing.InQuad
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 6

            Repeater {
                model: ["EN", "RU"]
                delegate: Rectangle {
                    readonly property bool isActive: osd.currentLayout === modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.r(isActive ? 11 : 15)
                    color: isActive ? Theme.accentWarm : Theme.bgPill
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: isActive ? Theme.accentOn : Theme.fgMuted
                    }
                }
            }
        }
    }
}
