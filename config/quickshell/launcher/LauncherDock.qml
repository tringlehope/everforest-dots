import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../components"
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
    property var openOrder: ({})
    property int openSeq: 0
    property var groupedClients: []
    property int activeWsId: 1
    property var appFreq: ({})
    property bool ctxOpen: false
    property string ctxAddr: ""
    property string ctxName: ""
    property string ctxIcon: ""
    property real ctxIconCenterX: 0

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
                        for (var k = 0; k < arr.length; k++) {
                            var ad = arr[k].address;
                            if (ad && launcherRoot.openOrder[ad] === undefined) {
                                launcherRoot.openSeq += 1;
                                launcherRoot.openOrder[ad] = launcherRoot.openSeq;
                            }
                        }
                        arr.sort((a, b) => {
                            var wa = a.workspace?.id ?? 0;
                            var wb = b.workspace?.id ?? 0;
                            if (wa !== wb) return wa - wb;
                            return (launcherRoot.openOrder[a.address] || 0) - (launcherRoot.openOrder[b.address] || 0);
                        });
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

    function swapLayout(str) {
        var ru = "йцукенгшщзхъфывапролджэячсмитьбюё";
        var en = "qwertyuiop[]asdfghjkl;'zxcvbnm,.`";
        var out = "";
        for (var i = 0; i < str.length; i++) {
            var ch = str.charAt(i);
            var ir = ru.indexOf(ch);
            if (ir !== -1) { out += en.charAt(ir); continue; }
            var ie = en.indexOf(ch);
            if (ie !== -1) { out += ru.charAt(ie); continue; }
            out += ch;
        }
        return out;
    }

    function fuzzyScore(q, target) {
        if (!q || !target) return -1;
        var t = target.toLowerCase();
        var idx = t.indexOf(q);
        if (idx === 0) return 1000 - t.length;
        if (idx > 0) {
            var prev = t.charAt(idx - 1);
            if (prev === " " || prev === "-" || prev === "_") return 850 - idx;
            return 650 - idx;
        }
        var qi = 0;
        var score = 0;
        var streak = 0;
        for (var ti = 0; ti < t.length && qi < q.length; ti++) {
            if (t.charAt(ti) === q.charAt(qi)) {
                score += 10 + streak * 6;
                if (ti === 0 || t.charAt(ti - 1) === " " || t.charAt(ti - 1) === "-" || t.charAt(ti - 1) === "_") {
                    score += 15;
                }
                streak += 1;
                qi += 1;
            } else {
                streak = 0;
                score -= 1;
            }
        }
        if (qi < q.length) return -1;
        return Math.max(1, 300 + score - (t.length - q.length));
    }

    function scoreApp(app, q1, q2) {
        var best = -1;
        var sName = Math.max(fuzzyScore(q1, app.name), fuzzyScore(q2, app.name));
        if (sName > 0) best = Math.max(best, sName + 200);
        if (app.genericName) {
            var sGen = Math.max(fuzzyScore(q1, app.genericName), fuzzyScore(q2, app.genericName));
            if (sGen > 0) best = Math.max(best, sGen);
        }
        if (app.id) {
            var sId = Math.max(fuzzyScore(q1, app.id), fuzzyScore(q2, app.id));
            if (sId > 0) best = Math.max(best, sId - 50);
        }
        if (app.keywords) {
            var kw = Array.isArray(app.keywords) ? app.keywords.join(" ") : String(app.keywords);
            var sKw = Math.max(fuzzyScore(q1, kw), fuzzyScore(q2, kw));
            if (sKw > 0) best = Math.max(best, sKw);
        }
        return best;
    }

    function appNameForClient(cls) {
        if (!cls) return "Приложение";
        var low = cls.toLowerCase();
        var list = DesktopEntries.applications.values;
        for (var i = 0; i < list.length; i++) {
            var a = list[i];
            if (a.id.toLowerCase() === low || (a.startupClass && a.startupClass.toLowerCase() === low)) {
                return a.name || cls;
            }
        }
        for (var j = 0; j < list.length; j++) {
            var b = list[j];
            var bid = b.id.toLowerCase();
            if (bid.indexOf(low) !== -1 || low.indexOf(bid) !== -1) {
                return b.name || cls;
            }
        }
        return cls.charAt(0).toUpperCase() + cls.slice(1);
    }

    function iconForClient(cls) {
        if (!cls) return Quickshell.iconPath("application-x-executable");
        var low = cls.toLowerCase();
        var list = DesktopEntries.applications.values;
        for (var i = 0; i < list.length; i++) {
            var a = list[i];
            if (a.id.toLowerCase() === low || (a.startupClass && a.startupClass.toLowerCase() === low)) {
                return Quickshell.iconPath(a.icon || "application-x-executable", "application-x-executable");
            }
        }
        for (var j = 0; j < list.length; j++) {
            var b = list[j];
            var bid = b.id.toLowerCase();
            if (bid.indexOf(low) !== -1 || low.indexOf(bid) !== -1) {
                return Quickshell.iconPath(b.icon || "application-x-executable", "application-x-executable");
            }
        }
        return Quickshell.iconPath(low, "application-x-executable");
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
            anchors.verticalCenterOffset: 650
            width: 490
            height: 540
            radius: Theme.radiusCard
            color: Theme.bgSurface
            border.color: Theme.accent
            border.width: 3
            scale: 0.94

            states: [
                State {
                    name: "open"
                    when: launcherRoot.open
                    PropertyChanges { target: menuCard; anchors.verticalCenterOffset: 0; scale: 1.0 }
                },
                State {
                    name: "closed"
                    when: !launcherRoot.open
                    PropertyChanges { target: menuCard; anchors.verticalCenterOffset: 650; scale: 0.94 }
                }
            ]

            transitions: [
                Transition {
                    to: "open"
                    ParallelAnimation {
                        SpringAnimation { property: "anchors.verticalCenterOffset"; spring: 4.0; damping: 0.28; epsilon: 0.5 }
                        SpringAnimation { property: "scale"; spring: 4.2; damping: 0.26; epsilon: 0.005 }
                    }
                },
                Transition {
                    to: "closed"
                    ParallelAnimation {
                        NumberAnimation { property: "anchors.verticalCenterOffset"; duration: 150; easing.type: Easing.InCubic }
                        NumberAnimation { property: "scale"; duration: 150; easing.type: Easing.InCubic }
                    }
                }
            ]

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
                                font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 13
                                color: Theme.fg
                                selectByMouse: true
                                Keys.onEscapePressed: launcherRoot.open = false
                                Text {
                                    visible: !parent.text
                                    text: "Поиск..."
                                    font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 13
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
                        Behavior on radius { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { anchors.centerIn: parent; text: "\uf00d"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.fgMuted }
                        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: launcherRoot.open = false }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
        OverscrollStretch {}
                        id: appList
                        anchors.fill: parent
                        anchors.rightMargin: 10
                        clip: true
                        spacing: 6
                        model: {
                            var q1 = launcherRoot.searchText.trim().toLowerCase();
                            var q2 = launcherRoot.swapLayout(q1);
                            var list = DesktopEntries.applications.values;
                            var scored = [];
                            for (var i = 0; i < list.length; i++) {
                                var app = list[i];
                                if (app.noDisplay) continue;
                                if (!q1) {
                                    scored.push({ app: app, score: 0 });
                                } else {
                                    var sc = launcherRoot.scoreApp(app, q1, q2);
                                    if (sc > 0) scored.push({ app: app, score: sc });
                                }
                            }
                            scored.sort((a, b) => {
                                if (q1 && b.score !== a.score) return b.score - a.score;
                                var fa = launcherRoot.appFreq[a.app.id] || 0;
                                var fb = launcherRoot.appFreq[b.app.id] || 0;
                                if (fb !== fa) return fb - fa;
                                return a.app.name.localeCompare(b.app.name);
                            });
                            var res = [];
                            for (var j = 0; j < scored.length; j++) res.push(scored[j].app);
                            return res;
                        }

                        delegate: Rectangle {
                            required property var modelData
                            width: appList.width
                            implicitHeight: 50
                            radius: Theme.r(appMouse.pressed ? 6 : (appMouse.containsMouse ? 9 : 14))
                            scale: appMouse.pressed ? 0.97 : (appMouse.containsMouse ? 1.02 : 1.0)
                            color: appMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                            Behavior on radius { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                            Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
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
                                    font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold
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
                    Behavior on radius { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                    Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: "\uf021"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.accent }
                        Text { text: "Обновить софт"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.fg }
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
        visible: dockTrans.y < 94 || shouldShow
        exclusiveZone: (launcherRoot.pinned && launcherRoot.runningClients.length > 0) ? 90 : -1
        anchors { bottom: true }
        margins.bottom: (Theme.showFrame && !Theme.isWin7 && !Theme.dockPinned ? Theme.frameThickness : 0) + 8
        implicitWidth: launcherRoot.runningClients.length <= 1 ? 82 : Math.max(82, dockRow.implicitWidth + 24)
        implicitHeight: 96
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-dock"

        Rectangle {
            id: dockCard
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 82
            radius: Theme.r(22)
            color: Theme.bgSurface
            border.color: Theme.accent
            border.width: 3

            transform: Translate {
                id: dockTrans
                y: dockWin.shouldShow ? 0 : 98
                Behavior on y { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
            }

            RowLayout {
                id: dockRow
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: launcherRoot.runningClients
                    delegate: Rectangle {
                        id: dockTile
                        required property var modelData
                        readonly property bool isFocused: (modelData.focusHistoryID ?? 99) === 0
                        implicitWidth: 60
                        implicitHeight: 60
                        width: 60; height: 60
                        radius: dockItemMouse.pressed ? Theme.r(8) : (dockItemMouse.containsMouse ? Theme.r(11) : Theme.r(13))
                        z: dockItemMouse.containsMouse ? 10 : 0
                        color: isFocused ? Theme.bgFrame : (dockItemMouse.containsMouse ? Theme.bgPillHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on radius { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }

                        Item {
                            anchors.centerIn: parent
                            width: 46; height: 46
                            scale: dockItemMouse.pressed ? 0.92 : (dockItemMouse.containsMouse ? 1.24 : 1.0)
                            Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                            transform: Translate {
                                y: dockItemMouse.containsMouse ? -6 : 0
                                Behavior on y { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                            }

                            Image {
                                id: dockIconImg
                                anchors.fill: parent
                                source: launcherRoot.iconForClient(dockTile.modelData.class)
                                sourceSize: Qt.size(48, 48)
                                asynchronous: true
                                smooth: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: dockIconImg.status !== Image.Ready
                                text: "\uf2d0"
                                font.family: Theme.iconFont
                                font.pixelSize: 22
                                color: Theme.fg
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            width: dockTile.isFocused ? 18 : 0
                            height: 3
                            radius: Theme.r(2)
                            color: Theme.accent
                            Behavior on width { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                        }

                        MouseArea {
                            id: dockItemMouse
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                var addr = dockTile.modelData.address || "";
                                if (mouse.button === Qt.RightButton) {
                                    var pt = dockTile.mapToItem(dockWin.contentItem, dockTile.width / 2, 0);
                                    launcherRoot.ctxAddr = addr;
                                    launcherRoot.ctxName = launcherRoot.appNameForClient(dockTile.modelData.class);
                                    launcherRoot.ctxIcon = launcherRoot.iconForClient(dockTile.modelData.class);
                                    launcherRoot.ctxIconCenterX = pt.x;
                                    launcherRoot.ctxOpen = true;
                                    return;
                                }
                                launcherRoot.ctxOpen = false;
                                if (addr !== "") {
                                    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + addr + "' })"]);
                                }
                                launcherRoot.open = false;
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: ctxWin
        visible: launcherRoot.ctxOpen
        exclusiveZone: -1
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-dock-menu"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: launcherRoot.ctxOpen = false
        }

        Rectangle {
            id: ctxCard
            x: Math.max(16, Math.min(parent.width - width - 16, (parent.width - dockWin.implicitWidth) / 2 + launcherRoot.ctxIconCenterX - width / 2))
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (Theme.showFrame && !Theme.isWin7 && !Theme.dockPinned ? Theme.frameThickness : 0) + 98
            width: 240
            height: ctxCol.implicitHeight + 20
            radius: Theme.radiusCard
            color: Theme.bgSurface
            border.color: Theme.accent
            border.width: 2

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: ctxCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    spacing: 10

                    Item {
                        width: 22; height: 22
                        Image {
                            id: ctxIconImg
                            anchors.fill: parent
                            sourceSize: Qt.size(32, 32)
                            source: launcherRoot.ctxIcon
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: ctxIconImg
                            source: ctxIconImg
                            saturation: -1.0
                            colorization: 0.85
                            colorizationColor: Theme.fg
                            visible: ctxIconImg.status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: Theme.iconFont; font.pixelSize: 16; color: Theme.fg
                            visible: ctxIconImg.status !== Image.Ready
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: launcherRoot.ctxName
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold
                        color: Theme.fg
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.borderSubtle
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.r(ctxCloseMouse.pressed ? 6 : (ctxCloseMouse.containsMouse ? 9 : 12))
                    scale: ctxCloseMouse.pressed ? 0.96 : (ctxCloseMouse.containsMouse ? 1.02 : 1.0)
                    color: ctxCloseMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                    Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text { text: ""; font.family: Theme.iconFont; font.pixelSize: 13; color: "#e67e80" }
                        Text { text: "Закрыть окно"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.fg; Layout.fillWidth: true }
                    }

                    MouseArea {
                        id: ctxCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var addr = launcherRoot.ctxAddr;
                            launcherRoot.ctxOpen = false;
                            if (addr !== "") {
                                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close({ window = 'address:" + addr + "' })"]);
                            }
                        }
                    }
                }
            }
        }
    }
}
