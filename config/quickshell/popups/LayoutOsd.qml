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

    visible: osdTrans.y < 148 || showing
    exclusiveZone: -1
    anchors { bottom: true }
    margins.bottom: 40
    implicitWidth: 210
    implicitHeight: 150
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
                if (next !== osd.currentLayout) {
                    osd.currentLayout = next;
                    osd.showing = true;
                    hideTimer.restart();
                } else {
                    osd.showing = true;
                    hideTimer.restart();
                }
            }
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        width: 184
        height: 56
        radius: Theme.r(20)
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
            y: osd.showing ? 0 : 150
            Behavior on y {
                NumberAnimation {
                    duration: osd.showing ? 180 : 120
                    easing.type: osd.showing ? Easing.OutQuint : Easing.InQuad
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Repeater {
                model: ["EN", "RU"]
                delegate: Rectangle {
                    readonly property bool isActive: osd.currentLayout === modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.r(isActive ? 12 : 16)
                    color: isActive ? Theme.accentWarm : Theme.bgPill
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: isActive ? Theme.accentOn : Theme.fgMuted
                    }
                }
            }
        }
    }
}
