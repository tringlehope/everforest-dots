import QtQuick

Item {
    id: root
    property var target: (parent && parent.parent && parent.parent.contentItem === parent) ? parent.parent : parent
    property bool fromTop: true
    property real amount: 0.0

    x: target ? target.contentX : 0
    y: target ? target.contentY : 0
    width: target ? target.width : 0
    height: target ? target.height : 0
    z: 99

    Behavior on amount {
        SpringAnimation {
            spring: 5.5
            damping: 0.34
            epsilon: 0.001
        }
    }

    Scale {
        id: stretchScale
        origin.x: root.target ? root.target.width / 2 : 0
        origin.y: root.target ? (root.fromTop ? root.target.contentY : (root.target.contentY + root.target.height)) : 0
        yScale: 1.0 + root.amount
    }

    Component.onCompleted: {
        if (!target) return;
        target.boundsBehavior = Flickable.StopAtBounds;
        target.clip = true;
        if (target.contentItem) {
            var t = [];
            for (var i = 0; i < target.contentItem.transform.length; i++)
                t.push(target.contentItem.transform[i]);
            t.push(stretchScale);
            target.contentItem.transform = t;
        }
    }

    Timer {
        id: resetTimer
        interval: 120
        onTriggered: root.amount = 0.0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        onWheel: wheel => {
            wheel.accepted = false;
            if (!root.target) return;
            var dy = wheel.angleDelta.y;
            if (dy === 0) return;
            if (dy < 0 && root.target.atYEnd) {
                root.fromTop = false;
                root.amount = Math.min(0.10, root.amount + Math.min(0.04, Math.abs(dy) / 2000.0));
                resetTimer.restart();
            } else if (dy > 0 && root.target.atYBeginning) {
                root.fromTop = true;
                root.amount = Math.min(0.10, root.amount + Math.min(0.04, Math.abs(dy) / 2000.0));
                resetTimer.restart();
            } else if (root.amount > 0) {
                root.amount = 0.0;
            }
        }
    }
}
