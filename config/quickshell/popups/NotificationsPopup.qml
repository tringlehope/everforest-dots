import QtQuick
import QtQuick.Layouts
import Quickshell
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

    visible: card.scale > 0.05 || open
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
        width: 530
        height: contentRow.implicitHeight + 28
        radius: Theme.radiusCard
        color: Theme.bgSurface
        border.color: Theme.accent
        border.width: 3

        transformOrigin: Item.TopRight
        scale: win.open ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation {
                duration: win.open ? 260 : 160
                easing.type: win.open ? Easing.OutQuint : Easing.InQuad
            }
        }

        MouseArea { anchors.fill: parent }

        RowLayout {
            id: contentRow
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Не беспокоить"
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.fg
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        implicitWidth: 42; implicitHeight: 22
                        radius: Theme.radiusPill
                        color: win.dnd ? Theme.accent : Theme.bgPill
                        Rectangle {
                            width: 16; height: 16; radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            x: win.dnd ? 23 : 3
                            color: win.dnd ? Theme.accentOn : Theme.fgMuted
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                        }
                        MouseArea { cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: win.dnd = !win.dnd }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: notifServer.trackedNotifications
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        implicitHeight: 50
                        radius: 14
                        color: Theme.bgPill

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 2
                            Text {
                                text: modelData.appName + (modelData.summary ? " — " + modelData.summary : "")
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.accentWarm
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.body || ""
                                font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.fg
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: clearMouse.containsMouse ? 10 : 17
                    color: clearMouse.containsMouse ? Theme.bgPillHover : Theme.bgPill
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    Text {
                        anchors.centerIn: parent
                        text: "Очистить"
                        font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.fg
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

            ColumnLayout {
                Layout.preferredWidth: 235
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "\uf053"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.fgMuted
                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent; anchors.margins: -6
                            onClicked: win.viewDate = new Date(win.viewDate.getFullYear(), win.viewDate.getMonth() - 1, 1)
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: win.ruMonths[win.viewDate.getMonth()] + " " + win.viewDate.getFullYear()
                        font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Theme.fg
                    }
                    Text {
                        text: "\uf054"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.fgMuted
                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent; anchors.margins: -6
                            onClicked: win.viewDate = new Date(win.viewDate.getFullYear(), win.viewDate.getMonth() + 1, 1)
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
                        delegate: Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.fgMuted
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
                            implicitHeight: 28
                            radius: Theme.radiusPill
                            color: isToday ? Theme.accentWarm : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData > 0 ? modelData : ""
                                font.family: Theme.fontFamily; font.pixelSize: 13
                                font.weight: isToday ? Font.Bold : Font.Normal
                                color: isToday ? Theme.accentOn : Theme.fg
                            }
                        }
                    }
                }
            }
        }
    }
}
