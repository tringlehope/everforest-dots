import QtQuick
import QtQuick.Effects
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
        visible: Theme.showFrame || Theme.panelStyle === "panel"
        radius: (Theme.panelStyle === "panel" && !Theme.isWin7) ? 16 : 0
        Rectangle {
            visible: Theme.panelStyle === "panel" && !Theme.isWin7
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 16
            color: Theme.bgFrame
        }
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
                    radius: Theme.r(menuMouse.pressed ? 7 : (menuMouse.containsMouse ? 15 : 11))
                    scale: menuMouse.pressed ? 0.92 : (menuMouse.containsMouse ? 1.08 : 1.0)
                    color: menuMouse.pressed ? Theme.accentWarm : (menuMouse.containsMouse ? Theme.accent : Theme.bgPill)
                    Behavior on radius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                    Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf303"
                        font.family: Theme.iconFont; font.pixelSize: 16; color: (menuMouse.containsMouse || menuMouse.pressed) ? Theme.accentOn : Theme.accent; Behavior on color { ColorAnimation { duration: 150 } }
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
                    color: wsHover.hovered ? Theme.bgElevated : Theme.bgPill
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on radius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                }

                HoverHandler { id: wsHover }
                MouseArea {
                    z: 50
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y;
                        if (dy === 0) return;
                        var step = dy > 0 ? "-1" : "1";
                        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/ws_step.sh", step]);
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
                                radius: Theme.r(wsItemMouse.pressed ? 5 : (wsItemMouse.containsMouse ? 12 : (parent.isActive ? 7 : 10)))
                                scale: wsItemMouse.pressed ? 0.88 : (wsItemMouse.containsMouse ? 1.14 : 1.0)
                                color: parent.isActive ? Theme.accentWarm : (wsItemMouse.pressed ? Theme.accentWarm : (wsItemMouse.containsMouse ? Theme.accent : (parent.hasWindows ? Theme.bgPillHover : "transparent")))

                                Behavior on width { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                                Behavior on radius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                                Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: wsId
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: isActive ? Font.Bold : (hasWindows ? Font.Bold : Font.Bold)
                                    color: (isActive || wsItemMouse.containsMouse || wsItemMouse.pressed) ? Theme.accentOn : (hasWindows ? Theme.fg : Theme.fgDim)
                                    Behavior on color { ColorAnimation { duration: 150 } }
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

        // --- ЦЕНТР: «Звук» или 2 сегмента мини-плеера ---
        RowLayout {
            id: centerGroup
            anchors.centerIn: parent
            height: bar.height
            spacing: 3

            // Левый сегмент: «Звук» или «Иконка + Название трека»
            Item {
                id: centerInfoItem
                Layout.fillHeight: true
                implicitWidth: infoRow.implicitWidth + 22

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 29
                    topLeftRadius: Theme.r(centerMouse.pressed ? 7 : 15)
                    bottomLeftRadius: topLeftRadius
                    topRightRadius: Theme.r(centerMouse.pressed ? 7 : ((centerMouse.containsMouse || !bar.showPlayer) ? 15 : 5))
                    bottomRightRadius: topRightRadius
                    scale: centerMouse.pressed ? 0.95 : (centerMouse.containsMouse ? 1.03 : 1.0)
                    color: centerMouse.pressed ? Theme.accentWarm : (centerMouse.containsMouse ? Theme.accent : Theme.bgPill)

                    Behavior on width { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                    Behavior on topLeftRadius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                    Behavior on topRightRadius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                    Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    z: 50
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y;
                        if (dy === 0) return;
                        var step = dy > 0 ? "2%+" : "2%-";
                        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", step]);
                        bar.volumeScrolled();
                    }
                }

                MouseArea {
                    id: centerMouse
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.toggleAudio()
                }

                RowLayout {
                    id: infoRow
                    anchors.centerIn: parent
                    spacing: 6

                    RowLayout {
                        visible: !bar.showPlayer
                        spacing: 6
                        Text {
                            text: ""
                            font.family: Theme.iconFont; font.pixelSize: 13
                            color: (centerMouse.containsMouse || centerMouse.pressed) ? Theme.accentOn : Theme.accent
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            text: "Звук"
                            font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold
                            color: (centerMouse.containsMouse || centerMouse.pressed) ? Theme.accentOn : Theme.fg
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    RowLayout {
                        visible: bar.showPlayer
                        spacing: 6

                        Item {
                            width: 16; height: 16
                            IconImage {
                                id: playerIconImg
                                anchors.fill: parent
                                source: Quickshell.iconPath((bar.playerName || "audio-x-generic").split(".")[0], "audio-x-generic")
                                implicitSize: 16
                                visible: false
                            }
                            MultiEffect {
                                anchors.fill: playerIconImg
                                source: playerIconImg
                                saturation: -1.0
                                colorization: 0.85
                                colorizationColor: (centerMouse.containsMouse || centerMouse.pressed) ? Theme.accentOn : Theme.accent
                            }
                        }

                        Text {
                            text: bar.playerTitle || "Музыка"
                            font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold
                            color: (centerMouse.containsMouse || centerMouse.pressed) ? Theme.accentOn : Theme.fg
                            Behavior on color { ColorAnimation { duration: 150 } }
                            elide: Text.ElideRight; Layout.maximumWidth: 150
                        }
                    }
                }
            }

            // Правый сегмент: кнопки управления плеером
            Item {
                visible: bar.showPlayer
                Layout.fillHeight: true
                implicitWidth: mediaRow.implicitWidth + 10

                HoverHandler { id: mediaGroupHover }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 29
                    topLeftRadius: Theme.r(mediaGroupHover.hovered ? 15 : 5)
                    bottomLeftRadius: topLeftRadius
                    topRightRadius: Theme.r(15)
                    bottomRightRadius: topRightRadius
                    color: Theme.bgPill

                    Behavior on topLeftRadius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                RowLayout {
                    id: mediaRow
                    anchors.centerIn: parent
                    spacing: 2

                    Rectangle {
                        scale: prevM.pressed ? 0.90 : (prevM.containsMouse ? 1.06 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on radius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        implicitWidth: 28; implicitHeight: 25
                        radius: Theme.r(prevM.pressed ? 7 : (prevM.containsMouse ? 12 : 8))
                        color: prevM.pressed ? Theme.accentWarm : (prevM.containsMouse ? Theme.accent : "transparent")
                        Text { anchors.centerIn: parent; text: ""; font.family: Theme.iconFont; font.pixelSize: 12; color: (prevM.containsMouse || prevM.pressed) ? Theme.accentOn : Theme.fg; Behavior on color { ColorAnimation { duration: 150 } } }
                        MouseArea { cursorShape: Qt.PointingHandCursor; id: prevM; anchors.fill: parent; hoverEnabled: true; onClicked: bar.runAct(["playerctl", "previous"]) }
                    }
                    Rectangle {
                        scale: playM.pressed ? 0.90 : (playM.containsMouse ? 1.06 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on radius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        implicitWidth: 30; implicitHeight: 25
                        radius: Theme.r(playM.pressed ? 7 : (playM.containsMouse ? 12 : 8))
                        color: playM.pressed ? Theme.accentWarm : (playM.containsMouse ? Theme.accent : "transparent")
                        Text { anchors.centerIn: parent; text: bar.isPlaying ? "" : ""; font.family: Theme.iconFont; font.pixelSize: 12; color: (playM.containsMouse || playM.pressed) ? Theme.accentOn : Theme.accent; Behavior on color { ColorAnimation { duration: 150 } } }
                        MouseArea { cursorShape: Qt.PointingHandCursor; id: playM; anchors.fill: parent; hoverEnabled: true; onClicked: bar.runAct(["playerctl", "play-pause"]) }
                    }
                    Rectangle {
                        scale: nextM.pressed ? 0.90 : (nextM.containsMouse ? 1.06 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on radius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        implicitWidth: 28; implicitHeight: 25
                        radius: Theme.r(nextM.pressed ? 7 : (nextM.containsMouse ? 12 : 8))
                        color: nextM.pressed ? Theme.accentWarm : (nextM.containsMouse ? Theme.accent : "transparent")
                        Text { anchors.centerIn: parent; text: ""; font.family: Theme.iconFont; font.pixelSize: 12; color: (nextM.containsMouse || nextM.pressed) ? Theme.accentOn : Theme.fg; Behavior on color { ColorAnimation { duration: 150 } } }
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
                        Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
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
                        Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
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
                            Behavior on rotation { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        }
                    }

                    Item {
                        id: trayIconsClip
                        clip: true
                        implicitHeight: 29
                        Layout.preferredHeight: 29
                        Layout.preferredWidth: trayPill.expanded ? (trayIconsRow.implicitWidth + 10) : 0
                        implicitWidth: Layout.preferredWidth
                        Behavior on Layout.preferredWidth { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }

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

            // Сегментированная группа M3 Expressive: Раскладка | Быстрые настройки | Часы
            RowLayout {
                Layout.fillHeight: true
                spacing: 3

                // Левый сегмент: Раскладка (EN / RU)
                Item {
                    id: kbPill
                    Layout.fillHeight: true
                    implicitWidth: kbTxt.implicitWidth + 20

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width; height: 29
                        topLeftRadius: Theme.r(kbMouse.pressed ? 7 : 15)
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: Theme.r(kbMouse.pressed ? 7 : (kbMouse.containsMouse ? 15 : 5))
                        bottomRightRadius: topRightRadius
                        scale: kbMouse.pressed ? 0.94 : (kbMouse.containsMouse ? 1.04 : 1.0)
                        color: kbMouse.pressed ? Theme.accentWarm : (kbMouse.containsMouse ? Theme.accent : Theme.bgPill)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on topLeftRadius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on topRightRadius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                    }

                    Text {
                        id: kbTxt
                        anchors.centerIn: parent
                        text: bar.kbLayout
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: (kbMouse.containsMouse || kbMouse.pressed) ? Theme.accentOn : Theme.fg; Behavior on color { ColorAnimation { duration: 150 } }
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

                // Средний сегмент: Быстрые настройки
                Item {
                    Layout.fillHeight: true
                    implicitWidth: qsIcons.implicitWidth + 20

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width; height: 29
                        radius: Theme.r(qsMouse.pressed ? 7 : (qsMouse.containsMouse ? 15 : 5))
                        scale: qsMouse.pressed ? 0.94 : (qsMouse.containsMouse ? 1.04 : 1.0)
                        color: qsMouse.pressed ? Theme.accentWarm : (qsMouse.containsMouse ? Theme.accent : Theme.bgPill)
                        Behavior on radius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    RowLayout {
                        id: qsIcons
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: ""; font.family: Theme.iconFont; font.pixelSize: 14; color: (qsMouse.containsMouse || qsMouse.pressed) ? Theme.accentOn : Theme.fg; Behavior on color { ColorAnimation { duration: 150 } } }
                        Text { text: ""; font.family: Theme.iconFont; font.pixelSize: 14; color: (qsMouse.containsMouse || qsMouse.pressed) ? Theme.accentOn : Theme.fg; Behavior on color { ColorAnimation { duration: 150 } } }
                        Text { text: ""; font.family: Theme.iconFont; font.pixelSize: 14; color: (qsMouse.containsMouse || qsMouse.pressed) ? Theme.accentOn : Theme.fg; Behavior on color { ColorAnimation { duration: 150 } } }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: qsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.toggleQuickSettings()
                    }
                }

                // Правый акцентный сегмент: Часы / Уведомления
                Item {
                    Layout.fillHeight: true
                    implicitWidth: timeText.implicitWidth + 22

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width; height: 29
                        topLeftRadius: Theme.r(timeMouse.pressed ? 7 : (timeMouse.containsMouse ? 15 : 5))
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: Theme.r(timeMouse.pressed ? 7 : 15)
                        bottomRightRadius: topRightRadius
                        scale: timeMouse.pressed ? 0.94 : (timeMouse.containsMouse ? 1.04 : 1.0)
                        color: timeMouse.pressed ? Theme.accentWarm : (timeMouse.containsMouse ? Theme.accent : Theme.bgPill)
                        Behavior on topLeftRadius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on topRightRadius { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on scale { SpringAnimation { spring: 4.6; damping: 0.22; epsilon: 0.004 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        id: timeText
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: (timeMouse.containsMouse || timeMouse.pressed) ? Theme.accentOn : Theme.fg; Behavior on color { ColorAnimation { duration: 150 } }
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
}
