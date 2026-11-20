import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import "../components"
import ".."

PanelWindow {
    id: win
    property bool open: false
    property string expandedSection: ""
    property bool recording: false
    property bool scrollingLayout: false
    property bool ethConnected: true
    property bool dockPinned: false
    property string netInfo: "Ethernet подключён"
    property real brightness: 0.8

    signal openWallpapers()

    visible: card.scale > 0.05 || open
    exclusiveZone: -1
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"

    Process {
        id: stateProc
        command: ["sh", "-c", "hyprctl getoption general:layout -j | python3 -c \"import sys,json; print(json.load(sys.stdin).get('str','dwindle'))\" && nmcli -t -f DEVICE,TYPE,STATE dev | head -n 3"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                if (lines.length >= 1) win.scrollingLayout = (lines[0].trim() === "scrolling");
                if (lines.length >= 2) win.netInfo = lines.slice(1).join(" • ");
            }
        }
    }
    Process {
        id: brightRead
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim());
                if (!isNaN(v)) win.brightness = v / 100.0;
            }
        }
    }
    onOpenChanged: {
        if (open) {
            brightRead.running = true;
            stateProc.running = true;
        } else {
            expandedSection = "";
        }
    }

    MouseArea { anchors.fill: parent; onClicked: win.open = false }

    Rectangle {
        id: card
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.topBarHeight + 8
        anchors.rightMargin: Theme.frameThickness + 8
        width: 344
        height: contentCol.implicitHeight + 28
        radius: Theme.radiusCard
        color: Theme.bgSurface
        border.color: Theme.accent
        border.width: 3

        transformOrigin: Item.TopRight
        scale: win.open ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation {
                duration: win.open ? 260 : 160
                easing.type: win.open ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.15
            }
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: contentCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                component ActionBtn: Rectangle {
                    property string icon: ""
                    property bool active: false
                    signal clicked()
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: m.containsMouse ? 10 : 18
                    color: active ? Theme.danger : (m.containsMouse ? Theme.bgPillHover : Theme.bgPill)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Text {
                        anchors.centerIn: parent
                        text: icon
                        font.family: Theme.iconFont; font.pixelSize: 14
                        color: active ? Theme.accentOn : Theme.fg
                    }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
                }

                ActionBtn { icon: "\uf030"; onClicked: { win.open = false; Quickshell.execDetached(["sh", "-c", "sleep 0.25 && grim -g \"$(slurp)\" - | wl-copy"]); } }
                ActionBtn {
                    icon: "\uf03d"
                    active: win.recording
                    onClicked: {
                        if (!win.recording) {
                            win.recording = true;
                            Quickshell.execDetached(["sh", "-c", "mkdir -p ~/Videos && wf-recorder -f ~/Videos/rec_$(date +%s).mp4"]);
                        } else {
                            win.recording = false;
                            Quickshell.execDetached(["pkill", "-INT", "wf-recorder"]);
                        }
                    }
                }
                ActionBtn { icon: "\uf021"; onClicked: Quickshell.execDetached(["systemctl", "reboot"]) }
                ActionBtn { icon: "\uf186"; onClicked: Quickshell.execDetached(["systemctl", "suspend"]) }
                ActionBtn { icon: "\uf011"; onClicked: Quickshell.execDetached(["systemctl", "poweroff"]) }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 14
                color: Theme.bgPill

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                    Text { text: "\uf185"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.accentWarm }
                    WavySlider {
                        Layout.fillWidth: true
                        value: win.brightness
                        activeColor: Theme.accentWarm
                        onMoved: v => {
                            win.brightness = v;
                            Quickshell.execDetached(["brightnessctl", "set", Math.round(v * 100) + "%"]);
                        }
                    }
                    Text { text: Math.round(win.brightness * 100) + "%"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.fg }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: netM.containsMouse ? 10 : 21
                    color: win.ethConnected ? Theme.accent : Theme.bgPill
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.fill: parent; spacing: 0
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; spacing: 6
                                Text { text: "\uf0e8"; font.family: Theme.iconFont; font.pixelSize: 13; color: win.ethConnected ? Theme.accentOn : Theme.fg }
                                Text { Layout.fillWidth: true; text: "Сеть"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: win.ethConnected ? Theme.accentOn : Theme.fg }
                            }
                            MouseArea {
                                id: netM
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    win.ethConnected = !win.ethConnected;
                                    Quickshell.execDetached(["nmcli", "networking", win.ethConnected ? "on" : "off"]);
                                }
                            }
                        }
                        Item {
                            implicitWidth: 34; Layout.fillHeight: true
                            Text {
                                anchors.centerIn: parent
                                text: win.expandedSection === "net" ? "\uf078" : "\uf054"
                                font.family: Theme.iconFont; font.pixelSize: 10
                                color: win.ethConnected ? Theme.accentOn : Theme.fgMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: win.expandedSection = (win.expandedSection === "net" ? "" : "net")
                            }
                        }
                    }
                }

                Rectangle {
                    id: btPill
                    readonly property bool btOn: Bluetooth.defaultAdapter?.enabled ?? false
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: btM.containsMouse ? 10 : 21
                    color: btOn ? Theme.accent : Theme.bgPill
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.fill: parent; spacing: 0
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; spacing: 6
                                Text { text: "\uf293"; font.family: Theme.iconFont; font.pixelSize: 13; color: btPill.btOn ? Theme.accentOn : Theme.fg }
                                Text { Layout.fillWidth: true; text: "Bluetooth"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: btPill.btOn ? Theme.accentOn : Theme.fg }
                            }
                            MouseArea {
                                id: btM
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                            }
                        }
                        Item {
                            implicitWidth: 34; Layout.fillHeight: true
                            Text {
                                anchors.centerIn: parent
                                text: win.expandedSection === "bt" ? "\uf078" : "\uf054"
                                font.family: Theme.iconFont; font.pixelSize: 10
                                color: btPill.btOn ? Theme.accentOn : Theme.fgMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: win.expandedSection = (win.expandedSection === "bt" ? "" : "bt")
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: layM.containsMouse ? 10 : 20
                    color: win.scrollingLayout ? Theme.accentWarm : (layM.containsMouse ? Theme.bgPillHover : Theme.bgPill)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "\uf009"; font.family: Theme.iconFont; font.pixelSize: 12; color: win.scrollingLayout ? Theme.accentOn : Theme.fg }
                        Text {
                            text: win.scrollingLayout ? "Scrolling" : "Dwindle"
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
                            color: win.scrollingLayout ? Theme.accentOn : Theme.fg
                        }
                    }

                    MouseArea {
                        id: layM
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            win.scrollingLayout = !win.scrollingLayout;
                            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ general = { layout = '" + (win.scrollingLayout ? "scrolling" : "dwindle") + "' } })"]);
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: wallM.containsMouse ? 10 : 20
                    color: wallM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "\uf03e"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.accentWarm }
                        Text { text: "Обои"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.fg }
                    }

                    MouseArea {
                        id: wallM
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            win.open = false;
                            win.openWallpapers();
                        }
                    }
                }
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: pinM.containsMouse ? 10 : 20
                    color: win.dockPinned ? Theme.accent : (pinM.containsMouse ? Theme.bgPillHover : Theme.bgPill)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: "\uf08d"; font.family: Theme.iconFont; font.pixelSize: 12; color: win.dockPinned ? Theme.accentOn : Theme.fg }
                        Text {
                            text: win.dockPinned ? "Док закреплён" : "Закрепить док"
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
                            color: win.dockPinned ? Theme.accentOn : Theme.fg
                        }
                    }

                    MouseArea {
                        id: pinM
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: win.dockPinned = !win.dockPinned
                    }
                }
            }

            Rectangle {
                visible: win.expandedSection === "net"
                Layout.fillWidth: true
                implicitHeight: netTxt.implicitHeight + 18
                radius: 14
                color: Theme.bgFrame

                Text {
                    id: netTxt
                    anchors.fill: parent; anchors.margins: 9
                    text: win.netInfo
                    font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.fg
                    wrapMode: Text.Wrap
                }
            }

            ColumnLayout {
                visible: win.expandedSection === "bt"
                Layout.fillWidth: true
                spacing: 6

                Text {
                    visible: Bluetooth.devices.values.length === 0
                    text: "Нет сопряжённых Bluetooth-устройств"
                    font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.fgMuted
                }

                Repeater {
                    model: Bluetooth.devices
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 12
                        color: modelData.connected ? Theme.accentWarm : Theme.bgPill

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.margins: 12
                            text: modelData.name || modelData.address
                            font.family: Theme.fontFamily; font.pixelSize: 12
                            color: modelData.connected ? Theme.accentOn : Theme.fg
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.connected = !modelData.connected
                        }
                    }
                }
            }
        }
    }
}
