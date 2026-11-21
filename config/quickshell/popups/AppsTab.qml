import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../components"
import ".."

Item {
    id: root
    property int subTab: 0
    property bool showSystem: false
    property var appList: []
    property var autostartList: []
    property var searchResults: []
    property string installSource: "pacman"
    property bool sourceMenuOpen: false
    property bool searching: false

    // Встроенный терминал / логи
    property bool termMode: false
    property string termLog: ""
    property bool termRunning: false
    property bool isPasswordPrompt: {
        var low = termLog.slice(-120).toLowerCase();
        return low.indexOf("password") !== -1 || low.indexOf("пароль") !== -1;
    }

    // Контекстное меню и удаление
    property var ctxApp: null
    property string ctxSource: ""
    property string ctxPkg: ""
    property bool ctxOpen: false
    property real ctxX: 0
    property real ctxY: 0
    property bool confirmDeleteOpen: false

    readonly property string mgrPath: "/home/tringlehope/.config/quickshell/scripts/app_mgr.py"
    readonly property string ptyPath: "/home/tringlehope/.config/quickshell/scripts/pty_run.py"

    function refreshAll() {
        appsProc.running = false; appsProc.running = true;
        autoProc.running = false; autoProc.running = true;
    }

    function closeMenus() {
        ctxOpen = false;
        sourceMenuOpen = false;
    }

    function runSearch() {
        var q = pkgSearch.text.trim();
        if (!q) { searchResults = []; return; }
        searching = true;
        searchProc.command = ["python3", root.mgrPath, "search", root.installSource, q];
        searchProc.running = false;
        searchProc.running = true;
    }

    function runInTerm(cmdList) {
        termLog = "";
        termMode = true;
        termRunning = true;
        termProc.command = ["python3", root.ptyPath].concat(cmdList);
        termProc.running = false;
        termProc.running = true;
        termInput.forceActiveFocus();
    }

    Component.onCompleted: refreshAll()
    onShowSystemChanged: refreshAll()

    Timer {
        id: searchDebounce
        interval: 320
        onTriggered: root.runSearch()
    }

    Process {
        id: appsProc
        command: ["python3", root.mgrPath, "apps", root.showSystem ? "1" : "0"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.appList = JSON.parse(text); } catch (e) { root.appList = []; } }
        }
    }

    Process {
        id: autoProc
        command: ["python3", root.mgrPath, "autostart", root.showSystem ? "1" : "0"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.autostartList = JSON.parse(text); } catch (e) { root.autostartList = []; } }
        }
    }

    Process {
        id: infoProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    root.ctxSource = d.source || "Неизвестно";
                    root.ctxPkg = d.pkg || "";
                } catch (e) {
                    root.ctxSource = "Неизвестно";
                    root.ctxPkg = "";
                }
            }
        }
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                try { root.searchResults = JSON.parse(text); } catch (e) { root.searchResults = []; }
            }
        }
    }

    Process {
        id: termProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var txt = root.termLog;
                for (var i = 0; i < data.length; i++) {
                    var ch = data[i];
                    if (ch === "\r") {
                        var nl = txt.lastIndexOf("\n");
                        txt = (nl === -1) ? "" : txt.slice(0, nl + 1);
                    } else {
                        txt += ch;
                    }
                }
                if (txt.length > 12000) txt = txt.slice(-10000);
                root.termLog = txt;
                termScroll.contentY = Math.max(0, termScroll.contentHeight - termScroll.height);
            }
        }
        onExited: {
            root.termRunning = false;
            root.refreshAll();
            if (pkgSearch.text.trim()) root.runSearch();
        }
    }

    Process { id: toggleAutoProc; onExited: autoProc.running = true }

    MouseArea { anchors.fill: parent; onClicked: root.closeMenus() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                scale: btnMa_3.pressed ? 0.94 : (btnMa_3.containsMouse ? 1.04 : 1.0)
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 12
                color: Theme.bgFrame

                RowLayout {
                    anchors.fill: parent; anchors.margins: 3; spacing: 4
                    Repeater {
                        model: ["Список", "Автозапуск"]
                        delegate: Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: 9
                            color: root.subTab === index ? Theme.accentWarm : "transparent"
                            Text {
                                anchors.centerIn: parent; text: modelData
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                                color: root.subTab === index ? Theme.accentOn : Theme.fgMuted
                            }
                            MouseArea {
                    id: btnMa_3
                    hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                onClicked: {
                                    root.subTab = index;
                                    root.termMode = false;
                                    root.closeMenus();
                                    root.refreshAll();
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                visible: !root.termMode
                spacing: 6
                Text { text: "Системные"; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 11; color: Theme.fgMuted }
                Rectangle {
                    scale: btnMa_4.pressed ? 0.94 : (btnMa_4.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    implicitWidth: 38; implicitHeight: 22; radius: 11
                    color: root.showSystem ? Theme.accent : Theme.bgPill
                    Rectangle {
                        width: 16; height: 16; radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.showSystem ? 19 : 3
                        color: root.showSystem ? Theme.accentOn : Theme.fgMuted
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    }
                    MouseArea {
                        id: btnMa_4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        onClicked: { root.closeMenus(); root.showSystem = !root.showSystem; }
                    }
                }
            }
        }

        // --- 1. СПИСОК ПРИЛОЖЕНИЙ ---
        Item {
            visible: root.subTab === 0 && !root.termMode
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: installedList
                anchors { fill: parent; rightMargin: 10 }
                clip: true
                spacing: 6
                model: root.appList

                delegate: Rectangle {
                    required property var modelData
                    width: installedList.width
                    implicitHeight: 42
                    radius: 12
                    color: itemM.containsMouse ? Theme.bgPillHover : Theme.bgPill

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 12; spacing: 10
                        IconImage {
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                            implicitSize: 48
                            width: 28; height: 28
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Black; color: Theme.fg
                            elide: Text.ElideRight
                        }
                        Text { text: "ПКМ"; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 10; color: Theme.fgDim }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: itemM
                        anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) { root.closeMenus(); return; }
                            root.sourceMenuOpen = false;
                            root.ctxApp = modelData;
                            root.ctxSource = "Проверка...";
                            root.ctxPkg = "";
                            var pt = mapToItem(root, mouse.x, mouse.y);
                            root.ctxX = Math.max(0, Math.min(root.width - 210, pt.x));
                            root.ctxY = Math.max(40, Math.min(root.height - 95, pt.y));
                            root.ctxOpen = true;
                            infoProc.command = ["python3", root.mgrPath, "info", modelData.path, modelData.exec];
                            infoProc.running = false; infoProc.running = true;
                        }
                    }
                }
            }

            WaveScrollBar { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } target: installedList }
        }

        // --- 2. ТЕРМИНАЛ УДАЛЕНИЯ ---
        ColumnLayout {
            visible: root.termMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    scale: repM.pressed ? 0.94 : (repM.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Layout.fillWidth: true; implicitHeight: 34; radius: 10
                    color: repM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "\uf021"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.accent }
                        Text { text: "Обновить репы"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg }
                    }
                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: repM; anchors.fill: parent; hoverEnabled: true
                        onClicked: { root.closeMenus(); root.runInTerm(["sudo", "pacman", "-Sy"]); }
                    }
                }

                Rectangle {
                    scale: sysM.pressed ? 0.94 : (sysM.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Layout.fillWidth: true; implicitHeight: 34; radius: 10
                    color: sysM.containsMouse ? Theme.accentWarm : Theme.accent
                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "\uf019"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.accentOn }
                        Text { text: "Обновить систему"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.accentOn }
                    }
                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: sysM; anchors.fill: parent; hoverEnabled: true
                        onClicked: { root.closeMenus(); root.runInTerm(["sudo", "pacman", "-Syu"]); }
                    }
                }
            }

            // Источник + Поиск + Кнопка Найти
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    scale: btnMa_5.pressed ? 0.94 : (btnMa_5.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    implicitWidth: 105; implicitHeight: 36; radius: 10
                    color: Theme.bgFrame
                    border.color: root.sourceMenuOpen ? Theme.accent : Theme.borderSubtle
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        Text {
                            Layout.fillWidth: true
                            text: root.installSource === "pacman" ? "Pacman" : (root.installSource === "aur" ? "AUR" : "Flatpak")
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg
                        }
                        Text { text: root.sourceMenuOpen ? "\uf077" : "\uf078"; font.family: Theme.iconFont; font.pixelSize: 10; color: Theme.fgMuted }
                    }
                    MouseArea { hoverEnabled: true; id: btnMa_5; cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: root.sourceMenuOpen = !root.sourceMenuOpen }
                }

                Rectangle {
                    scale: btnMa_6.pressed ? 0.94 : (btnMa_6.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Layout.fillWidth: true; implicitHeight: 36; radius: 10
                    color: Theme.bgPill
                    border.color: pkgSearch.activeFocus ? Theme.accent : "transparent"
                    border.width: 1

                    MouseArea { hoverEnabled: true; id: btnMa_6; cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: { root.closeMenus(); pkgSearch.forceActiveFocus(); } }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text { text: "\uf002"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.fgMuted }
                        TextInput {
                            id: pkgSearch
                            Layout.fillWidth: true
                            font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 12; color: Theme.fg
                            selectByMouse: true
                            onTextChanged: {
                                root.termMode = false;
                                searchDebounce.restart();
                            }
                            Keys.onReturnPressed: { root.closeMenus(); root.termMode = false; root.runSearch(); }
                            Text {
                                visible: !parent.text
                                text: "Поиск пакетов..."
                                font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 12; color: Theme.fgMuted
                            }
                        }
                    }
                }

                Rectangle {
                    scale: findBtnM.pressed ? 0.94 : (findBtnM.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    implicitWidth: 74; implicitHeight: 36; radius: 10
                    color: findBtnM.containsMouse ? Theme.accentWarm : Theme.bgPill
                    Text {
                        anchors.centerIn: parent; text: "Найти"
                        font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                        color: findBtnM.containsMouse ? Theme.accentOn : Theme.fg
                    }
                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: findBtnM; anchors.fill: parent; hoverEnabled: true
                        onClicked: { root.closeMenus(); root.termMode = false; root.runSearch(); }
                    }
                }
            }

            Text {
                visible: root.searching && !root.termMode
                Layout.alignment: Qt.AlignHCenter
                text: "Поиск..."
                font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 12; color: Theme.accentWarm
            }

            // Список найденных пакетов
            Item {
                visible: !root.termMode
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: pkgResultsList
                    anchors { fill: parent; rightMargin: 10 }
                    clip: true
                    spacing: 6
                    model: root.searchResults

                    delegate: Rectangle {
                        required property var modelData
                        width: pkgResultsList.width
                        implicitHeight: 54
                        radius: 12
                        color: Theme.bgPill

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10

                            IconImage {
                                source: Quickshell.iconPath(modelData.pkg, "package-x-generic")
                                implicitSize: 18
                                width: 18; height: 18
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                RowLayout {
                                    spacing: 6
                                    Text { text: modelData.pkg; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg }
                                    Text { text: modelData.repo + " • " + modelData.ver; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 10; color: Theme.accentWarm }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.desc
                                    font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 11; color: Theme.fgMuted
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                scale: instM.pressed ? 0.94 : (instM.containsMouse ? 1.04 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                                Behavior on color { ColorAnimation { duration: 140 } }
                                implicitWidth: 92; implicitHeight: 32; radius: 9
                                color: modelData.installed ? Theme.bgFrame : (instM.containsMouse ? Theme.accentWarm : Theme.accent)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.installed ? "Стоит" : "Установить"
                                    font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black
                                    color: modelData.installed ? Theme.fgMuted : Theme.accentOn
                                }
                                MouseArea {
                                    cursorShape: Qt.PointingHandCursor
                                    id: instM; anchors.fill: parent; hoverEnabled: true
                                    enabled: !modelData.installed
                                    onClicked: {
                                        if (root.installSource === "pacman") root.runInTerm(["sudo", "pacman", "-S", modelData.pkg]);
                                        else if (root.installSource === "aur") root.runInTerm(["yay", "-S", modelData.pkg]);
                                        else root.runInTerm(["flatpak", "install", modelData.pkg]);
                                    }
                                }
                            }
                        }
                    }
                }

                WaveScrollBar { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } target: pkgResultsList }
            }

            // Встроенное окно логов терминала (ввод пароля, y, Enter)
            Rectangle {
                scale: backM.pressed ? 0.94 : (backM.containsMouse ? 1.04 : 1.0)
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                visible: root.termMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Theme.bgFrame
                border.color: Theme.borderSubtle
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            implicitWidth: 82; implicitHeight: 26; radius: 8
                            color: backM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                            Text { anchors.centerIn: parent; text: "← Назад"; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 11; color: Theme.fg }
                            MouseArea { cursorShape: Qt.PointingHandCursor; id: backM; anchors.fill: parent; hoverEnabled: true; onClicked: { root.termMode = false; root.refreshAll(); if (pkgSearch.text.trim()) root.runSearch(); } }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.termRunning ? "Выполняется..." : "Завершено"
                            font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black
                            color: root.termRunning ? Theme.accentWarm : Theme.accent
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Flickable {
                        id: termScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: logText.implicitHeight

                        Text {
                            id: logText
                            width: parent.width
                            text: root.termLog
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            color: Theme.fg
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 34; radius: 9
                        color: Theme.bgSurface
                        border.color: termInput.activeFocus ? Theme.accent : Theme.borderSubtle
                        border.width: 1

                        MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: termInput.forceActiveFocus() }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                            Text { text: ">"; font.family: Theme.monoFont; font.pixelSize: 12; color: Theme.accent }
                            TextInput {
                                id: termInput
                                Layout.fillWidth: true
                                echoMode: root.isPasswordPrompt ? TextInput.Password : TextInput.Normal
                                font.family: Theme.monoFont; font.pixelSize: 12; color: Theme.fg
                                Keys.onReturnPressed: {
                                    var val = text.replace(/'/g, "'\\''");
                                    Quickshell.execDetached(["sh", "-c", "[ -p /tmp/qs-term-in ] && printf '%s\\n' '" + val + "' > /tmp/qs-term-in"]);
                                    if (!root.isPasswordPrompt) root.termLog += text + "\n";
                                    text = "";
                                }
                                Text {
                                    visible: !parent.text
                                    text: root.isPasswordPrompt ? "Введите пароль и Enter..." : "Ввод (y / Enter)..."
                                    font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 11; color: Theme.fgMuted
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- 2. АВТОЗАПУСК ---
        Item {
            visible: root.subTab === 1 && !root.termMode
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: autoListView
                anchors { fill: parent; rightMargin: 10 }
                clip: true
                spacing: 6
                model: root.autostartList

                delegate: Rectangle {
                    required property var modelData
                    width: autoListView.width
                    implicitHeight: 42
                    radius: 12
                    color: Theme.bgPill

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 12; spacing: 10
                        IconImage {
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                            implicitSize: 48
                            width: 28; height: 28
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Black; color: Theme.fg
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            scale: btnMa_7.pressed ? 0.94 : (btnMa_7.containsMouse ? 1.04 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            implicitWidth: 40; implicitHeight: 22; radius: 11
                            color: modelData.autostart ? Theme.accent : Theme.bgFrame
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                x: modelData.autostart ? 21 : 3
                                color: modelData.autostart ? Theme.accentOn : Theme.fgMuted
                            }
                            MouseArea {
                                id: btnMa_7
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                onClicked: {
                                    toggleAutoProc.command = ["python3", root.mgrPath, "toggle_autostart", modelData.exec];
                                    toggleAutoProc.running = false; toggleAutoProc.running = true;
                                }
                            }
                        }
                    }
                }
            }

            WaveScrollBar { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } target: autoListView }
        }
    }

    Rectangle {
        scale: sm.pressed ? 0.94 : (sm.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
        Behavior on color { ColorAnimation { duration: 140 } }
        visible: root.sourceMenuOpen
        x: 0; y: 128
        width: 105; height: 108
        radius: 12
        color: Theme.bgElevated
        border.color: Theme.accent; border.width: 2
        z: 20

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 4; spacing: 2
            Repeater {
                model: [{ id: "pacman", name: "Pacman" }, { id: "aur", name: "AUR" }, { id: "flatpak", name: "Flatpak" }]
                delegate: Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 8
                    color: root.installSource === modelData.id ? Theme.accentWarm : (sm.containsMouse ? Theme.bgPillHover : "transparent")
                    Text {
                        anchors.centerIn: parent; text: modelData.name
                        font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                        color: root.installSource === modelData.id ? Theme.accentOn : Theme.fg
                    }
                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: sm; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            root.installSource = modelData.id;
                            root.sourceMenuOpen = false;
                            if (pkgSearch.text.trim()) root.runSearch();
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        scale: delBtnM.pressed ? 0.94 : (delBtnM.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
        Behavior on color { ColorAnimation { duration: 140 } }
        visible: root.ctxOpen
        x: root.ctxX; y: root.ctxY
        width: 200; height: 84
        radius: 14
        color: Theme.bgElevated
        border.color: Theme.accent; border.width: 2
        z: 30

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 6
            Text {
                Layout.fillWidth: true
                text: "Источник: " + root.ctxSource + (root.ctxPkg ? " (" + root.ctxPkg + ")" : "")
                font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 11; color: Theme.fgMuted
                elide: Text.ElideRight
            }
            Rectangle {
                scale: delBtnM.pressed ? 0.93 : (delBtnM.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                Layout.fillWidth: true; implicitHeight: 34; radius: 10
                color: delBtnM.containsMouse ? Theme.danger : Theme.bgPill
                enabled: root.ctxPkg !== ""
                Text {
                    anchors.centerIn: parent
                    text: root.ctxPkg !== "" ? "Удалить" : "Нельзя удалить"
                    font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                    color: delBtnM.containsMouse ? Theme.accentOn : Theme.danger
                }
                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: delBtnM; anchors.fill: parent; hoverEnabled: true
                    onClicked: { root.ctxOpen = false; root.confirmDeleteOpen = true; }
                }
            }
        }
    }

    Rectangle {
        scale: dAllM.pressed ? 0.94 : (dAllM.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
        Behavior on color { ColorAnimation { duration: 140 } }
        visible: root.confirmDeleteOpen
        anchors.fill: parent
        radius: 14
        color: Theme.bgFrame
        border.color: Theme.danger; border.width: 2
        z: 40

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 12

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Удалить " + (root.ctxApp?.name ?? "") + " (" + root.ctxPkg + ")?"
                font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Black; color: Theme.fg
                wrapMode: Text.Wrap
            }

            Rectangle {
                scale: dAllM.pressed ? 0.93 : (dAllM.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                Layout.fillWidth: true; implicitHeight: 38; radius: 12
                color: dAllM.containsMouse ? Theme.danger : Theme.bgPill
                Text { anchors.centerIn: parent; text: "Удалить целиком (вместе с данными)"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: dAllM.containsMouse ? Theme.accentOn : Theme.danger }
                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: dAllM; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        var p = root.ctxPkg;
                        var appDir = p.toLowerCase();
                        root.confirmDeleteOpen = false;
                        if (root.ctxSource === "Flatpak") {
                            root.runInTerm(["flatpak", "uninstall", "-y", "--delete-data", p]);
                        } else {
                            root.runInTerm(["sh", "-c", "sudo pacman -Rns " + p + " && rm -rf ~/.config/" + appDir + " ~/.local/share/" + appDir + " ~/.cache/" + appDir]);
                        }
                    }
                }
            }

            Rectangle {
                scale: dKeepM.pressed ? 0.93 : (dKeepM.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                Layout.fillWidth: true; implicitHeight: 38; radius: 12
                color: dKeepM.containsMouse ? Theme.accentWarm : Theme.bgPill
                Text { anchors.centerIn: parent; text: "Удалить, но оставить данные"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: dKeepM.containsMouse ? Theme.accentOn : Theme.fg }
                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: dKeepM; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        var p = root.ctxPkg;
                        root.confirmDeleteOpen = false;
                        if (root.ctxSource === "Flatpak") root.runInTerm(["flatpak", "uninstall", "-y", p]);
                        else root.runInTerm(["sudo", "pacman", "-Rns", p]);
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; implicitHeight: 34; radius: 12
                color: dCanM.containsMouse ? Theme.bgPillHover : Theme.bgSurface
                Text { anchors.centerIn: parent; text: "Отмена"; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 12; color: Theme.fgMuted }
                MouseArea { cursorShape: Qt.PointingHandCursor; id: dCanM; anchors.fill: parent; hoverEnabled: true; onClicked: root.confirmDeleteOpen = false }
            }
        }
    }
}
