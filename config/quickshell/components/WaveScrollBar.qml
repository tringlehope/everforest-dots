import QtQuick
import ".."

Canvas {
    id: root
    property Flickable target: null

    visible: target !== null && target.contentHeight > target.height
    width: 6
    property real pos: target ? target.visibleArea.yPosition : 0
    property real ratio: target ? target.visibleArea.heightRatio : 1

    onPosChanged: requestPaint()
    onRatioChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (!target || height <= 0) return;
        var y1 = Math.max(4, pos * height);
        var h = Math.max(24, ratio * height);
        var y2 = Math.min(height - 4, y1 + h);
        ctx.strokeStyle = Theme.accent;
        ctx.lineWidth = 3;
        ctx.lineCap = "round";
        ctx.beginPath();
        for (var y = y1; y <= y2; y += 2) {
            var x = width / 2 + Math.sin(y * 0.35) * 1.6;
            if (y === y1) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
}
