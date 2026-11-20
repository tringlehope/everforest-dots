import QtQuick
import ".."

Item {
    id: root
    property real value: 0.5
    property color activeColor: Theme.accent
    property color trackColor: Theme.bgFrame
    property bool interactive: true
    signal moved(real newValue)

    implicitHeight: 20

    // Неактивная часть дорожки
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 4
        radius: 2
        color: root.trackColor
    }

    // Активный «червячок» (волнистая линия M3 Expressive)
    Canvas {
        id: waveCanvas
        anchors.fill: parent
        property real phase: 0

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onValueChanged() { waveCanvas.requestPaint(); }
            function onActiveColorChanged() { waveCanvas.requestPaint(); }
        }

        NumberAnimation on phase {
            from: 0; to: Math.PI * 2
            duration: 1800
            loops: Animation.Infinite
            running: root.visible && root.value > 0.02
            onStopped: waveCanvas.requestPaint()
        }
        onPhaseChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = Math.max(0, width * Math.max(0, Math.min(1, root.value)) - 6);
            if (w <= 2) return;
            var cy = height / 2;
            var amp = 2.6;
            var freq = 0.28;

            ctx.strokeStyle = root.activeColor;
            ctx.lineWidth = 3.5;
            ctx.lineCap = "round";
            ctx.beginPath();
            for (var x = 2; x <= w; x += 2) {
                var y = cy + Math.sin(x * freq + phase) * amp;
                if (x === 2) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
    }

    // Бегунок-таблетка
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(parent.width - width, parent.width * Math.max(0, Math.min(1, root.value)) - width / 2))
        width: 6
        height: 16
        radius: 3
        color: root.activeColor
    }

    MouseArea {
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        enabled: root.interactive
        onPressed: mouse => root.moved(Math.max(0, Math.min(1, mouse.x / width)))
        onPositionChanged: mouse => {
            if (pressed) root.moved(Math.max(0, Math.min(1, mouse.x / width)));
        }
    }
}
