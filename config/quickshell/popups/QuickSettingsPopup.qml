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
    property string page: "main" // "main" | "net" | "bt"
    property string netTab: "eth" // "eth" | "wifi"
    property bool recording: false
    property bool scrollingLayout: false
    property bool dockPinned: false
    property real brightness: 0.8

    // Состояние сети
    property bool ethConnected: false
    property bool wifiEnabled: false
    property bool hasWifiDev: false
    property string ethDevice: ""
    property string ethProfile: ""
    property string ethIp: ""
    property string ethGw: ""
    property string ethDns: ""
    property string ethSpeed: ""
    property var wifiList: []
    property string connectedWifiSsid: ""
    property string connectedWifiSignal: ""
    property string selectedWifiSsid: ""
    property string wifiStatusMsg: ""
    property bool wifiScanning: false
    property bool showPass: false

    signal openWallpapers()
    signal openSettings()
    signal startCapture()
    signal openPowerMenu()

    visible: card.scale > 0.05 || open
    exclusiveZone: -1
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.keyboardFocus: (win.open && win.page === "net" && win.selectedWifiSsid !== "")
                                 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function refreshNetwork() {
        netStateProc.running = true
    }

    function refreshWifi() {
        win.wifiScanning = true
        wifiScanProc.running = true
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "hyprctl getoption general:layout -j | python3 -c \"import sys,json; print(json.load(sys.stdin).get('str','dwindle'))\""]
        stdout: StdioCollector {
            onStreamFinished: win.scrollingLayout = (text.trim() === "scrolling")
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

    Process {
        id: netStateProc
        command: ["sh", "-c", "python3 - << 'PY'\nimport subprocess, json\ndef run(cmd):\n    try: return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()\n    except: return ''\nwifi = run(['env', 'LC_ALL=C', 'nmcli', 'radio', 'wifi']) == 'enabled'\ndevs = run(['env', 'LC_ALL=C', 'nmcli', '-t', '-f', 'DEVICE,TYPE,STATE,CONNECTION', 'dev'])\neth_dev, eth_state, eth_con = '', '', ''\nfor ln in devs.splitlines():\n    p = ln.split(':')\n    if len(p) >= 4 and p[1] == 'ethernet':\n        eth_dev, eth_state, eth_con = p[0], p[2], p[3]\n        break\neth_on = eth_state.startswith('connected')\nip, gw, dns, spd = '', '', '', ''\nif eth_dev and eth_on:\n    det = run(['env', 'LC_ALL=C', 'nmcli', '-t', '-f', 'IP4.ADDRESS,IP4.GATEWAY,IP4.DNS', 'dev', 'show', eth_dev])\n    for ln in det.splitlines():\n        if ln.startswith('IP4.ADDRESS') and not ip: ip = ln.split(':', 1)[1]\n        elif ln.startswith('IP4.GATEWAY') and not gw: gw = ln.split(':', 1)[1]\n        elif ln.startswith('IP4.DNS') and not dns: dns = ln.split(':', 1)[1]\n    try:\n        with open(f'/sys/class/net/{eth_dev}/speed') as f:\n            s = f.read().strip()\n            if s.isdigit() and int(s) > 0: spd = s + ' Мбит/с'\n    except: pass\nprint(json.dumps({'wifi': wifi, 'hasWifi': has_wifi, 'ethOn': eth_on, 'ethDev': eth_dev, 'ethCon': eth_con, 'ip': ip, 'gw': gw, 'dns': dns, 'spd': spd}))\nPY"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim());
                    win.wifiEnabled = !!d.wifi;
                    win.hasWifiDev = !!d.hasWifi;
                    win.ethConnected = !!d.ethOn;
                    win.ethDevice = d.ethDev || "";
                    win.ethProfile = d.ethCon || "";
                    win.ethIp = d.ip || "";
                    win.ethGw = d.gw || "";
                    win.ethDns = d.dns || "";
                    win.ethSpeed = d.spd || "";
                    if (win.page === "net" && win.wifiEnabled) {
                        wifiListProc.running = true;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: wifiScanProc
        command: ["sh", "-c", "nmcli dev wifi rescan 2>/dev/null; sleep 0.5"]
        onExited: wifiListProc.running = true
    }

    Process {
        id: wifiListProc
        command: ["sh", "-c", "python3 - << 'PY'\nimport subprocess, json\ntry:\n    out = subprocess.check_output(['env', 'LC_ALL=C', 'nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list'], stderr=subprocess.DEVNULL, text=True)\nexcept:\n    out = ''\nseen = set()\nitems = []\nconn_ssid = ''\nconn_sig = ''\nfor ln in out.splitlines():\n    p = ln.split(':')\n    if len(p) < 4: continue\n    in_use, ssid, sig, sec = p[0].strip(), p[1].strip(), p[2].strip(), p[3].strip()\n    if not ssid:\n        continue\n    if in_use == '*':\n        conn_ssid = ssid\n        conn_sig = sig\n        continue\n    if ssid in seen: continue\n    seen.add(ssid)\n    items.append({'ssid': ssid, 'sig': sig, 'sec': sec})\nprint(json.dumps({'connSsid': conn_ssid, 'connSig': conn_sig, 'items': items[:20]}))\nPY"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.wifiScanning = false;
                try {
                    var d = JSON.parse(text.trim());
                    win.connectedWifiSsid = d.connSsid || "";
                    win.connectedWifiSignal = d.connSig || "";
                    win.wifiList = d.items || [];
                } catch (e) {}
            }
        }
    }

    Process {
        id: wifiConnectProc
        onExited: (code) => {
            if (code === 0) {
                win.selectedWifiSsid = "";
                win.wifiStatusMsg = "";
                passInput.text = "";
                win.refreshNetwork();
            } else {
                win.wifiStatusMsg = "Не удалось подключиться (проверь пароль)";
            }
        }
    }

    Process {
        id: toggleNetProc
        onExited: win.refreshNetwork()
    }

    onOpenChanged: {
        if (open) {
            win.page = "main";
            win.selectedWifiSsid = "";
            win.wifiStatusMsg = "";
            brightRead.running = true;
            stateProc.running = true;
            win.refreshNetwork();
        } else {
            win.page = "main";
            win.selectedWifiSsid = "";
            win.wifiStatusMsg = "";
        }
    }

    MouseArea { anchors.fill: parent; onClicked: win.open = false }

    // Компактный переиспользуемый тумблер
    component TogglePill: Rectangle {
        property bool checked: false
        signal toggled()
        implicitWidth: 44
        implicitHeight: 24
        width: 44
        height: 24
        radius: 12
        color: checked ? Theme.accent : Theme.bgFrame
        border.color: checked ? Theme.accent : Theme.bgPillHover
        border.width: 2
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: 16; height: 16; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: checked ? parent.width - width - 4 : 4
            color: checked ? Theme.accentOn : Theme.fgDim
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

    Rectangle {
        id: card
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.topBarHeight + 8
        anchors.rightMargin: Theme.frameThickness + 8
        width: 344
        height: (win.page === "main" ? mainCol.implicitHeight : (win.page === "net" ? netCol.implicitHeight : btCol.implicitHeight)) + 28
        radius: Theme.radiusCard
        color: Theme.bgSurface
        border.color: Theme.accent
        border.width: 3

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

        transformOrigin: Item.TopRight
        scale: win.open ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation {
                duration: win.open ? 260 : 160
                easing.type: win.open ? Easing.OutQuint : Easing.InQuad
            }
        }

        MouseArea { anchors.fill: parent }

        // ==================== СТРАНИЦА 1: ГЛАВНОЕ МЕНЮ ====================
        ColumnLayout {
            id: mainCol
            visible: win.page === "main"
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
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Text {
                        anchors.centerIn: parent
                        text: icon
                        font.family: Theme.iconFont; font.pixelSize: 14
                        color: active ? Theme.accentOn : Theme.fg
                    }
                    MouseArea { cursorShape: Qt.PointingHandCursor; id: m; anchors.fill: parent; z: 10; hoverEnabled: true; onClicked: parent.clicked() }
                }

                ActionBtn {
                    icon: "\uf03d"
                    active: win.recording
                    onClicked: {
                        if (!win.recording) {
                            win.open = false;
                            win.startCapture();
                        }
                    }
                }
                ActionBtn {
                    icon: "\uf011"
                    onClicked: {
                        win.open = false;
                        win.openPowerMenu();
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 14
                color: Theme.bgPill

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 10

                    Text { text: "\uf185"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.accentWarm }
                    WavySlider {
                        Layout.fillWidth: true
                        value: win.brightness
                        activeColor: Theme.accentWarm
                        onMoved: v => {
                            win.brightness = v;
                            Quickshell.execDetached(["brightnessctl", "set", Math.round(v * 100) + "%"]);
                        }
                    }
                    Text { text: Math.round(win.brightness * 100) + "%"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fg }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                // СЕТЬ (с круглой кнопкой-стрелкой)
                Rectangle {
                    readonly property bool netActive: win.ethConnected || win.connectedWifiSsid !== ""
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: netM.containsMouse ? 10 : 21
                    color: netActive ? Theme.accent : Theme.bgPill
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.rightMargin: 6
                        spacing: 4

                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; spacing: 6
                                Text { text: "\uf0e8"; font.family: Theme.iconFont; font.pixelSize: 13; color: (win.ethConnected || win.connectedWifiSsid !== "") ? Theme.accentOn : Theme.fg }
                                Text { Layout.fillWidth: true; text: "Сеть"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: (win.ethConnected || win.connectedWifiSsid !== "") ? Theme.accentOn : Theme.fg }
                            }
                            MouseArea {
                                id: netM
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    win.page = "net";
                                    win.refreshNetwork();
                                }
                            }
                        }

                        // Круглая кнопка-стрелка
                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: netArrowM.containsMouse
                                   ? ((win.ethConnected || win.connectedWifiSsid !== "") ? "#232a2e" : Theme.bgPillHover)
                                   : ((win.ethConnected || win.connectedWifiSsid !== "") ? "#2d353b" : Theme.bgFrame)
                            Text {
                                anchors.centerIn: parent
                                text: "\uf054"
                                font.family: Theme.iconFont; font.pixelSize: 10
                                color: Theme.fg
                            }
                            MouseArea {
                                id: netArrowM
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    win.page = "net";
                                    win.refreshNetwork();
                                }
                            }
                        }
                    }
                }

                // BLUETOOTH (с круглой кнопкой-стрелкой)
                Rectangle {
                    id: btPill
                    readonly property bool btOn: Bluetooth.defaultAdapter?.enabled ?? false
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: btM.containsMouse ? 10 : 21
                    color: btOn ? Theme.accent : Theme.bgPill
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.rightMargin: 6
                        spacing: 4

                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; spacing: 6
                                Text { text: "\uf293"; font.family: Theme.iconFont; font.pixelSize: 13; color: btPill.btOn ? Theme.accentOn : Theme.fg }
                                Text { Layout.fillWidth: true; text: "Bluetooth"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: btPill.btOn ? Theme.accentOn : Theme.fg }
                            }
                            MouseArea {
                                id: btM
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: btArrowM.containsMouse
                                   ? (btPill.btOn ? "#232a2e" : Theme.bgPillHover)
                                   : (btPill.btOn ? "#2d353b" : Theme.bgFrame)
                            Text {
                                anchors.centerIn: parent
                                text: "\uf054"
                                font.family: Theme.iconFont; font.pixelSize: 10
                                color: Theme.fg
                            }
                            MouseArea {
                                id: btArrowM
                                cursorShape: Qt.PointingHandCursor
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.page = "bt"
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
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "\uf009"; font.family: Theme.iconFont; font.pixelSize: 12; color: win.scrollingLayout ? Theme.accentOn : Theme.fg }
                        Text {
                            text: win.scrollingLayout ? "Scrolling" : "Dwindle"
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                            color: win.scrollingLayout ? Theme.accentOn : Theme.fg
                        }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
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
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "\uf03e"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.accentWarm }
                        Text { text: "Обои"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: wallM
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            win.open = false;
                            win.openWallpapers();
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: pinM.containsMouse ? 10 : 20
                    color: win.dockPinned ? Theme.accent : (pinM.containsMouse ? Theme.bgPillHover : Theme.bgPill)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: "\uf08d"; font.family: Theme.iconFont; font.pixelSize: 12; color: win.dockPinned ? Theme.accentOn : Theme.fg }
                        Text {
                            text: win.dockPinned ? "Док: Закреплён" : "Закрепить док"
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                            color: win.dockPinned ? Theme.accentOn : Theme.fg
                        }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: pinM
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: win.dockPinned = !win.dockPinned
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: setM.containsMouse ? 10 : 20
                    color: setM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                    RowLayout {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "\uf013"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.accentWarm }
                        Text { text: "Настройки"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: setM
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            win.open = false;
                            win.openSettings();
                        }
                    }
                }
            }
        }

        // ==================== СТРАНИЦА 2: НАСТРОЙКИ СЕТИ ====================
        ColumnLayout {
            id: netCol
            visible: win.page === "net"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            // Шапка с кнопкой «Назад»
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: netBackM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Text { anchors.centerIn: parent; text: "\uf053"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.fg }
                    MouseArea {
                        id: netBackM
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.selectedWifiSsid = "";
                            win.wifiStatusMsg = "";
                            win.page = "main";
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Настройки сети"
                    font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Black
                    color: Theme.fg
                }
            }

            // 2 вкладки: Ethernet / Wi-Fi
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 12
                color: Theme.bgFrame

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 9
                        color: win.netTab === "eth" ? Theme.accent : (ethTabM.containsMouse ? Theme.bgPill : "transparent")
                        RowLayout {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "\uf0e8"; font.family: Theme.iconFont; font.pixelSize: 12; color: win.netTab === "eth" ? Theme.accentOn : Theme.fg }
                            Text { text: "Ethernet"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: win.netTab === "eth" ? Theme.accentOn : Theme.fg }
                        }
                        MouseArea {
                            id: ethTabM
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: win.netTab = "eth"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 9
                        color: win.netTab === "wifi" ? Theme.accent : (wifiTabM.containsMouse ? Theme.bgPill : "transparent")
                        RowLayout {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "\uf1eb"; font.family: Theme.iconFont; font.pixelSize: 12; color: win.netTab === "wifi" ? Theme.accentOn : Theme.fg }
                            Text { text: "Wi-Fi"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: win.netTab === "wifi" ? Theme.accentOn : Theme.fg }
                        }
                        MouseArea {
                            id: wifiTabM
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.netTab = "wifi";
                                if (win.wifiEnabled) wifiListProc.running = true;
                            }
                        }
                    }
                }
            }

            // -------- ВКЛАДКА 1: ETHERNET --------
            ColumnLayout {
                visible: win.netTab === "eth"
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 14
                    color: Theme.bgPill

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 8
                        Text { text: "\uf0e8"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.accent }
                        Text { Layout.fillWidth: true; text: win.ethConnected ? "Ethernet включён" : "Ethernet выключен"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg }
                        TogglePill {
                            checked: win.ethConnected
                            onToggled: {
                                if (win.ethDevice !== "") {
                                    var next = !win.ethConnected;
                                    win.ethConnected = next;
                                    toggleNetProc.command = ["nmcli", "dev", next ? "connect" : "disconnect", win.ethDevice];
                                    toggleNetProc.running = true;
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: win.ethConnected
                    Layout.fillWidth: true
                    implicitHeight: ethInfoCol.implicitHeight + 18
                    radius: 14
                    color: Theme.bgFrame

                    ColumnLayout {
                        id: ethInfoCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 4

                        Text {
                            text: "Характеристики"
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                            color: Theme.accent
                        }
                        Text {
                            visible: win.ethDevice !== ""
                            text: "Интерфейс: " + win.ethDevice + (win.ethProfile ? (" (" + win.ethProfile + ")") : "")
                            font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fg
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            visible: win.ethIp !== ""
                            text: "IP: " + win.ethIp
                            font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fg
                        }
                        Text {
                            visible: win.ethGw !== ""
                            text: "Шлюз: " + win.ethGw
                            font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fgDim
                        }
                        Text {
                            visible: win.ethDns !== ""
                            text: "DNS: " + win.ethDns
                            font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fgDim
                        }
                        Text {
                            visible: win.ethSpeed !== ""
                            text: "Скорость: " + win.ethSpeed
                            font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.accentWarm
                        }
                    }
                }

                Text {
                    visible: !win.ethConnected
                    text: "Проводное подключение отключено"
                    font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black
                    color: Theme.fgMuted
                }
            }

            // -------- ВКЛАДКА 2: WI-FI --------
            ColumnLayout {
                visible: win.netTab === "wifi"
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 14
                    color: Theme.bgPill

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 8
                        Text { text: "\uf1eb"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.accentWarm }
                        Text { Layout.fillWidth: true; text: win.wifiEnabled ? "Wi-Fi включён" : "Wi-Fi выключен"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg }
                        TogglePill {
                            checked: win.wifiEnabled
                            onToggled: {
                                var next = !win.wifiEnabled;
                                win.wifiEnabled = next;
                                toggleNetProc.command = ["nmcli", "radio", "wifi", next ? "on" : "off"];
                                toggleNetProc.running = true;
                            }
                        }
                    }
                }

                Text {
                    visible: !win.wifiEnabled
                    text: "Включите Wi-Fi для поиска сетей"
                    font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black
                    color: Theme.fgMuted
                }

                ColumnLayout {
                    visible: win.wifiEnabled
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Доступные сети"
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                            color: Theme.fgDim
                        }
                        Rectangle {
                            implicitWidth: refRow.implicitWidth + 16
                            implicitHeight: 28
                            radius: 10
                            color: refM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                            RowLayout {
                                id: refRow
                                anchors.centerIn: parent; spacing: 5
                                Text { text: "\uf021"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.accent }
                                Text { text: win.wifiScanning ? "Поиск..." : "Обновить"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fg }
                            }
                            MouseArea {
                                id: refM
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: win.refreshWifi()
                            }
                        }
                    }

                    Rectangle {
                        visible: win.connectedWifiSsid !== ""
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 12
                        color: Theme.accent

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                            Text { text: "\uf1eb"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.accentOn }
                            Text {
                                Layout.fillWidth: true
                                text: win.connectedWifiSsid + " (" + win.connectedWifiSignal + "%)"
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                                color: Theme.accentOn
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                implicitWidth: discTxt.implicitWidth + 12
                                implicitHeight: 24
                                radius: 8
                                color: discM.containsMouse ? "#232a2e" : "#2d353b"
                                Text { id: discTxt; anchors.centerIn: parent; text: "Отключить"; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.Black; color: Theme.fg }
                                MouseArea {
                                    id: discM
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        toggleNetProc.command = ["nmcli", "con", "down", "id", win.connectedWifiSsid];
                                        toggleNetProc.running = true;
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: win.wifiList.length === 0 && win.connectedWifiSsid === ""
                        text: !win.hasWifiDev ? "Wi-Fi адаптер не найден (виртуальная машина)" : (win.wifiScanning ? "Сканирование сетей..." : "Сети не найдены")
                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black
                        color: Theme.fgMuted
                    }

                    Flickable {
                        visible: win.wifiList.length > 0
                        Layout.fillWidth: true
                        implicitHeight: Math.min(165, wifiListCol.implicitHeight)
                        contentHeight: wifiListCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: wifiListCol
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: win.wifiList
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: 10
                                    color: (win.selectedWifiSsid === modelData.ssid) ? Theme.bgPillHover
                                           : (wM.containsMouse ? Theme.bgPill : Theme.bgFrame)
                                    border.color: (win.selectedWifiSsid === modelData.ssid) ? Theme.accent : "transparent"
                                    border.width: 2

                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                        Text { text: "\uf1eb"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.accentWarm }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.ssid
                                            elide: Text.ElideRight
                                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: Theme.fg
                                        }
                                        Text {
                                            visible: modelData.sec !== "" && modelData.sec !== "--"
                                            text: "\uf023"
                                            font.family: Theme.iconFont; font.pixelSize: 10; color: Theme.fgDim
                                        }
                                        Text {
                                            text: modelData.sig + "%"
                                            font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fgDim
                                        }
                                    }

                                    MouseArea {
                                        id: wM
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.wifiStatusMsg = "";
                                            if (modelData.sec === "" || modelData.sec === "--") {
                                                win.selectedWifiSsid = "";
                                                wifiConnectProc.command = ["nmcli", "dev", "wifi", "connect", modelData.ssid];
                                                wifiConnectProc.running = true;
                                            } else {
                                                win.selectedWifiSsid = modelData.ssid;
                                                passInput.forceActiveFocus();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: win.selectedWifiSsid !== ""
                        Layout.fillWidth: true
                        implicitHeight: passCol.implicitHeight + 16
                        radius: 12
                        color: Theme.bgFrame
                        border.color: Theme.accent
                        border.width: 2

                        ColumnLayout {
                            id: passCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: "Пароль для " + win.selectedWifiSsid
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black
                                color: Theme.accentWarm
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 8
                                color: Theme.bgPill

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 4
                                    TextInput {
                                        id: passInput
                                        Layout.fillWidth: true
                                        font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Black
                                        color: Theme.fg
                                        echoMode: win.showPass ? TextInput.Normal : TextInput.Password
                                        clip: true
                                        Keys.onReturnPressed: {
                                            wifiConnectProc.command = ["nmcli", "dev", "wifi", "connect", win.selectedWifiSsid, "password", passInput.text];
                                            wifiConnectProc.running = true;
                                        }
                                    }
                                    Text {
                                        text: win.showPass ? "\uf070" : "\uf06e"
                                        font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.fgDim
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: win.showPass = !win.showPass
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: win.wifiStatusMsg !== ""
                                Layout.fillWidth: true
                                text: win.wifiStatusMsg
                                wrapMode: Text.Wrap
                                font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.Black
                                color: Theme.danger
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 28; radius: 8
                                    color: cancelPassM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                                    Text { anchors.centerIn: parent; text: "Отмена"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.fg }
                                    MouseArea {
                                        id: cancelPassM
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { win.selectedWifiSsid = ""; win.wifiStatusMsg = ""; passInput.text = ""; }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 28; radius: 8
                                    color: Theme.accent
                                    Text { anchors.centerIn: parent; text: "Подключить"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Black; color: Theme.accentOn }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            wifiConnectProc.command = ["nmcli", "dev", "wifi", "connect", win.selectedWifiSsid, "password", passInput.text];
                                            wifiConnectProc.running = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==================== СТРАНИЦА 3: НАСТРОЙКИ BLUETOOTH ====================
        ColumnLayout {
            id: btCol
            visible: win.page === "bt"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: btBackM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Text { anchors.centerIn: parent; text: "\uf053"; font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.fg }
                    MouseArea {
                        id: btBackM
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: win.page = "main"
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Bluetooth"
                    font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Black
                    color: Theme.fg
                }
            }

            Text {
                visible: Bluetooth.devices.values.length === 0
                text: "Нет сопряжённых Bluetooth-устройств"
                font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 11; color: Theme.fgMuted
            }

            Repeater {
                model: Bluetooth.devices
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 12
                    color: modelData.connected ? Theme.accentWarm : Theme.bgPill

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.margins: 12
                        text: modelData.name || modelData.address
                        font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 12
                        color: modelData.connected ? Theme.accentOn : Theme.fg
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        onClicked: modelData.connected = !modelData.connected
                    }
                }
            }
        }
    }
}
