import QtQuick
import QtQuick.Layouts
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#232a2e"

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string currentUserName: ""
    property string currentSessionName: "Hyprland"
    property bool loginError: false

    // Скрытые Repeater/ListView для удобного чтения имён из моделей SDDM
    ListView {
        id: userHelper
        visible: false
        model: userModel
        currentIndex: root.userIndex
        delegate: Item {
            property string uName: name
        }
        onCurrentItemChanged: if (currentItem) root.currentUserName = currentItem.uName
        Component.onCompleted: if (currentItem) root.currentUserName = currentItem.uName
    }

    ListView {
        id: sessionHelper
        visible: false
        model: sessionModel
        currentIndex: root.sessionIndex
        delegate: Item {
            property string sName: name
        }
        onCurrentItemChanged: if (currentItem) root.currentSessionName = currentItem.sName
        Component.onCompleted: if (currentItem) root.currentSessionName = currentItem.sName
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.loginError = true;
            passwordInput.text = "";
            shakeAnim.start();
            passwordInput.forceActiveFocus();
        }
    }

    function doLogin() {
        root.loginError = false;
        sddm.login(root.currentUserName, passwordInput.text, root.sessionIndex);
    }

    // --- ВЕРХНЯЯ ПАНЕЛЬ ---
    Item {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        height: 36

        // Левый верхний угол: выбор сессии
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            width: sessRow.implicitWidth + 24
            radius: sessMouse.containsMouse ? 10 : 16
            color: sessMouse.containsMouse ? "#3d484d" : "#323c41"
            Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

            RowLayout {
                id: sessRow
                anchors.centerIn: parent
                spacing: 8
                Text { text: "\uf108"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: "#a7c080" }
                Text { text: root.currentSessionName; font.family: "Nunito"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#d3c6aa" }
            }

            MouseArea {
                id: sessMouse
                anchors.fill: parent; hoverEnabled: true
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount())
            }
        }

        // Центр вверху: Сон, Перезагрузка, Выключение
        Rectangle {
            anchors.centerIn: parent
            height: 32
            width: pwrRow.implicitWidth + 16
            radius: 16
            color: "#323c41"

            RowLayout {
                id: pwrRow
                anchors.centerIn: parent
                spacing: 6

                component PwrBtn: Rectangle {
                    property string icon: ""
                    property color iconColor: "#d3c6aa"
                    signal clicked()
                    width: 28; height: 24
                    radius: pm.containsMouse ? 8 : 12
                    color: pm.containsMouse ? "#3d484d" : "transparent"
                    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Text { anchors.centerIn: parent; text: icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: iconColor }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
                }

                PwrBtn { icon: "\uf186"; onClicked: sddm.suspend() }
                PwrBtn { icon: "\uf021"; onClicked: sddm.reboot() }
                PwrBtn { icon: "\uf011"; iconColor: "#e67e80"; onClicked: sddm.powerOff() }
            }
        }

        // Правый верхний угол: раскладка клавиатуры
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            width: kbRow.implicitWidth + 24
            radius: kbMouse.containsMouse ? 10 : 16
            color: kbMouse.containsMouse ? "#3d484d" : "#323c41"
            Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

            RowLayout {
                id: kbRow
                anchors.centerIn: parent
                spacing: 6
                Text { text: "\uf11c"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: "#dbbc7f" }
                Text {
                    text: {
                        if (keyboard.layouts && keyboard.layouts.length > keyboard.currentLayout) {
                            return keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase();
                        }
                        return "EN";
                    }
                    font.family: "Nunito"; font.pixelSize: 12; font.weight: Font.Bold; color: "#d3c6aa"
                }
            }

            MouseArea {
                id: kbMouse
                anchors.fill: parent; hoverEnabled: true
                onClicked: {
                    if (keyboard.layouts && keyboard.layouts.length > 0) {
                        keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length;
                    }
                }
            }
        }
    }

    // --- ЦЕНТРАЛЬНАЯ КАРТОЧКА ВХОДА ---
    Rectangle {
        id: loginCard
        anchors.centerIn: parent
        width: 340
        height: 270
        radius: 22
        color: "#2d353b"
        border.color: root.loginError ? "#e67e80" : "#a7c080"
        border.width: 3

        scale: 0.92
        Component.onCompleted: {
            scale = 1.0;
            passwordInput.forceActiveFocus();
        }
        Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // Тряска при неверном пароле
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: loginCard; property: "anchors.horizontalCenterOffset"; to: -12; duration: 55 }
            NumberAnimation { target: loginCard; property: "anchors.horizontalCenterOffset"; to: 12; duration: 55 }
            NumberAnimation { target: loginCard; property: "anchors.horizontalCenterOffset"; to: -8; duration: 55 }
            NumberAnimation { target: loginCard; property: "anchors.horizontalCenterOffset"; to: 8; duration: 55 }
            NumberAnimation { target: loginCard; property: "anchors.horizontalCenterOffset"; to: 0; duration: 55 }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 16

            // Иконка пользователя + стрелки по бокам (если пользователей > 1)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16

                Rectangle {
                    visible: userModel.count > 1
                    width: 32; height: 32; radius: prevU.containsMouse ? 10 : 16
                    color: prevU.containsMouse ? "#3d484d" : "#323c41"
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                    Text { anchors.centerIn: parent; text: "\uf053"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: "#d3c6aa" }
                    MouseArea {
                        id: prevU; anchors.fill: parent; hoverEnabled: true
                        onClicked: root.userIndex = (root.userIndex - 1 + userModel.count) % userModel.count
                    }
                }

                Rectangle {
                    width: 76; height: 76; radius: 22
                    color: "#323c41"
                    border.color: "#dbbc7f"
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        text: "\uf007"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 32
                        color: "#d3c6aa"
                    }
                }

                Rectangle {
                    visible: userModel.count > 1
                    width: 32; height: 32; radius: nextU.containsMouse ? 10 : 16
                    color: nextU.containsMouse ? "#3d484d" : "#323c41"
                    Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                    Text { anchors.centerIn: parent; text: "\uf054"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: "#d3c6aa" }
                    MouseArea {
                        id: nextU; anchors.fill: parent; hoverEnabled: true
                        onClicked: root.userIndex = (root.userIndex + 1) % userModel.count
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.currentUserName
                font.family: "Nunito"; font.pixelSize: 15; font.weight: Font.Bold; color: "#d3c6aa"
            }

            // Поле ввода пароля с «желейной» анимацией фокуса
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: passwordInput.activeFocus ? 12 : 22
                color: "#323c41"
                border.color: root.loginError ? "#e67e80" : (passwordInput.activeFocus ? "#a7c080" : "#475258")
                border.width: 2
                scale: passwordInput.activeFocus ? 1.03 : 1.0

                Behavior on radius { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10; spacing: 8

                    TextInput {
                        id: passwordInput
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        font.family: "Nunito"; font.pixelSize: 14
                        color: "#d3c6aa"
                        selectionColor: "#a7c080"
                        onTextChanged: root.loginError = false
                        Keys.onReturnPressed: root.doLogin()
                        Keys.onEnterPressed: root.doLogin()

                        Text {
                            visible: !parent.text
                            text: root.loginError ? "Неверный пароль" : "Пароль..."
                            font.family: "Nunito"; font.pixelSize: 13
                            color: root.loginError ? "#e67e80" : "#859289"
                        }
                    }

                    Rectangle {
                        width: 28; height: 28
                        radius: enterM.containsMouse ? 8 : 14
                        color: enterM.containsMouse ? "#dbbc7f" : "#a7c080"
                        Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        Text { anchors.centerIn: parent; text: "\uf054"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: "#232a2e" }
                        MouseArea { id: enterM; anchors.fill: parent; hoverEnabled: true; onClicked: root.doLogin() }
                    }
                }
            }
        }
    }
}
