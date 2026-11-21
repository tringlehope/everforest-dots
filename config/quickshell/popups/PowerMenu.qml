import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import ".."

PanelWindow {
    id: pm

    property bool showing: false
    property bool updating: false
    property bool cancelled: false
    property string logText: ""

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: showing || bgRect.opacity > 0.01

    function open() {
        updating = false
        cancelled = false
        logText = ""
        showing = true
    }

    function close() {
        if (updating) {
            cancelUpdate()
        } else {
            showing = false
        }
    }

    function cancelUpdate() {
        cancelled = true
        killUpdProc.running = true
        updating = false
        showing = false
    }

    Process {
        id: updProc
        command: ["bash", "-c", "\"$HOME/.config/quickshell/scripts/update_and_poweroff.sh\" 2>&1"]
        stdout: SplitParser {
            onRead: data => {
                pm.logText += data + "\n"
                logFlick.contentY = Math.max(0, logTxt.implicitHeight - logFlick.height + 16)
            }
        }
        onExited: (code) => {
            pm.updating = false
            if (pm.cancelled) return
            if (code === 0) {
                Quickshell.execDetached(["systemctl", "poweroff"])
            } else {
                pm.logText += "\n[Ошибка] Код выхода: " + code + ". Выключение отменено.\n"
                logFlick.contentY = Math.max(0, logTxt.implicitHeight - logFlick.height + 16)
            }
        }
    }

    Process {
        id: killUpdProc
        command: ["pkill", "-TERM", "-f", "update_and_poweroff.sh"]
    }

    // Плавное проявление однотонного фона
    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Theme.bgFrame
        opacity: pm.showing ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: pm.showing ? 220 : 160
                easing.type: pm.showing ? Easing.OutQuint : Easing.InQuad
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: if (!pm.updating) pm.close()
        }
    }

    Item {
        id: animBox
        anchors.fill: parent
        focus: pm.showing
        Keys.onEscapePressed: pm.close()

        opacity: pm.showing ? 1.0 : 0.0
        scale: pm.showing ? 1.0 : 0.90
        Behavior on opacity {
            NumberAnimation {
                duration: pm.showing ? 240 : 150
                easing.type: pm.showing ? Easing.OutQuint : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: pm.showing ? 260 : 160
                easing.type: pm.showing ? Easing.OutQuint : Easing.InQuad
            }
        }

        // Крестик в правом верхнем углу без обводки
        Rectangle {
            visible: !pm.updating
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 28
            anchors.rightMargin: 28
            width: 44; height: 44
            radius: Theme.r(closeM.pressed ? 10 : (closeM.containsMouse ? 14 : 22))
            scale: closeM.pressed ? 0.94 : (closeM.containsMouse ? 1.06 : 1.0)
            color: closeM.containsMouse ? Theme.bgPillHover : Theme.bgSurface

            Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
            Behavior on scale  { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
            Behavior on color  { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.Bold
                color: Theme.danger
            }

            MouseArea {
                id: closeM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pm.close()
            }
        }

        // 5 Material You кнопок по центру
        RowLayout {
            visible: !pm.updating && pm.logText === ""
            anchors.centerIn: parent
            spacing: 16

            component PowerTile: Rectangle {
                property string icon: ""
                property string label: ""
                property color iconColor: Theme.fg
                signal triggered()

                implicitWidth: 152
                implicitHeight: 152
                Layout.preferredWidth: 152
                Layout.preferredHeight: 152
                radius: Theme.r(tileM.pressed ? 14 : (tileM.containsMouse ? 20 : 32))
                scale: tileM.pressed ? 0.95 : (tileM.containsMouse ? 1.05 : 1.0)
                color: tileM.containsMouse ? Theme.bgPillHover : Theme.bgSurface
                border.color: tileM.containsMouse ? Theme.accent : Theme.bgPill
                border.width: tileM.containsMouse ? 3 : 2

                Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on scale  { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on color  { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    width: parent.width - 22

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: icon
                        font.family: Theme.iconFont
                        font.pixelSize: 34
                        color: iconColor
                        scale: tileM.containsMouse ? 1.1 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: label
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.fg
                    }
                }

                MouseArea {
                    id: tileM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.triggered()
                }
            }

            PowerTile {
                icon: "\uf021"
                label: "Перезагрузка"
                iconColor: Theme.accentWarm
                onTriggered: { pm.showing = false; Quickshell.execDetached(["systemctl", "reboot"]) }
            }

            PowerTile {
                icon: "\uf011"
                label: "Выключение"
                iconColor: Theme.danger
                onTriggered: { pm.showing = false; Quickshell.execDetached(["systemctl", "poweroff"]) }
            }

            PowerTile {
                icon: "\uf019"
                label: "Обновить и выключить"
                iconColor: Theme.accent
                onTriggered: {
                    pm.updating = true
                    pm.cancelled = false
                    pm.logText = "Запуск автоматического обновления...\n"
                    updProc.running = true
                }
            }

            PowerTile {
                icon: "\uf186"
                label: "Спящий режим"
                iconColor: "#7fbbb3"
                onTriggered: { pm.showing = false; Quickshell.execDetached(["systemctl", "suspend"]) }
            }

            PowerTile {
                icon: "\uf08b"
                label: "Выход из сессии"
                iconColor: Theme.fgDim
                onTriggered: {
                    pm.showing = false
                    Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null || loginctl terminate-session \"$XDG_SESSION_ID\""])
                }
            }
        }

        // Окно логов при обновлении и выключении
        Rectangle {
            visible: pm.updating || pm.logText !== ""
            anchors.centerIn: parent
            width: Math.min(740, parent.width - 48)
            height: Math.min(460, parent.height - 48)
            radius: Theme.r(22)
            color: Theme.bgSurface
            border.color: Theme.accent
            border.width: 3

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: pm.updating ? "Обновление системы и конфигов..." : "Лог обновления"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: Theme.fg
                    }
                    Text {
                        visible: pm.updating
                        text: "Не выключайте компьютер"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Theme.accentWarm
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.r(14)
                    color: Theme.bgFrame

                    Flickable {
                        id: logFlick
                        anchors.fill: parent
                        anchors.margins: 12
                        contentWidth: width
                        contentHeight: logTxt.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Text {
                            id: logTxt
                            width: logFlick.width
                            text: pm.logText
                            wrapMode: Text.WrapAnywhere
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fg
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: cancelTxt.implicitWidth + 44
                    implicitHeight: 42
                    radius: Theme.r(cancelM.pressed ? 10 : (cancelM.containsMouse ? 14 : 21))
                    scale: cancelM.pressed ? 0.96 : (cancelM.containsMouse ? 1.03 : 1.0)
                    color: cancelM.containsMouse ? Theme.bgPillHover : Theme.bgPill

                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on scale  { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Behavior on color  { ColorAnimation { duration: 150 } }

                    Text {
                        id: cancelTxt
                        anchors.centerIn: parent
                        text: pm.updating ? "Отмена" : "Закрыть"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Theme.danger
                    }

                    MouseArea {
                        id: cancelM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pm.close()
                    }
                }
            }
        }
    }
}
