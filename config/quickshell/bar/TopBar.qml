import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."

PanelWindow {
    id: bar

    signal toggleLauncher()
    signal toggleAudio()
    signal toggleQuickSettings()
    signal toggleNotifications()
    signal volumeScrolled()

    anchors { left: true; right: true; top: true }
    implicitHeight: Theme.topBarHeight
    exclusiveZone: Theme.topBarHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-bar"

    property int activeWsId: 1
    property var occupiedWs: ({})
    property string kbLayout: "EN"
    property string playerState: ""
    property string playerTitle: ""
    property string playerName: ""

    Process { id: wsDispatch }
    Process { id: actProc }

    function runAct(cmd) {
        actProc.command = cmd;
        actProc.running = false;
        actProc.running = true;
    }

    Process {
        id: stateProc
        command: ["sh", "-c",
            "hyprctl activeworkspace -j | python3 -c \"import sys,json; print(json.load(sys.stdin).get('id',1))\"\n" +
            "hyprctl clients -j | python3 -c \"import sys,json; print(','.join(str(c['workspace']['id']) for c in json.load(sys.stdin)))\"\n" +
            "hyprctl devices -j | python3 -c \"import sys,json; ks=json.load(sys.stdin).get('keyboards',[]); m=[k for k in ks if k.get('main')] or ks; print((m[0].get('active_keymap','EN') if m else 'EN'))\"\n" +
            "python3 -c \"import subprocess\ntry:\n  out=subprocess.check_output(['playerctl','-a','-f','{{status}}||{{playerName}}||{{title}}','metadata'],stderr=subprocess.DEVNULL).decode().splitlines()\n  p=[l.split('||',2) for l in out if l.startswith('Playing||')] or [l.split('||',2) for l in out if l.startswith('Paused||')]\n  print(p[0][0]+'\\n'+p[0][2]+'\\n'+p[0][1] if p else '\\n\\n')\nexcept: print('\\n\\n')\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                if (lines.length >= 1) {
                    var id = parseInt(lines[0].trim());
                    if (!isNaN(id)) bar.activeWsId = id;
                }
                var occ = {};
                if (lines.length >= 2 && lines[1].trim().length > 0) {
                    var parts = lines[1].trim().split(",");
                    for (var i = 0; i < parts.length; i++) occ[parts[i]] = true;
                }
                bar.occupiedWs = occ;
                if (lines.length >= 3) {
                    var km = lines[2].toLowerCase();
                    bar.kbLayout = (km.indexOf("rus") !== -1 || km.indexOf("ру") !== -1) ? "RU" : "EN";
                }
                if (lines.length >= 4) {
                    var st = lines[3].trim();
                    bar.playerState = (st === "Playing" || st === "Paused") ? st : "";
                }
                if (lines.length >= 5) {
                    bar.playerTitle = lines[4].trim();
                }
                if (lines.length >= 6) {
                    bar.playerName = lines[5].trim().toLowerCase();
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { stateProc.running = true; }
    }
    Timer { interval: 500; running: true; repeat: true; onTriggered: stateProc.running = true }

    readonly property bool showPlayer: playerState === "Playing" || playerState === "Paused"
    readonly property bool isPlaying: playerState === "Playing"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgFrame
        visible: Theme.showFrame
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        // --- ЛЕВЫЙ БЛОК ---
        RowLayout {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: 6

            Item {
                implicitWidth: 28
                Layout.fillHeight: true

                Rectangle {
                    anchors.centerIn: parent
                    width: 28; height: 26
                    radius: menuMouse.containsMouse ? 8 : 13
                    color: menuMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf303"
                        font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.accent
                    }
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: menuMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.toggleLauncher()
                }
            }

            Item {
                implicitWidth: wsRow.implicitWidth + 10
                Layout.fillHeight: true

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: 26
                    radius: wsHover.hovered ? 9 : 13
                    color: Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                }

                HoverHandler { id: wsHover }
                WheelHandler {
                    onWheel: event => {
                        var dir = event.angleDelta.y > 0 ? "r-1" : "r+1";
                        wsDispatch.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = '" + dir + "' })"];
                        wsDispatch.running = false;
                        wsDispatch.running = true;
                    }
                }

                RowLayout {
                    id: wsRow
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 5
                    spacing: 2

                    Repeater {
                        model: 9
                        delegate: Item {
                            readonly property int wsId: index + 1
                            readonly property bool isActive: bar.activeWsId === wsId
                            readonly property bool hasWindows: bar.occupiedWs[String(wsId)] === true

                            implicitWidth: isActive ? 26 : 21
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 20
                                radius: parent.isActive ? 7 : (wsItemMouse.containsMouse ? 6 : 10)
                                color: parent.isActive ? Theme.accentWarm : (parent.hasWindows ? Theme.bgPillHover : "transparent")

                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: wsId
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: isActive ? Font.Black : (hasWindows ? Font.Black : Font.Black)
                                    color: isActive ? Theme.accentOn : (hasWindows ? Theme.fg : Theme.fgDim)
                                }
                            }

                            MouseArea {
                                cursorShape: Qt.PointingHandCursor
                                id: wsItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    wsDispatch.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + wsId + " })"];
                                    wsDispatch.running = false;
                                    wsDispatch.running = true;
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- ЦЕНТР: «Звук» или мини-плеер ---
        Item {
            anchors.centerIn: parent
            height: bar.height
            implicitWidth: centerRow.implicitWidth + 24

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 26
                radius: centerMouse.containsMouse ? 8 : 13
                color: centerMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill

                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
            }

            WheelHandler {
                onWheel: event => {
                    var step = event.angleDelta.y > 0 ? "5%+" : "5%-";
                    bar.runAct(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", step]);
                }
            }

            MouseArea {
                cursorShape: Qt.PointingHandCursor
                id: centerMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.toggleAudio()
            }

            RowLayout {
                id: centerRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    visible: !bar.showPlayer
                    text: "Звук"
                    font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg
                }

                RowLayout {
                    visible: bar.showPlayer
                    spacing: 4

                    IconImage {
                        source: Quickshell.iconPath((bar.playerName || "audio-x-generic").split(".")[0], "audio-x-generic")
                        implicitSize: 16
                        width: 16; height: 16
                    }

                    Text {
                        text: bar.playerTitle || "Музыка"
                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fg
                        elide: Text.ElideRight; Layout.maximumWidth: 140
                        Layout.rightMargin: 4
                    }

                    Rectangle {
                        implicitWidth: 30; implicitHeight: 26; radius: prevM.containsMouse ? 6 : 11
                        color: prevM.containsMouse ? Theme.bgElevated : "transparent"
                        Text { anchors.centerIn: parent; text: "\uf048"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.fg }
                        MouseArea { cursorShape: Qt.PointingHandCursor; id: prevM; anchors.fill: parent; hoverEnabled: true; onClicked: bar.runAct(["playerctl", "previous"]) }
                    }
                    Rectangle {
                        implicitWidth: 32; implicitHeight: 26; radius: playM.containsMouse ? 6 : 11
                        color: playM.containsMouse ? Theme.bgElevated : "transparent"
                        Text { anchors.centerIn: parent; text: bar.isPlaying ? "\uf04c" : "\uf04b"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.accent }
                        MouseArea { cursorShape: Qt.PointingHandCursor; id: playM; anchors.fill: parent; hoverEnabled: true; onClicked: bar.runAct(["playerctl", "play-pause"]) }
                    }
                    Rectangle {
                        implicitWidth: 30; implicitHeight: 26; radius: nextM.containsMouse ? 6 : 11
                        color: nextM.containsMouse ? Theme.bgElevated : "transparent"
                        Text { anchors.centerIn: parent; text: "\uf051"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.fg }
                        MouseArea { cursorShape: Qt.PointingHandCursor; id: nextM; anchors.fill: parent; hoverEnabled: true; onClicked: bar.runAct(["playerctl", "next"]) }
                    }
                }
            }
        }

        // --- ПРАВЫЙ БЛОК ---
        RowLayout {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: 6

            Item {
                id: trayPill
                readonly property bool hasTray: SystemTray.items.values.length > 0
                readonly property bool expanded: trayHover.hovered && hasTray
                Layout.fillHeight: true
                implicitWidth: trayContent.implicitWidth + 16

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: 26
                    radius: trayHover.hovered ? 8 : 13
                    color: trayHover.hovered ? Theme.bgPillHover : Theme.bgPill
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                }

                HoverHandler { id: trayHover }

                RowLayout {
                    id: trayContent
                    anchors.centerIn: parent
                    spacing: 8

                    RowLayout {
                        visible: trayPill.expanded
                        spacing: 10
                        Repeater {
                            model: SystemTray.items
                            delegate: Item {
                                required property var modelData
                                implicitWidth: 16; implicitHeight: 26
                                Image {
                                    anchors.centerIn: parent
                                    source: modelData.icon
                                    sourceSize: Qt.size(15, 15)
                                    width: 15; height: 15
                                }
                                MouseArea {
                                    cursorShape: Qt.PointingHandCursor
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.LeftButton) modelData.activate();
                                        else modelData.secondaryActivate();
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: !trayPill.expanded
                        text: "\uf053"
                        font.family: Theme.iconFont; font.pixelSize: 10
                        color: trayPill.hasTray ? Theme.fg : Theme.fgDim
                    }

                    Item {
                        implicitWidth: kbTxt.implicitWidth + 4
                        Layout.fillHeight: true
                        Text {
                            id: kbTxt
                            anchors.centerIn: parent
                            text: bar.kbLayout
                            font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fg
                        }
                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            onClicked: bar.runAct(["hyprctl", "switchxkblayout", "all", "next"])
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                implicitWidth: qsIcons.implicitWidth + 18

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: 26
                    radius: qsMouse.containsMouse ? 8 : 13
                    color: qsMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                }

                RowLayout {
                    id: qsIcons
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "\uf0e8"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.fg }
                    Text { text: "\uf013"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.fg }
                    Text { text: "\uf011"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.fg }
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: qsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.toggleQuickSettings()
                }
            }

            Item {
                Layout.fillHeight: true
                implicitWidth: timeText.implicitWidth + 18

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: 26
                    radius: timeMouse.containsMouse ? 8 : 13
                    color: timeMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                }

                Text {
                    id: timeText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: timeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.toggleNotifications()
                }
            }
        }
    }
}
