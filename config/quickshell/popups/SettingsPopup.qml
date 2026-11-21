import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import ".."

PanelWindow {
    id: win
    property bool open: false
    property int currentTab: 0
    property var monitors: []
    property int selectedMonIdx: 0

    property string selRes: ""
    property string selHz: ""
    property real selScale: 1.0
    property bool dirty: false
    property string activeDropdown: "" // "" | "res" | "hz" | "scale"

    visible: card.scale > 0.05 || open
    exclusiveZone: -1
    implicitWidth: 880
    implicitHeight: 560
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Process {
        id: monProc
        command: ["sh", "-c", "hyprctl monitors all -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text);
                    var list = [];
                    for (var i = 0; i < arr.length; i++) {
                        var m = arr[i];
                        var resMap = {};
                        var modes = m.availableModes || [];
                        for (var j = 0; j < modes.length; j++) {
                            var parts = modes[j].replace("Hz", "").split("@");
                            if (parts.length === 2) {
                                var r = parts[0];
                                var hz = String(Math.round(parseFloat(parts[1])));
                                if (!resMap[r]) resMap[r] = [];
                                if (resMap[r].indexOf(hz) === -1) resMap[r].push(hz);
                            }
                        }
                        var curRes = m.width + "x" + m.height;
                        for (var rk in resMap) resMap[rk].sort(function(a, b) { return parseInt(b) - parseInt(a); });
                        var curHz = String(Math.round(m.refreshRate || 60));
                        if (!resMap[curRes]) resMap[curRes] = [curHz];
                        list.push({
                            name: m.name,
                            width: m.width,
                            height: m.height,
                            x: m.x,
                            y: m.y,
                            scale: m.scale || 1.0,
                            curRes: curRes,
                            curHz: curHz,
                            resMap: resMap,
                            resList: Object.keys(resMap).sort(function(a, b) {
                                var pa = a.split('x'), pb = b.split('x');
                                var diff = (parseInt(pb[0]) * parseInt(pb[1])) - (parseInt(pa[0]) * parseInt(pa[1]));
                                return diff !== 0 ? diff : (parseInt(pb[0]) - parseInt(pa[0]));
                            })
                        });
                    }
                    win.monitors = list;
                    if (list.length > 0) {
                        var idx = Math.min(win.selectedMonIdx, list.length - 1);
                        win.selectedMonIdx = idx;
                        win.syncSelection(idx);
                    }
                    win.dirty = false;
                } catch (e) {}
            }
        }
    }

    function syncSelection(idx) {
        if (idx < 0 || idx >= monitors.length) return;
        var m = monitors[idx];
        selRes = m.curRes;
        selHz = m.curHz;
        selScale = m.scale;
    }

    function applyMonitors() {
        var luaLines = "";
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i];
            var modeStr = (i === selectedMonIdx) ? (selRes + "@" + selHz) : (m.curRes + "@" + m.curHz);
            var sc = (i === selectedMonIdx) ? selScale : m.scale;
            var posStr = Math.round(m.x) + "x" + Math.round(m.y);
            luaLines += "hl.monitor({ output = \"" + m.name + "\", mode = \"" + modeStr + "\", position = \"" + posStr + "\", scale = " + sc + " })\n";
        }
        var esc = luaLines.replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + esc + "' > ~/.config/hypr/monitors.lua && touch ~/.config/hypr/hyprland.lua"]);
        win.dirty = false;
    }

    onOpenChanged: {
        if (open) {
            activeDropdown = "";
            monProc.running = true;
        } else {
            activeDropdown = "";
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(1060, parent.width - 80)
        height: Math.min(680, parent.height - 80)
        radius: Theme.radiusCard
        color: Theme.bgSurface
        border.color: Theme.accent
        border.width: 3

        transformOrigin: Item.Center
        scale: win.open ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation {
                duration: win.open ? 220 : 160
                easing.type: win.open ? Easing.OutQuint : Easing.InQuad
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: { win.activeDropdown = ""; appsTab.closeMenus(); }
        }

        RowLayout {
            anchors { fill: parent; margins: 3 }
            spacing: 0

            // --- ЛЕВЫЙ САЙДБАР ---
            Rectangle {
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                Layout.preferredWidth: 195
                Layout.fillHeight: true
                color: Theme.bgFrame
                radius: Theme.radiusCard - 3

                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 18
                    color: Theme.bgFrame
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: "Настройки"
                        font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.fg
                        Layout.leftMargin: 8; Layout.bottomMargin: 8; Layout.topMargin: 4
                    }

                    Repeater {
                        model: [{ icon: "\uf108", title: "Мониторы" }, { icon: "\uf00a", title: "Приложения" }, { icon: "\uf53f", title: "Внешний вид" }]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Theme.r(12)
                            color: win.currentTab === index ? Theme.accent : (tabM.containsMouse ? Theme.bgPillHover : "transparent")

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                Text {
                                    text: modelData.icon
                                    font.family: Theme.iconFont; font.pixelSize: 14
                                    color: win.currentTab === index ? Theme.accentOn : Theme.fgMuted
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.family: Theme.fontFamily; font.pixelSize: 13
                                    font.weight: win.currentTab === index ? Font.Bold : Font.Bold
                                    color: win.currentTab === index ? Theme.accentOn : Theme.fg
                                }
                            }

                            MouseArea {
                                cursorShape: Qt.PointingHandCursor
                                id: tabM
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: win.currentTab = index
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.borderSubtle }

            // --- ПРАВАЯ ЧАСТЬ ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Заголовок + кнопка закрытия
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: win.currentTab === 0 ? "Мониторы" : (win.currentTab === 1 ? "Приложения" : "Внешний вид")
                            font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Bold; color: Theme.fg
                        }
                        Rectangle {
                            scale: closeS.pressed ? 0.94 : (closeS.containsMouse ? 1.04 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            implicitWidth: 30; implicitHeight: 30
                            radius: Theme.r(closeS.containsMouse ? 8 : 15)
                            color: closeS.containsMouse ? Theme.bgPillHover : Theme.bgPill
                            Text { anchors.centerIn: parent; text: "\uf00d"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.fgMuted }
                            MouseArea { id: closeS; anchors.fill: parent; hoverEnabled: true; onClicked: win.open = false }
                        }
                    }

                    AppsTab {
                        id: appsTab
                        visible: win.currentTab === 1
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    AppearanceTab {
                        visible: win.currentTab === 2
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    // Уведомление о несохранённых настройках
                    Rectangle {
                        visible: win.currentTab === 0 && win.dirty
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: Theme.r(12)
                        color: Theme.accentWarm

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                            Text { text: "\uf071"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.accentOn }
                            Text {
                                Layout.fillWidth: true
                                text: "Настройки не сохранены — нажмите «Применить»"
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.accentOn
                            }
                        }
                    }

                    // Область перетаскивания мониторов
                    Rectangle {
                        visible: win.currentTab === 0
                        Layout.fillWidth: true
                        implicitHeight: 165
                        radius: Theme.r(16)
                        color: Theme.bgFrame
                        border.color: Theme.borderSubtle
                        border.width: 1
                        clip: true

                        Text {
                            anchors { left: parent.left; top: parent.top; margins: 8 }
                            text: "Перетащите мониторы для расположения"
                            font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 10; color: Theme.fgMuted
                        }

                        Repeater {
                            model: win.monitors
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool isSel: win.selectedMonIdx === index
                                readonly property real uiScale: 0.045

                                x: 110 + modelData.x * uiScale
                                y: 38 + modelData.y * uiScale
                                width: Math.max(76, modelData.width * uiScale)
                                height: Math.max(48, modelData.height * uiScale)
                                radius: Theme.r(10)
                                color: isSel ? Theme.bgElevated : Theme.bgPill
                                border.color: isSel ? Theme.accentWarm : Theme.borderSubtle
                                border.width: 2

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.name
                                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.fg
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Math.round(modelData.x) + ", " + Math.round(modelData.y)
                                        font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 9; color: Theme.fgMuted
                                    }
                                }

                                MouseArea {
                                    cursorShape: Qt.PointingHandCursor
                                    anchors.fill: parent
                                    drag.target: parent
                                    drag.minimumX: 8
                                    drag.maximumX: parent.parent.width - parent.width - 8
                                    drag.minimumY: 24
                                    drag.maximumY: parent.parent.height - parent.height - 8
                                    onPressed: {
                                        win.selectedMonIdx = index;
                                        win.syncSelection(index);
                                        win.activeDropdown = "";
                                    }
                                    onReleased: {
                                        var list = win.monitors.slice();
                                        var nx = Math.round((parent.x - 110) / parent.uiScale / 10) * 10;
                                        var ny = Math.round((parent.y - 38) / parent.uiScale / 10) * 10;
                                        if (nx !== list[index].x || ny !== list[index].y) win.dirty = true;
                                        list[index].x = nx;
                                        list[index].y = ny;
                                        win.monitors = list;
                                    }
                                }
                            }
                        }
                    }

                    // Строки с выпадающими списками в стиле GNOME
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: win.currentTab === 0 && win.monitors.length > 0

                        component DropRow: Rectangle {
                            scale: dm.pressed ? 0.94 : (dm.containsMouse ? 1.04 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            property string label: ""
                            property string valueText: ""
                            property bool isOpen: false
                            signal toggled()

                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: Theme.r(14)
                            color: Theme.bgPill

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10
                                Text {
                                    Layout.fillWidth: true
                                    text: label
                                    font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: Theme.fg
                                }
                                Rectangle {
                                    scale: dm.pressed ? 0.93 : (dm.containsMouse ? 1.05 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    implicitWidth: valRow.implicitWidth + 22
                                    implicitHeight: 30
                                    radius: Theme.r(10)
                                    color: dm.containsMouse || isOpen ? Theme.bgPillHover : Theme.bgFrame
                                    border.color: isOpen ? Theme.accent : Theme.borderSubtle
                                    border.width: 1

                                    RowLayout {
                                        id: valRow
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text { text: valueText; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.fg }
                                        Text { text: isOpen ? "\uf077" : "\uf078"; font.family: Theme.iconFont; font.pixelSize: 10; color: Theme.fgMuted }
                                    }

                                    MouseArea {
                                        cursorShape: Qt.PointingHandCursor
                                        id: dm
                                        anchors.fill: parent; hoverEnabled: true
                                        onClicked: toggled()
                                    }
                                }
                            }
                        }

                        DropRow {
                            id: resRow
                            label: "Разрешение"
                            valueText: win.selRes.replace("x", " × ")
                            isOpen: win.activeDropdown === "res"
                            onToggled: win.activeDropdown = (win.activeDropdown === "res" ? "" : "res")
                        }

                        DropRow {
                            id: hzRow
                            label: "Частота обновления"
                            valueText: win.selHz + " Hz"
                            isOpen: win.activeDropdown === "hz"
                            onToggled: win.activeDropdown = (win.activeDropdown === "hz" ? "" : "hz")
                        }

                        DropRow {
                            id: scaleRow
                            label: "Масштаб"
                            valueText: win.selScale + "x"
                            isOpen: win.activeDropdown === "scale"
                            onToggled: win.activeDropdown = (win.activeDropdown === "scale" ? "" : "scale")
                        }
                    }

                    Item { visible: win.currentTab === 0; Layout.fillHeight: true }

                    // Кнопка Применить
                    RowLayout {
                        visible: win.currentTab === 0
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            scale: appBtnM.pressed ? 0.94 : (appBtnM.containsMouse ? 1.04 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            implicitWidth: 140; implicitHeight: 38
                            radius: Theme.r(appBtnM.containsMouse ? 10 : 19)
                            color: appBtnM.containsMouse ? Theme.accentWarm : Theme.accent
                            Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                            Text {
                                anchors.centerIn: parent
                                text: "Применить"
                                font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: Theme.accentOn
                            }
                            MouseArea {
                                cursorShape: Qt.PointingHandCursor
                                id: appBtnM
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    win.applyMonitors();
                                    win.open = false;
                                }
                            }
                        }
                    }
                }

                // Всплывающий выпадающий список поверх правой панели
                Rectangle {
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    visible: win.activeDropdown !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: 26
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 64
                    width: 190
                    height: Math.min(220, dropList.contentHeight + 12)
                    radius: Theme.r(14)
                    color: Theme.bgElevated
                    border.color: Theme.accent
                    border.width: 2
                    z: 10

                    MouseArea { anchors.fill: parent }

                    ListView {
                        id: dropList
                        anchors.fill: parent; anchors.margins: 6
                        clip: true
                        spacing: 4
                        model: {
                            if (win.activeDropdown === "res") return win.monitors[win.selectedMonIdx]?.resList ?? [];
                            if (win.activeDropdown === "hz") return win.monitors[win.selectedMonIdx]?.resMap[win.selRes] ?? ["60"];
                            if (win.activeDropdown === "scale") return ["2", "1.5", "1.25", "1"];
                            return [];
                        }

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isCur: {
                                if (win.activeDropdown === "res") return win.selRes === modelData;
                                if (win.activeDropdown === "hz") return win.selHz === modelData;
                                if (win.activeDropdown === "scale") return Math.abs(win.selScale - parseFloat(modelData)) < 0.01;
                                return false;
                            }
                            width: dropList.width
                            implicitHeight: 32
                            radius: Theme.r(8)
                            color: isCur ? Theme.accentWarm : (dItemM.containsMouse ? Theme.bgPillHover : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (win.activeDropdown === "res") return String(modelData).replace("x", " × ");
                                    if (win.activeDropdown === "hz") return modelData + " Hz";
                                    return modelData + "x";
                                }
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: isCur ? Font.Bold : Font.Bold
                                color: isCur ? Theme.accentOn : Theme.fg
                            }

                            MouseArea {
                                cursorShape: Qt.PointingHandCursor
                                id: dItemM
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (win.activeDropdown === "res") {
                                        if (win.selRes !== modelData) win.dirty = true;
                                        win.selRes = modelData;
                                        var hzs = win.monitors[win.selectedMonIdx].resMap[modelData] || ["60"];
                                        if (hzs.indexOf(win.selHz) === -1) win.selHz = hzs[0];
                                    } else if (win.activeDropdown === "hz") {
                                        if (win.selHz !== modelData) win.dirty = true;
                                        win.selHz = modelData;
                                    } else if (win.activeDropdown === "scale") {
                                        var sc = parseFloat(modelData);
                                        if (Math.abs(win.selScale - sc) > 0.01) win.dirty = true;
                                        win.selScale = sc;
                                    }
                                    win.activeDropdown = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
