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
    property bool recording: false
    property bool recPaused: false
    property string recElapsed: "00:00"
    property bool screenSharing: false
    signal toggleRecPause()
    signal stopRecording()
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

    Process {
        id: sniSyncProc
        command: ["sh", "-c", "for svc in $(busctl --user list 2>/dev/null | awk '/^org\.kde\.StatusNotifierItem-/{print $1}'); do busctl --user call org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisterStatusNotifierItem s \"$svc\" 2>/dev/null || true; done"]
    }
    Timer {
        interval: 800
        running: true
        repeat: false
        onTriggered: sniSyncProc.running = true
    }

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
                implicitWidth: 31
                Layout.fillHeight: true

                Rectangle {
                    anchors.centerIn: parent
                    width: 31; height: 29
                    radius: Theme.r(menuMouse.pressed ? 6 : (menuMouse.containsMouse ? 8 : 13))
                    scale: menuMouse.pressed ? 0.92 : (menuMouse.containsMouse ? 1.08 : 1.0)
                    color: menuMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf303"
                        font.family: Theme.iconFont; font.pixelSize: 16; color: Theme.accent
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
                    width: parent.width; height: 29
                    radius: Theme.r(wsHover.hovered ? 9 : 13)
                    color: Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                }

                HoverHandler { id: wsHover }
                MouseArea {
                    z: 50
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y;
                        if (dy === 0) return;
                        var dir = dy > 0 ? "r-1" : "r+1";
                        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = '" + dir + "' })"]);
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

                            implicitWidth: isActive ? 29 : 23
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 23
                                radius: Theme.r(wsItemMouse.pressed ? 5 : (parent.isActive ? 7 : (wsItemMouse.containsMouse ? 6 : 10)))
                                scale: wsItemMouse.pressed ? 0.88 : (wsItemMouse.containsMouse ? 1.14 : 1.0)
                                color: parent.isActive ? Theme.accentWarm : (wsItemMouse.containsMouse ? Theme.bgElevated : (parent.hasWindows ? Theme.bgPillHover : "transparent"))

                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: wsId
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: isActive ? Font.Bold : (hasWindows ? Font.Bold : Font.Bold)
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
                height: 29
                radius: Theme.r(centerMouse.containsMouse ? 8 : 13)
                color: centerMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill

                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
            }

            MouseArea {
                z: 50
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y;
                    if (dy === 0) return;
                    var step = dy > 0 ? "5%+" : "5%-";
                    Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", step]);
                    bar.volumeScrolled();
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

                RowLayout {
                    visible: !bar.showPlayer
                    spacing: 6
                    Text {
                        text: "\uf028"
                        font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.accent
                    }
                    Text {
                        text: "Звук"
                        font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Theme.fg
                    }
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
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: Theme.fg
                        elide: Text.ElideRight; Layout.maximumWidth: 140
                        Layout.rightMargin: 4
                    }

                    Rectangle {
                        scale: prevM.pressed ? 0.94 : (prevM.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        implicitWidth: 30; implicitHeight: 29; radius: Theme.r(prevM.containsMouse ? 6 : 11)
                        color: prevM.containsMouse ? Theme.bgElevated : "transparent"
                        Text { anchors.centerIn: parent; text: "\uf048"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.fg }
                        MouseArea { cursorShape: Qt.PointingHandCursor; id: prevM; anchors.fill: parent; hoverEnabled: true; onClicked: bar.runAct(["playerctl", "previous"]) }
                    }
                    Rectangle {
                        scale: playM.pressed ? 0.94 : (playM.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        implicitWidth: 32; implicitHeight: 29; radius: Theme.r(playM.containsMouse ? 6 : 11)
                        color: playM.containsMouse ? Theme.bgElevated : "transparent"
                        Text { anchors.centerIn: parent; text: bar.isPlaying ? "\uf04c" : "\uf04b"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.accent }
                        MouseArea { cursorShape: Qt.PointingHandCursor; id: playM; anchors.fill: parent; hoverEnabled: true; onClicked: bar.runAct(["playerctl", "play-pause"]) }
                    }
                    Rectangle {
                        scale: nextM.pressed ? 0.94 : (nextM.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        implicitWidth: 30; implicitHeight: 29; radius: Theme.r(nextM.containsMouse ? 6 : 11)
                        color: nextM.containsMouse ? Theme.bgElevated : "transparent"
                        Text { anchors.centerIn: parent; text: "\uf051"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.fg }
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

            // Виджет записи экрана или уведомление о трансляции перед треем
            Item {
                id: recCastPill
                visible: bar.recording || bar.screenSharing
                Layout.fillHeight: true
                implicitWidth: recCastRow.implicitWidth + 16

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: 29
                    radius: Theme.r(13)
                    color: Theme.bgPill
                    border.color: bar.recording ? Theme.danger : Theme.accentWarm
                    border.width: 2
                }

                RowLayout {
                    id: recCastRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 8; height: 8; radius: Theme.r(4)
                        color: bar.recording ? (bar.recPaused ? Theme.accentWarm : Theme.danger) : Theme.accentWarm
                    }

                    Text {
                        visible: !bar.recording && bar.screenSharing
                        text: "Трансляция"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.fg
                    }

                    Text {
                        visible: bar.recording
                        text: bar.recElapsed
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.fg
                    }

                    Rectangle {
                        scale: pauseM.pressed ? 0.94 : (pauseM.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        visible: bar.recording
                        width: 20; height: 20; radius: Theme.r(10)
                        color: pauseM.containsMouse ? Theme.bgPillHover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: bar.recPaused ? "\uf04b" : "\uf04c"
                            font.family: Theme.iconFont; font.pixelSize: 13
                            color: Theme.fg
                        }
                        MouseArea {
                            id: pauseM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.toggleRecPause()
                        }
                    }

                    Rectangle {
                        scale: stopM.pressed ? 0.94 : (stopM.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        visible: bar.recording
                        width: 20; height: 20; radius: Theme.r(10)
                        color: stopM.containsMouse ? Theme.bgPillHover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "\uf04d"
                            font.family: Theme.iconFont; font.pixelSize: 13
                            color: Theme.danger
                        }
                        MouseArea {
                            id: stopM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.stopRecording()
                        }
                    }
                }
            }

            // Отдельный пузырь трея: стрелочка + плавно выезжающая строка иконок
            Item {
                id: trayPill
                readonly property bool hasTray: SystemTray.items.values.length > 0
                property bool expanded: false
                property int openMenus: 0
                Layout.fillHeight: true
                implicitWidth: trayRow.implicitWidth + 18

                Timer {
                    id: trayCloseTimer
                    interval: 600
                    onTriggered: {
                        if (!trayHover.hovered && trayPill.openMenus <= 0)
                            trayPill.expanded = false;
                    }
                }

                Connections {
                    target: trayHover
                    function onHoveredChanged() {
                        if (trayHover.hovered && trayPill.hasTray) {
                            trayCloseTimer.stop();
                            trayPill.expanded = true;
                        } else if (trayPill.openMenus <= 0) {
                            trayCloseTimer.restart();
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: 29
                    radius: Theme.r(14)
                    color: (trayHover.hovered || trayPill.expanded) ? Theme.bgPillHover : Theme.bgPill
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                HoverHandler { id: trayHover }

                RowLayout {
                    id: trayRow
                    anchors.centerIn: parent
                    height: 29
                    spacing: 0

                    Item {
                        implicitWidth: 16
                        implicitHeight: 29
                        Text {
                            anchors.centerIn: parent
                            text: "\uf053"
                            font.family: Theme.iconFont; font.pixelSize: 13
                            color: trayPill.hasTray ? Theme.fg : Theme.fgDim
                            rotation: trayPill.expanded ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        }
                    }

                    Item {
                        id: trayIconsClip
                        clip: true
                        implicitHeight: 29
                        Layout.preferredHeight: 29
                        Layout.preferredWidth: trayPill.expanded ? (trayIconsRow.implicitWidth + 10) : 0
                        implicitWidth: Layout.preferredWidth
                        Behavior on Layout.preferredWidth {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }

                        RowLayout {
                            id: trayIconsRow
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Repeater {
                                model: SystemTray.items
                                delegate: Item {
                                    id: trayItemBox
                                    required property var modelData
                                    implicitWidth: 20; implicitHeight: 29

                                    QsMenuAnchor {
                                        id: trayMenu
                                        menu: trayItemBox.modelData.menu
                                        anchor.window: bar
                                        anchor.item: trayItemBox
                                        anchor.edges: Edges.Bottom
                                        anchor.gravity: Edges.Bottom
                                        onVisibleChanged: {
                                            trayPill.openMenus = Math.max(0, trayPill.openMenus + (visible ? 1 : -1));
                                            if (visible) {
                                                trayCloseTimer.stop();
                                                trayPill.expanded = true;
                                            } else if (!trayHover.hovered && trayPill.openMenus <= 0) {
                                                trayCloseTimer.restart();
                                            }
                                        }
                                    }

                                    Image {
                                        id: trayImg
                                        anchors.centerIn: parent
                                        source: trayItemBox.modelData.icon
                                        sourceSize: Qt.size(16, 16)
                                        width: 16; height: 16
                                        visible: status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: trayImg.status !== Image.Ready
                                        text: (trayItemBox.modelData.id || "").toLowerCase().indexOf("zed") !== -1 ? "\uf132" : "\uf2d0"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 13
                                        color: Theme.accent
                                    }

                                    MouseArea {
                                        cursorShape: Qt.PointingHandCursor
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                trayItemBox.modelData.activate();
                                            } else if (trayItemBox.modelData.hasMenu && trayItemBox.modelData.menu) {
                                                trayCloseTimer.stop();
                                                trayMenu.open();
                                            } else if (trayItemBox.modelData.hasMenu) {
                                                var pt = trayItemBox.mapToItem(null, mouse.x, mouse.y);
                                                trayItemBox.modelData.display(bar, Math.round(pt.x), Math.round(pt.y));
                                            } else {
                                                trayItemBox.modelData.secondaryActivate();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Отдельный пузырь раскладки (EN / RU)
            Item {
                id: kbPill
                Layout.fillHeight: true
                implicitWidth: kbTxt.implicitWidth + 20

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: 29
                    radius: kbMouse.pressed ? Theme.r(8) : (kbMouse.containsMouse ? Theme.r(10) : Theme.r(14))
                    scale: kbMouse.pressed ? 0.94 : (kbMouse.containsMouse ? 1.05 : 1.0)
                    color: kbMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                }

                Text {
                    id: kbTxt
                    anchors.centerIn: parent
                    text: bar.kbLayout
                    font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Theme.fg
                }

                MouseArea {
                    id: kbMouse
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
                    onWheel: wheel => {
                        var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y;
                        if (dy !== 0) Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                implicitWidth: qsIcons.implicitWidth + 18

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: 29
                    radius: Theme.r(qsMouse.pressed ? 6 : (qsMouse.containsMouse ? 8 : 13))
                    scale: qsMouse.pressed ? 0.94 : (qsMouse.containsMouse ? 1.05 : 1.0)
                    color: qsMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                RowLayout {
                    id: qsIcons
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "\uf0e8"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.fg }
                    Text { text: "\uf013"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.fg }
                    Text { text: "\uf011"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.fg }
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
                    width: parent.width; height: 29
                    radius: Theme.r(timeMouse.pressed ? 6 : (timeMouse.containsMouse ? 8 : 13))
                    scale: timeMouse.pressed ? 0.94 : (timeMouse.containsMouse ? 1.05 : 1.0)
                    color: timeMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    id: timeText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Theme.fg
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
