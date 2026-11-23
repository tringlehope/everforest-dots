import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components"
import Quickshell.Wayland
import Quickshell.Services.Notifications
import ".."

PanelWindow {
    id: win
    property bool open: false
    property bool dnd: false
    property date viewDate: new Date()

    readonly property var ruMonths: [
        "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
        "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ]

    visible: topTrans.y > -(card.height + 46) || open
    exclusiveZone: -1
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"

    NotificationServer {
        id: notifServer
        keepOnReload: true
        onNotification: notif => {
            if (!win.dnd) notif.tracked = true;
        }
    }

    MouseArea { anchors.fill: parent; onClicked: win.open = false }

    Rectangle {
        id: card
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.topBarHeight + 8
        anchors.rightMargin: Theme.frameThickness + 8
        width: 660
        height: Math.max(360, contentRow.implicitHeight + 32)
        radius: Theme.radiusCard
        color: Theme.bgSurface
        border.color: Theme.accent
        border.width: 3

        transformOrigin: Item.Top
        scale: win.open ? 1.0 : 0.94
        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
        transform: Translate {
            id: topTrans
            y: win.open ? 0 : -(card.height + 48)
            Behavior on y { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
        }

        MouseArea { anchors.fill: parent }

        RowLayout {
            id: contentRow
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 16 }
            spacing: 16

            // Левая колонка: Уведомления
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Не беспокоить"
                        font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Theme.fg
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        scale: btnMa_9.pressed ? 0.94 : (btnMa_9.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        implicitWidth: 44; implicitHeight: 24
                        radius: Theme.radiusPill
                        color: win.dnd ? Theme.accent : Theme.bgPill
                        Rectangle {
                            width: 18; height: 18; radius: Theme.r(9)
                            anchors.verticalCenter: parent.verticalCenter
                            x: win.dnd ? 23 : 3
                            color: win.dnd ? Theme.accentOn : Theme.fgMuted
                            Behavior on x { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                        }
                        MouseArea { hoverEnabled: true; id: btnMa_9; cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: win.dnd = !win.dnd }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        visible: notifServer.trackedNotifications.values.length === 0
                        anchors.centerIn: parent
                        text: "Нет новых уведомлений"
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold
                        color: Theme.fgDim
                    }

                    ListView {
        OverscrollStretch {}
                        anchors.fill: parent
                        clip: true
                        spacing: 8
                        model: notifServer.trackedNotifications
                        delegate: Rectangle {
                            id: notifCard
                            required property var modelData
                            width: ListView.view.width
                            implicitHeight: Math.max(56, notifCol.implicitHeight + 18)
                            radius: Theme.r(nM.containsMouse ? 10 : 14)
                            scale: nM.pressed ? 0.97 : (nM.containsMouse ? 1.02 : 1.0)
                            color: nM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on radius { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                            Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }

                            ColumnLayout {
                                id: notifCol
                                anchors.fill: parent; anchors.margins: 10; spacing: 3
                                Text {
                                    text: notifCard.modelData.appName + (notifCard.modelData.summary ? " — " + notifCard.modelData.summary : "")
                                    font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: Theme.accentWarm
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                    text: notifCard.modelData.body || ""
                                    font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12; color: Theme.fg
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: nM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notifCard.modelData.dismiss()
                            }
                        }
                    }
                }

                Rectangle {
                    scale: clearMouse.pressed ? 0.94 : (clearMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Theme.r(clearMouse.containsMouse ? 10 : 19)
                    color: clearMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                    Text {
                        anchors.centerIn: parent
                        text: "Очистить"
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: Theme.fg
                    }
                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: clearMouse
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            var list = notifServer.trackedNotifications.values.slice();
                            for (var i = 0; i < list.length; i++) list[i].dismiss();
                        }
                    }
                }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.borderSubtle }

            // Правая колонка: Крупный календарь
            ColumnLayout {
                Layout.preferredWidth: 290
                Layout.fillHeight: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        width: 30; height: 30; radius: Theme.r(prevM.containsMouse ? 10 : 15)
                        scale: prevM.pressed ? 0.9 : (prevM.containsMouse ? 1.08 : 1.0)
                        color: prevM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on radius { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                        Text { anchors.centerIn: parent; text: "\uf053"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.fg }
                        MouseArea {
                            id: prevM
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: win.viewDate = new Date(win.viewDate.getFullYear(), win.viewDate.getMonth() - 1, 1)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: win.ruMonths[win.viewDate.getMonth()] + " " + win.viewDate.getFullYear()
                        font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Bold; color: Theme.fg
                    }

                    Rectangle {
                        width: 30; height: 30; radius: Theme.r(nextM.containsMouse ? 10 : 15)
                        scale: nextM.pressed ? 0.9 : (nextM.containsMouse ? 1.08 : 1.0)
                        color: nextM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on radius { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                        Text { anchors.centerIn: parent; text: "\uf054"; font.family: Theme.iconFont; font.pixelSize: 12; color: Theme.fg }
                        MouseArea {
                            id: nextM
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: win.viewDate = new Date(win.viewDate.getFullYear(), win.viewDate.getMonth() + 1, 1)
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 5
                    columnSpacing: 5

                    Repeater {
                        model: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
                        delegate: Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.fgMuted
                        }
                    }

                    Repeater {
                        model: {
                            var y = win.viewDate.getFullYear();
                            var m = win.viewDate.getMonth();
                            var firstDay = (new Date(y, m, 1).getDay() + 6) % 7;
                            var daysInMonth = new Date(y, m + 1, 0).getDate();
                            var cells = [];
                            for (var i = 0; i < firstDay; i++) cells.push(0);
                            for (var d = 1; d <= daysInMonth; d++) cells.push(d);
                            return cells;
                        }
                        delegate: Rectangle {
                            readonly property date nowDate: new Date()
                            readonly property bool isToday: modelData > 0
                                && modelData === nowDate.getDate()
                                && win.viewDate.getMonth() === nowDate.getMonth()
                                && win.viewDate.getFullYear() === nowDate.getFullYear()
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Theme.radiusPill
                            scale: (modelData > 0 && dayM.containsMouse) ? 1.12 : 1.0
                            color: isToday ? Theme.accentWarm : ((modelData > 0 && dayM.containsMouse) ? Theme.bgPillHover : "transparent")
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData > 0 ? modelData : ""
                                font.family: Theme.fontFamily; font.pixelSize: 14
                                font.weight: Font.Bold
                                color: isToday ? Theme.accentOn : Theme.fg
                            }

                            MouseArea {
                                id: dayM
                                anchors.fill: parent
                                hoverEnabled: modelData > 0
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
