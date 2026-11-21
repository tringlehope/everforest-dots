import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

Scope {
    id: root
    readonly property int cornerR: Theme.radiusWindow + 8

    PanelWindow {
        anchors { left: true; top: true; bottom: true }
        implicitWidth: Theme.frameThickness
        exclusiveZone: Theme.frameThickness
        color: Theme.bgFrame
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-frame"
        visible: (Theme.showFrame && !Theme.isWin7)
    }

    PanelWindow {
        anchors { right: true; top: true; bottom: true }
        implicitWidth: Theme.frameThickness
        exclusiveZone: Theme.frameThickness
        color: Theme.bgFrame
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-frame"
        visible: (Theme.showFrame && !Theme.isWin7)
    }

    PanelWindow {
        anchors { left: true; right: true; bottom: true }
        implicitHeight: Theme.frameThickness
        exclusiveZone: Theme.frameThickness
        color: Theme.bgFrame
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-frame"
        visible: (Theme.showFrame && !Theme.isWin7)
    }

    component CornerCutout: PanelWindow {
        property bool isLeft: true
        property bool isTop: true

        implicitWidth: root.cornerR
        implicitHeight: root.cornerR
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-corner"
        visible: (Theme.showFrame && !Theme.isWin7)
        mask: Region {}

        margins {
            left:   isLeft  ? Theme.frameThickness : 0
            right:  !isLeft ? Theme.frameThickness : 0
            top:    isTop   ? Theme.topBarHeight   : 0
            bottom: !isTop  ? Theme.frameThickness : 0
        }

        Canvas {
            id: cornerCanvas
            Connections {
                target: Theme
                function onBgFrameChanged() { cornerCanvas.requestPaint() }
                function onCurrentThemeChanged() { cornerCanvas.requestPaint() }
            }
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var r = root.cornerR;
                ctx.fillStyle = Theme.bgFrame.toString();
                ctx.beginPath();
                if (isLeft && isTop) {
                    ctx.moveTo(0, 0); ctx.lineTo(r, 0);
                    ctx.arc(r, r, r, -Math.PI/2, Math.PI, true);
                } else if (!isLeft && isTop) {
                    ctx.moveTo(r, 0); ctx.lineTo(0, 0);
                    ctx.arc(0, r, r, -Math.PI/2, 0, false);
                } else if (isLeft && !isTop) {
                    ctx.moveTo(0, r); ctx.lineTo(0, 0);
                    ctx.arc(r, 0, r, Math.PI, Math.PI/2, true);
                } else {
                    ctx.moveTo(r, r); ctx.lineTo(r, 0);
                    ctx.arc(0, 0, r, 0, Math.PI/2, false);
                }
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    CornerCutout { anchors { left: true; top: true }    isLeft: true;  isTop: true }
    CornerCutout { anchors { right: true; top: true }   isLeft: false; isTop: true }
    CornerCutout { anchors { left: true; bottom: true } isLeft: true;  isTop: false }
    CornerCutout { anchors { right: true; bottom: true } isLeft: false; isTop: false }
}
