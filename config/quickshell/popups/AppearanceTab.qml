import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: root

    function setFrameMode(enabled) {
        Theme.showFrame = enabled;
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + (enabled ? "1" : "0") + "' > ~/.local/state/qs-frame-mode"]);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Text {
            text: "Стиль панели и краёв экрана"
            font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.fgMuted
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Вариант 1: Панель с рамками
            Rectangle {
                readonly property bool active: Theme.showFrame
                Layout.fillWidth: true
                implicitHeight: 190
                radius: 18
                color: active ? Theme.bgElevated : Theme.bgPill
                border.color: active ? Theme.accent : Theme.borderSubtle
                border.width: active ? 3 : 1

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: root.setFrameMode(true)
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 12

                    // Мини-превью экрана с рамкой
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: 12
                        color: Theme.bgSurface
                        border.color: Theme.bgFrame
                        border.width: 6

                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: 22
                            color: Theme.bgFrame
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                Rectangle { width: 34; height: 10; radius: 5; color: Theme.accentWarm }
                                Item { Layout.fillWidth: true }
                                Rectangle { width: 22; height: 10; radius: 5; color: Theme.bgPillHover }
                                Item { Layout.fillWidth: true }
                                Rectangle { width: 30; height: 10; radius: 5; color: Theme.bgPillHover }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Панель с рамками"
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: active ? Font.Bold : Font.Medium
                        color: active ? Theme.accent : Theme.fg
                    }
                }
            }

            // Вариант 2: Только пузыри
            Rectangle {
                readonly property bool active: !Theme.showFrame
                Layout.fillWidth: true
                implicitHeight: 190
                radius: 18
                color: active ? Theme.bgElevated : Theme.bgPill
                border.color: active ? Theme.accent : Theme.borderSubtle
                border.width: active ? 3 : 1

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: root.setFrameMode(false)
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 12

                    // Мини-превью без рамки — только парящие пузыри
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: 12
                        color: Theme.bgSurface
                        border.color: Theme.borderSubtle
                        border.width: 1

                        RowLayout {
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                            Rectangle { width: 34; height: 12; radius: 6; color: Theme.accentWarm }
                            Item { Layout.fillWidth: true }
                            Rectangle { width: 24; height: 12; radius: 6; color: Theme.bgPillHover }
                            Item { Layout.fillWidth: true }
                            Rectangle { width: 30; height: 12; radius: 6; color: Theme.bgPillHover }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Только пузыри"
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: active ? Font.Bold : Font.Medium
                        color: active ? Theme.accent : Theme.fg
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
