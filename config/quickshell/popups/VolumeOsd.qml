import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../components"
import ".."

PanelWindow {
    id: osd
    property bool showing: false
    property real volume: 0.5
    property bool muted: false

    visible: card.scale > 0.05 || showing
    exclusiveZone: -1
    anchors { top: true }
    margins.top: Theme.topBarHeight + 2
    implicitWidth: 310
    implicitHeight: 84
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"
    mask: Region {}

    Process {
        id: volRead
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                osd.muted = (t.indexOf("[MUTED]") !== -1);
                var m = t.match(/Volume:\s*([0-9.]+)/);
                if (m) osd.volume = Math.max(0, Math.min(1, parseFloat(m[1])));
            }
        }
    }

    function trigger() {
        volRead.running = false;
        volRead.running = true;
        osd.showing = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: osd.showing = false
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 256
        height: 50
        radius: Theme.r(18)
        color: Theme.bgSurface
        border.color: osd.muted ? Theme.danger : Theme.accent
        border.width: 3

        transformOrigin: Item.Top
        scale: osd.showing ? 1.0 : 0.0
        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 10

            Text {
                text: osd.muted || osd.volume <= 0.01 ? "\uf026" : (osd.volume < 0.5 ? "\uf027" : "\uf028")
                font.family: Theme.iconFont
                font.pixelSize: 15
                color: osd.muted ? Theme.danger : Theme.accentWarm
            }

            WavySlider {
                Layout.fillWidth: true
                interactive: false
                value: osd.muted ? 0 : osd.volume
                activeColor: osd.muted ? Theme.danger : Theme.accent
            }

            Text {
                text: osd.muted ? "Mute" : Math.round(osd.volume * 100) + "%"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Bold
                color: osd.muted ? Theme.danger : Theme.fg
                Layout.minimumWidth: 34
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
