import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import ".."

Scope {
    id: launcherRoot
    property bool open: false
    property bool pinned: false
    property string searchText: ""
    property var runningClients: []
    property var groupedClients: []
    property int activeWsId: 1
    property var appFreq: ({})

    Process {
        id: clientsProc
        command: ["sh", "-c", "hyprctl activeworkspace -j | python3 -c \"import sys,json; print(json.load(sys.stdin).get('id',1))\" && hyprctl clients -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var idx = text.indexOf("\n");
                    if (idx !== -1) {
                        var ws = parseInt(text.slice(0, idx).trim());
                        if (!isNaN(ws)) launcherRoot.activeWsId = ws;
                        var arr = JSON.parse(text.slice(idx + 1));
                        arr.sort((a, b) => (a.workspace?.id ?? 0) - (b.workspace?.id ?? 0));
                        launcherRoot.runningClients = arr;
                        var map = {};
                        var groups = [];
                        for (var i = 0; i < arr.length; i++) {
                            var wid = arr[i].workspace?.id ?? 1;
                            if (!map[wid]) {
                                map[wid] = { wsId: wid, items: [] };
                                groups.push(map[wid]);
                            }
                            map[wid].items.push(arr[i]);
                        }
                        launcherRoot.groupedClients = groups;
                    }
                } catch (e) {
                    launcherRoot.runningClients = [];
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (launcherRoot.pinned || launcherRoot.open) clientsProc.running = true;
        }
    }
    Timer {
        interval: 800
        running: launcherRoot.pinned
        repeat: true
        onTriggered: clientsProc.running = true
    }

    Process {
        id: freqRead
        command: ["sh", "-c", "cat ~/.local/state/qs-app-freq.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { launcherRoot.appFreq = JSON.parse(text); } catch (e) { launcherRoot.appFreq = {}; }
            }
        }
    }

    function iconForClient(cls) {
        if (!cls) return Quickshell.iconPath("application-x-executable");
        var low = cls.toLowerCase();
        var list = DesktopEntries.applications.values;
        for (var i = 0; i < list.length; i++) {
            var a = list[i];
            if (a.id.toLowerCase() === low || (a.startupClass && a.startupClass.toLowerCase() === low)) {
                return Quickshell.iconPath(a.icon, "application-x-executable");
            }
        }
        return Quickshell.iconPath(cls, Quickshell.iconPath(low, "application-x-executable"));
    }

    function recordLaunch(appId) {
        var f = Object.assign({}, launcherRoot.appFreq);
        f[appId] = (f[appId] || 0) + 1;
        launcherRoot.appFreq = f;
        var jsonStr = JSON.stringify(f).replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + jsonStr + "' > ~/.local/state/qs-app-freq.json"]);
    }

    onOpenChanged: {
        if (open) {
            searchText = "";
            searchInput.forceActiveFocus();
            clientsProc.running = true;
            freqRead.running = true;
        }
    }
    onPinnedChanged: if (pinned) clientsProc.running = true

    // Меню приложений
    PanelWindow {
        visible: menuCard.anchors.verticalCenterOffset < 640 || launcherRoot.open
        exclusiveZone: -1
        anchors { top: true; bottom: true; left: true; right: true }
        margins.bottom: dockWin.shouldShow ? (dockWin.implicitHeight + Theme.frameThickness + 10) : 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-launcher"
        WlrLayershell.keyboardFocus: launcherRoot.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea { anchors.fill: parent; onClicked: launcherRoot.open = false }

        Rectangle {
            id: menuCard
            anchors.centerIn: parent
            anchors.verticalCenterOffset: launcherRoot.open ? 0 : 650
            width: 390
            height: 430
            radius: Theme.radiusCard
            color: Theme.bgSurface
            border.color: Theme.accent
            border.width: 3

            scale: launcherRoot.open ? 1.0 : 0.94
            Behavior on anchors.verticalCenterOffset {
                NumberAnimation {
                    duration: launcherRoot.open ? 180 : 120
                    easing.type: launcherRoot.open ? Easing.OutQuint : Easing.InQuad
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: launcherRoot.open ? 180 : 120
                    easing.type: launcherRoot.open ? Easing.OutQuint : Easing.InQuad
                }
            }

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Theme.r(14)
                        color: Theme.bgPill

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                            Text { text: "\uf002"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.fgMuted }
                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                text: launcherRoot.searchText
                                onTextChanged: launcherRoot.searchText = text
                                font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 13
                                color: Theme.fg
                                selectByMouse: true
                                Keys.onEscapePressed: launcherRoot.open = false
                                Text {
                                    visible: !parent.text
                                    text: "Поиск..."
                                    font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 13
                                    color: Theme.fgMuted
                                }
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34
                        radius: Theme.r(closeMouse.pressed ? 6 : (closeMouse.containsMouse ? 8 : 12))
                        scale: closeMouse.pressed ? 0.92 : (closeMouse.containsMouse ? 1.06 : 1.0)
                        color: closeMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                        Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { anchors.centerIn: parent; text: "\uf00d"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.fgMuted }
                        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: launcherRoot.open = false }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: appList
                        anchors.fill: parent
                        anchors.rightMargin: 10
                        clip: true
                        spacing: 6
                        model: {
                            var q = launcherRoot.searchText.toLowerCase();
                            var res = [];
                            var list = DesktopEntries.applications.values;
                            for (var i = 0; i < list.length; i++) {
                                var app = list[i];
                                if (app.noDisplay) continue;
                                if (!q || app.name.toLowerCase().indexOf(q) !== -1) res.push(app);
                            }
                            res.sort((a, b) => {
                                var fa = launcherRoot.appFreq[a.id] || 0;
                                var fb = launcherRoot.appFreq[b.id] || 0;
                                if (fb !== fa) return fb - fa;
                                return a.name.localeCompare(b.name);
                            });
                            return res;
                        }

                        delegate: Rectangle {
                            required property var modelData
                            width: appList.width
                            implicitHeight: 44
                            radius: Theme.r(appMouse.pressed ? 6 : (appMouse.containsMouse ? 9 : 14))
                            scale: appMouse.pressed ? 0.97 : (appMouse.containsMouse ? 1.02 : 1.0)
                            color: appMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                            Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 12; spacing: 10
                                IconImage {
                                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                    implicitSize: 48
                                    width: 32; height: 32
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Black
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                cursorShape: Qt.PointingHandCursor
                                id: appMouse
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    var appId = modelData.id;
                                    modelData.execute();
                                    launcherRoot.open = false;
                                    launcherRoot.recordLaunch(appId);
                                }
                            }
                        }
                    }

                    Canvas {
                        id: scrollWave
                        visible: appList.contentHeight > appList.height
                        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                        width: 6
                        property real pos: appList.visibleArea.yPosition
                        property real ratio: appList.visibleArea.heightRatio
                        onPosChanged: requestPaint()
                        onRatioChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var y1 = Math.max(4, pos * height);
                            var h = Math.max(24, ratio * height);
                            var y2 = Math.min(height - 4, y1 + h);
                            ctx.strokeStyle = Theme.accent;
                            ctx.lineWidth = 3;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            for (var y = y1; y <= y2; y += 2) {
                                var x = width / 2 + Math.sin(y * 0.35) * 1.6;
                                if (y === y1) ctx.moveTo(x, y);
                                else ctx.lineTo(x, y);
                            }
                            ctx.stroke();
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.r(updMouse.pressed ? 6 : (updMouse.containsMouse ? 9 : 14))
                    scale: updMouse.pressed ? 0.96 : (updMouse.containsMouse ? 1.02 : 1.0)
                    color: updMouse.containsMouse ? Theme.bgPillHover : Theme.bgElevated
                    border.color: Theme.borderSubtle
                    border.width: 1
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: "\uf021"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.accent }
                        Text { text: "Обновить софт"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg }
                    }
                    MouseArea { cursorShape: Qt.PointingHandCursor; id: updMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { launcherRoot.open = false; Quickshell.execDetached(["bauh"]); } }
                }
            }
        }
    }

    // Отдельное компактное окно для нижнего дока (может быть закреплено на экране)
    PanelWindow {
        id: dockWin
        readonly property bool shouldShow: (launcherRoot.open || launcherRoot.pinned) && launcherRoot.runningClients.length > 0
        visible: dockTrans.y < 108 || shouldShow
        exclusiveZone: (launcherRoot.pinned && launcherRoot.runningClients.length > 0) ? (implicitHeight + 8) : -1
        anchors { bottom: true }
        margins.bottom: (Theme.showFrame ? Theme.frameThickness : 0) + 8
        implicitWidth: Math.max(104, dockRow.implicitWidth + 32)
        implicitHeight: 112
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-dock"

        Rectangle {
            scale: dockItemMouse.pressed ? 0.94 : (dockItemMouse.containsMouse ? 1.04 : 1.0)
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 140 } }
            id: dockCard
            anchors.fill: parent
            radius: Theme.r(26)
            color: Theme.bgSurface
            border.color: Theme.accent
            border.width: 3

            transform: Translate {
                id: dockTrans
                y: dockWin.shouldShow ? 0 : 110
                Behavior on y {
                    NumberAnimation {
                        duration: dockWin.shouldShow ? 180 : 120
                        easing.type: dockWin.shouldShow ? Easing.OutQuint : Easing.InQuad
                    }
                }
            }

            RowLayout {
                id: dockRow
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: launcherRoot.runningClients
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isFocused: (modelData.focusHistoryID ?? 99) === 0
                        width: 68; height: 68
                        radius: Theme.r(dockItemMouse.pressed ? 10 : (dockItemMouse.containsMouse ? 14 : 18))
                        z: dockItemMouse.containsMouse ? 10 : 0
                        color: isFocused ? Theme.bgElevated : (dockItemMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill)
                        border.color: isFocused ? Theme.accent : "transparent"
                        border.width: isFocused ? 2 : 0
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        IconImage {
                            anchors.centerIn: parent
                            source: launcherRoot.iconForClient(modelData.class)
                            implicitSize: 54
                            width: 54; height: 54
                            scale: dockItemMouse.pressed ? 0.92 : (dockItemMouse.containsMouse ? 1.26 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                            transform: Translate {
                                y: dockItemMouse.containsMouse ? -7 : 0
                                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                            }
                        }

                        MouseArea {
                            id: dockItemMouse
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                var addr = modelData.address || "";
                                if (addr !== "") {
                                    Quickshell.execDetached(["sh", "-c", "hyprctl dispatch \"hl.dsp.focus({ window = 'address:" + addr + "' })\" 2>/dev/null || hyprctl dispatch \"hl.dsp.focuswindow('address:" + addr + "')\""]);
                                }
                                launcherRoot.open = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
