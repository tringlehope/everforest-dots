import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root

    property bool active: false
    property string shotUrl: ""
    property int shotCounter: 0

    // Выделение области
    property bool isSelecting: false
    property bool hasSelection: false
    property real startX: 0
    property real startY: 0
    property int selX: 0
    property int selY: 0
    property int selW: 0
    property int selH: 0

    // Инструменты: "none" | "draw" | "eraser" | "pipette"
    property string activeTool: "none"
    property color brushColor: "#e67e80"
    property int brushWidth: 6
    property int eraserWidth: 18
    readonly property int currentToolWidth: activeTool === "eraser" ? eraserWidth : brushWidth

    property string colorFormat: "HEX" // "HEX" | "RGB" | "HSL"
    property string hoverColorText: ""
    property color hoverColorVal: "#a7c080"
    property string toastText: ""

    // Курсор на холсте
    property real cursorX: 0
    property real cursorY: 0
    property bool cursorInSel: false

    // Рисование
    property var strokes: []
    property var currentStroke: null
    property bool isDrawing: false
    property bool exportPending: false
    property string exportAction: "" // "copy" | "save"

    readonly property var paletteColors: ["#e67e80", "#dbbc7f", "#a7c080", "#7fbbb3", "#d3c6aa"]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: active

    function start() { open() }
    function startCapture() { open() }
    function toggle() { active ? close() : open() }

    function open() {
        hasSelection = false
        isSelecting = false
        activeTool = "none"
        strokes = []
        currentStroke = null
        toastText = ""
        hoverColorText = ""
        cursorInSel = false
        grimProc.running = true
    }

    function close() {
        active = false
        isSelecting = false
        isDrawing = false
        currentStroke = null
        cursorInSel = false
        toastTimer.stop()
    }

    function undo() {
        if (strokes.length > 0) {
            strokes = strokes.slice(0, strokes.length - 1)
            drawCanvas.requestPaint()
        }
    }

    function formatColor(r, g, b) {
        if (colorFormat === "RGB") {
            return "rgb(" + r + ", " + g + ", " + b + ")"
        } else if (colorFormat === "HSL") {
            var rn = r / 255, gn = g / 255, bn = b / 255
            var max = Math.max(rn, gn, bn), min = Math.min(rn, gn, bn)
            var h = 0, s = 0, l = (max + min) / 2
            if (max !== min) {
                var d = max - min
                s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
                if (max === rn) h = (gn - bn) / d + (gn < bn ? 6 : 0)
                else if (max === gn) h = (bn - rn) / d + 2
                else h = (rn - gn) / d + 4
                h /= 6
            }
            return "hsl(" + Math.round(h * 360) + ", " + Math.round(s * 100) + "%, " + Math.round(l * 100) + "%)"
        }
        var hex = function(n) { return ("0" + n.toString(16)).slice(-2).toUpperCase() }
        return "#" + hex(r) + hex(g) + hex(b)
    }

    function samplePixel(px, py) {
        var x = Math.max(0, Math.min(Math.round(px), root.width - 1))
        var y = Math.max(0, Math.min(Math.round(py), root.height - 1))
        var bg = pickCanvas.getContext("2d").getImageData(x, y, 1, 1).data
        var fg = drawCanvas.getContext("2d").getImageData(x, y, 1, 1).data
        var r = bg[0], g = bg[1], b = bg[2]
        if (fg[3] > 0) {
            var a = fg[3] / 255.0
            r = Math.round(fg[0] * a + bg[0] * (1 - a))
            g = Math.round(fg[1] * a + bg[1] * (1 - a))
            b = Math.round(fg[2] * a + bg[2] * (1 - a))
        }
        return { r: r, g: g, b: b }
    }

    function copyText(txt) {
        clipProc.command = ["sh", "-c", "printf '%s' " + JSON.stringify(txt) + " | wl-copy"]
        clipProc.running = true
        toastText = "Скопировано: " + txt
        toastTimer.restart()
    }

    function runExport(action) {
        if (!hasSelection || selW < 2 || selH < 2) return
        var scaleX = (bgImg.sourceSize.width > 0 && root.width > 0) ? (bgImg.sourceSize.width / root.width) : 1.0
        var scaleY = (bgImg.sourceSize.height > 0 && root.height > 0) ? (bgImg.sourceSize.height / root.height) : 1.0
        var sx = Math.max(0, Math.round(selX * scaleX))
        var sy = Math.max(0, Math.round(selY * scaleY))
        var sw = Math.max(2, Math.round(selW * scaleX))
        var sh = Math.max(2, Math.round(selH * scaleY))
        var hasDraw = (strokes.length > 0)
        if (hasDraw) {
            drawCanvas.save("/tmp/qs-shot-draw.png")
        }
        var cropFilter = "crop=" + sw + ":" + sh + ":" + sx + ":" + sy
        var ffCmd = hasDraw
            ? ("ffmpeg -y -i /tmp/qs-shot-raw.png -i /tmp/qs-shot-draw.png -filter_complex \"[1:v][0:v]scale2ref[fg][bg];[bg][fg]overlay=0:0," + cropFilter + "\" /tmp/qs-shot-out.png")
            : ("ffmpeg -y -i /tmp/qs-shot-raw.png -vf \"" + cropFilter + "\" /tmp/qs-shot-out.png")
        var postCmd = (action === "copy")
            ? "wl-copy < /tmp/qs-shot-out.png"
            : "mkdir -p \"$HOME/Pictures/Screenshots\" && cp /tmp/qs-shot-out.png \"$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png\""
        exportExecProc.command = ["sh", "-c", ffCmd + " && " + postCmd]
        exportExecProc.running = true
    }

    Process {
        id: grimProc
        command: ["grim", "/tmp/qs-shot-raw.png"]
        onExited: (code) => {
            if (code === 0) {
                root.shotCounter += 1
                root.shotUrl = "file:///tmp/qs-shot-raw.png?v=" + root.shotCounter
                root.active = true
                pickCanvas.loadImage(root.shotUrl)
                drawCanvas.requestPaint()
            }
        }
    }

    Process { id: clipProc }

    Process {
        id: exportExecProc
        onExited: root.close()
    }

    Timer {
        id: toastTimer
        interval: 1800
        onTriggered: root.toastText = ""
    }

    Item {
        id: keyRoot
        anchors.fill: parent
        focus: root.active

        Keys.onEscapePressed: root.close()
        Keys.onPressed: (event) => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                root.undo()
                event.accepted = true
            }
        }

        // Замороженный фон экрана
        Image {
            id: bgImg
            anchors.fill: parent
            source: root.shotUrl
            cache: false
            smooth: false
        }

        // Буфер для пипетки (под непрозрачным bgImg, чтобы Qt рисовал кадр)
        Canvas {
            id: pickCanvas
            anchors.fill: parent
            z: -1
            visible: true
            onImageLoaded: {
                if (isImageLoaded(root.shotUrl)) requestPaint()
            }
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (isImageLoaded(root.shotUrl)) {
                    ctx.drawImage(root.shotUrl, 0, 0, width, height)
                }
            }
        }

        // Слой рисунка (ластик стирает только этот слой)
        Canvas {
            id: drawCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                var all = root.strokes.slice()
                if (root.currentStroke) all.push(root.currentStroke)
                for (var i = 0; i < all.length; i++) {
                    var s = all[i]
                    if (!s.points || s.points.length === 0) continue
                    ctx.globalCompositeOperation = (s.type === "erase") ? "destination-out" : "source-over"
                    ctx.strokeStyle = s.color
                    ctx.fillStyle = s.color
                    ctx.lineWidth = s.width
                    if (s.points.length === 1) {
                        ctx.beginPath()
                        ctx.arc(s.points[0].x, s.points[0].y, s.width / 2, 0, Math.PI * 2)
                        ctx.fill()
                    } else {
                        ctx.beginPath()
                        ctx.moveTo(s.points[0].x, s.points[0].y)
                        for (var j = 1; j < s.points.length; j++) {
                            ctx.lineTo(s.points[j].x, s.points[j].y)
                        }
                        ctx.stroke()
                    }
                }
                ctx.globalCompositeOperation = "source-over"
            }
        }

        // Скрытый Canvas для склейки и обрезки при сохранении/копировании
        Canvas {
            id: exportCanvas
            visible: false
            onPaint: {
                if (!root.exportPending) return
                root.exportPending = false
                var ctx = getContext("2d")
                var bg = pickCanvas.getContext("2d").getImageData(root.selX, root.selY, root.selW, root.selH)
                var fg = drawCanvas.getContext("2d").getImageData(root.selX, root.selY, root.selW, root.selH)
                var bd = bg.data, fd = fg.data
                for (var i = 0; i < bd.length; i += 4) {
                    var a = fd[i + 3] / 255.0
                    if (a > 0) {
                        bd[i]     = Math.round(fd[i]     * a + bd[i]     * (1 - a))
                        bd[i + 1] = Math.round(fd[i + 1] * a + bd[i + 1] * (1 - a))
                        bd[i + 2] = Math.round(fd[i + 2] * a + bd[i + 2] * (1 - a))
                        bd[i + 3] = 255
                    }
                }
                ctx.putImageData(bg, 0, 0)
                save("/tmp/qs-shot-out.png")
                if (root.exportAction === "copy") {
                    exportExecProc.command = ["sh", "-c", "wl-copy < /tmp/qs-shot-out.png"]
                } else {
                    exportExecProc.command = ["sh", "-c", "mkdir -p \"$HOME/Pictures/Screenshots\" && cp /tmp/qs-shot-out.png \"$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png\""]
                }
                exportExecProc.running = true
            }
        }

        // Затемнение вокруг выделенной области
        Item {
            anchors.fill: parent
            visible: root.hasSelection || root.isSelecting
            Rectangle { x: 0; y: 0; width: parent.width; height: root.selY; color: "#88181d20" }
            Rectangle { x: 0; y: root.selY + root.selH; width: parent.width; height: Math.max(0, parent.height - (root.selY + root.selH)); color: "#88181d20" }
            Rectangle { x: 0; y: root.selY; width: root.selX; height: root.selH; color: "#88181d20" }
            Rectangle { x: root.selX + root.selW; y: root.selY; width: Math.max(0, parent.width - (root.selX + root.selW)); height: root.selH; color: "#88181d20" }

            Rectangle {
                x: root.selX - 2
                y: root.selY - 2
                width: root.selW + 4
                height: root.selH + 4
                color: "transparent"
                border.color: "#a7c080"
                border.width: 2
            }
        }

        // Полное затемнение до начала выделения
        Rectangle {
            anchors.fill: parent
            color: "#88181d20"
            visible: !root.hasSelection && !root.isSelecting
        }

        // Взаимодействие мышью (выделение / рисование ЛКМ / ластик ПКМ / пипетка)
        MouseArea {
            id: mainMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: (root.activeTool === "draw" || root.activeTool === "eraser") && root.cursorInSel
                         ? Qt.BlankCursor : Qt.CrossCursor

            onPressed: (mouse) => {
                var inSel = root.hasSelection &&
                            mouse.x >= root.selX && mouse.x <= root.selX + root.selW &&
                            mouse.y >= root.selY && mouse.y <= root.selY + root.selH

                if (root.activeTool === "pipette" && mouse.button === Qt.LeftButton) {
                    var c = root.samplePixel(mouse.x, mouse.y)
                    root.copyText(root.formatColor(c.r, c.g, c.b))
                    return
                }

                if ((root.activeTool === "draw" || root.activeTool === "eraser") && inSel) {
                    var eraseMode = (mouse.button === Qt.RightButton || root.activeTool === "eraser")
                    root.isDrawing = true
                    root.currentStroke = {
                        type: eraseMode ? "erase" : "draw",
                        color: root.brushColor.toString(),
                        width: eraseMode ? root.eraserWidth : root.brushWidth,
                        points: [{ x: mouse.x, y: mouse.y }]
                    }
                    drawCanvas.requestPaint()
                    return
                }

                if (mouse.button === Qt.LeftButton && root.activeTool === "none") {
                    root.isSelecting = true
                    root.hasSelection = false
                    root.startX = mouse.x
                    root.startY = mouse.y
                    root.selX = Math.round(mouse.x)
                    root.selY = Math.round(mouse.y)
                    root.selW = 0
                    root.selH = 0
                } else if (mouse.button === Qt.RightButton && root.activeTool === "none") {
                    root.close()
                }
            }

            onPositionChanged: (mouse) => {
                root.cursorX = mouse.x
                root.cursorY = mouse.y
                root.cursorInSel = root.hasSelection &&
                                   mouse.x >= root.selX && mouse.x <= root.selX + root.selW &&
                                   mouse.y >= root.selY && mouse.y <= root.selY + root.selH

                if (root.activeTool === "pipette") {
                    var c = root.samplePixel(mouse.x, mouse.y)
                    root.hoverColorVal = Qt.rgba(c.r / 255, c.g / 255, c.b / 255, 1)
                    root.hoverColorText = root.formatColor(c.r, c.g, c.b)
                }

                if (root.isDrawing && root.currentStroke) {
                    var cx = Math.max(root.selX, Math.min(mouse.x, root.selX + root.selW))
                    var cy = Math.max(root.selY, Math.min(mouse.y, root.selY + root.selH))
                    root.currentStroke.points.push({ x: cx, y: cy })
                    drawCanvas.requestPaint()
                    return
                }

                if (root.isSelecting) {
                    root.selX = Math.round(Math.min(root.startX, mouse.x))
                    root.selY = Math.round(Math.min(root.startY, mouse.y))
                    root.selW = Math.round(Math.abs(mouse.x - root.startX))
                    root.selH = Math.round(Math.abs(mouse.y - root.startY))
                }
            }

            onExited: root.cursorInSel = false

            onReleased: {
                if (root.isDrawing && root.currentStroke) {
                    var copy = root.strokes.slice()
                    copy.push(root.currentStroke)
                    root.strokes = copy
                    root.currentStroke = null
                    root.isDrawing = false
                    drawCanvas.requestPaint()
                }
                if (root.isSelecting) {
                    root.isSelecting = false
                    root.hasSelection = (root.selW > 8 && root.selH > 8)
                }
            }

            onWheel: (wheel) => {
                if (root.activeTool === "draw") {
                    root.brushWidth = wheel.angleDelta.y > 0
                        ? Math.min(40, root.brushWidth + 2)
                        : Math.max(2, root.brushWidth - 2)
                } else if (root.activeTool === "eraser") {
                    root.eraserWidth = wheel.angleDelta.y > 0
                        ? Math.min(40, root.eraserWidth + 2)
                        : Math.max(2, root.eraserWidth - 2)
                }
            }
        }

        // Живое кольцо размера кисти / ластика под курсором
        Rectangle {
            readonly property bool showRing: (root.activeTool === "draw" || root.activeTool === "eraser") && root.cursorInSel
            readonly property bool isErasingNow: root.activeTool === "eraser" || (root.isDrawing && root.currentStroke && root.currentStroke.type === "erase")
            readonly property int ringSize: (root.isDrawing && root.currentStroke) ? root.currentStroke.width : root.currentToolWidth

            visible: showRing
            x: root.cursorX - width / 2
            y: root.cursorY - height / 2
            width: Math.max(4, ringSize)
            height: Math.max(4, ringSize)
            radius: width / 2
            color: "transparent"
            border.color: isErasingNow ? "#d3c6aa" : root.brushColor
            border.width: 2
        }

        // Подсказка до выделения
        Rectangle {
            visible: !root.hasSelection && !root.isSelecting
            anchors.centerIn: parent
            width: hintLbl.implicitWidth + 32
            height: 44
            radius: Theme.r(14)
            color: "#2d353b"
            border.color: "#a7c080"
            border.width: 2

            Text {
                id: hintLbl
                anchors.centerIn: parent
                text: "Выделите область мышью • Esc — отмена"
                color: "#d3c6aa"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }

        // Тост-уведомление (после пипетки)
        Rectangle {
            visible: root.toastText !== ""
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 28
            width: toastLbl.implicitWidth + 32
            height: 40
            radius: Theme.r(12)
            color: "#2d353b"
            border.color: "#a7c080"
            border.width: 2

            Text {
                id: toastLbl
                anchors.centerIn: parent
                text: root.toastText
                color: "#a7c080"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }

        // Панель действий и настроек инструмента
        Column {
            id: toolbarCol
            visible: root.hasSelection && !root.isSelecting
            spacing: 8
            x: Math.max(12, Math.min(root.selX + (root.selW - width) / 2, root.width - width - 12))
            y: (root.selY + root.selH + height + 16 <= root.height)
               ? (root.selY + root.selH + 10)
               : Math.max(12, root.selY - height - 10)

            // Дополнительная панель: цвета + размер 1:1 (для кисти/ластика) или формат (для пипетки)
            Rectangle {
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                id: subBar
                visible: root.activeTool === "draw" || root.activeTool === "eraser" || root.activeTool === "pipette"
                anchors.horizontalCenter: parent.horizontalCenter
                width: subRow.implicitWidth + 24
                height: 56
                radius: Theme.r(14)
                color: "#2d353b"
                border.color: "#a7c080"
                border.width: 2

                Row {
                    id: subRow
                    anchors.centerIn: parent
                    spacing: 10

                    // Палитра цветов (только для кисти)
                    Row {
                        visible: root.activeTool === "draw"
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: root.paletteColors
                            Rectangle {
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                                Behavior on color { ColorAnimation { duration: 140 } }
                                width: 24
                                height: 24
                                radius: Theme.r(12)
                                color: modelData
                                border.color: root.brushColor.toString() === modelData ? "#d3c6aa" : "#232a2e"
                                border.width: root.brushColor.toString() === modelData ? 3 : 2
                                MouseArea {
                    id: btnMa_12
                    hoverEnabled: true
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.brushColor = modelData
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: root.activeTool === "draw"
                        width: 2; height: 26; radius: Theme.r(1)
                        color: "#323c41"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Независимый размер кисти / ластика + живое отображение 1:1
                    Row {
                        visible: root.activeTool === "draw" || root.activeTool === "eraser"
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: root.activeTool === "eraser" ? "Ластик:" : "Кисть:"
                            color: "#d3c6aa"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Слайдер ширины 2..40px
                        Item {
                            width: 110
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 6
                                radius: Theme.r(3)
                                color: "#323c41"

                                Rectangle {
                                    width: ((root.currentToolWidth - 2) / 38) * parent.width
                                    height: parent.height
                                    radius: Theme.r(3)
                                    color: "#a7c080"
                                }
                            }

                            Rectangle {
                                width: 16; height: 16; radius: Theme.r(8)
                                color: "#d3c6aa"
                                border.color: "#232a2e"
                                border.width: 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, ((root.currentToolWidth - 2) / 38) * (parent.width - width)))
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                function updateWidth(mx) {
                                    var ratio = Math.max(0, Math.min(1, mx / width))
                                    var val = Math.round(2 + ratio * 38)
                                    if (root.activeTool === "eraser") root.eraserWidth = val
                                    else root.brushWidth = val
                                }
                                onPressed: (m) => updateWidth(m.x)
                                onPositionChanged: (m) => { if (pressed) updateWidth(m.x) }
                            }
                        }

                        // Наглядный предпросмотр диаметра 1:1
                        Rectangle {
                            width: 44
                            height: 44
                            radius: Theme.r(10)
                            color: "#232a2e"
                            border.color: "#323c41"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.centerIn: parent
                                width: root.currentToolWidth
                                height: root.currentToolWidth
                                radius: width / 2
                                color: root.activeTool === "eraser" ? "#2d353b" : root.brushColor
                                border.color: root.activeTool === "eraser" ? "#d3c6aa" : "transparent"
                                border.width: root.activeTool === "eraser" ? 2 : 0
                            }
                        }

                        Text {
                            text: root.currentToolWidth + "px"
                            color: "#dbbc7f"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            width: 38
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Настройки пипетки: формат HEX / RGB / HSL + предпросмотр под курсором
                    Row {
                        visible: root.activeTool === "pipette"
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "Формат:"
                            color: "#d3c6aa"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                            model: ["HEX", "RGB", "HSL"]
                            Rectangle {
                                scale: animMa_2.pressed ? 0.93 : (animMa_2.containsMouse ? 1.05 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                                Behavior on color { ColorAnimation { duration: 140 } }
                                width: fmtTxt.implicitWidth + 18
                                height: 28
                                radius: Theme.r(8)
                                color: root.colorFormat === modelData ? "#a7c080" : "#323c41"
                                Text {
                                    id: fmtTxt
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.colorFormat === modelData ? "#232a2e" : "#d3c6aa"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    id: animMa_2
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.colorFormat = modelData
                                }
                            }
                        }

                        Rectangle {
                            visible: root.hoverColorText !== ""
                            width: 2; height: 22; radius: Theme.r(1)
                            color: "#323c41"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            visible: root.hoverColorText !== ""
                            width: 20; height: 20; radius: Theme.r(6)
                            color: root.hoverColorVal
                            border.color: "#d3c6aa"
                            border.width: 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            visible: root.hoverColorText !== ""
                            text: root.hoverColorText
                            color: "#d3c6aa"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Главная панель кнопок (без записи экрана)
            Rectangle {
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 140 } }
                anchors.horizontalCenter: parent.horizontalCenter
                width: mainRow.implicitWidth + 20
                height: 48
                radius: Theme.r(14)
                color: "#2d353b"
                border.color: "#a7c080"
                border.width: 2

                Row {
                    id: mainRow
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "draw",    icon: "\uf040" },
                            { id: "eraser",  icon: "\uf12d" },
                            { id: "pipette", icon: "\uf1fb" }
                        ]
                        Rectangle {
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            width: 36
                            height: 34
                            radius: Theme.r(10)
                            color: root.activeTool === modelData.id ? "#a7c080" : "#323c41"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: root.activeTool === modelData.id ? "#232a2e" : "#d3c6aa"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                            }
                            MouseArea {
                    id: btnMa_13
                    hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTool = (root.activeTool === modelData.id ? "none" : modelData.id)
                            }
                        }
                    }

                    Rectangle {
                        scale: animMa_3.pressed ? 0.93 : (animMa_3.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        visible: root.strokes.length > 0
                        width: undoLbl.implicitWidth + 20
                        height: 34
                        radius: Theme.r(10)
                        color: "#323c41"
                        Text {
                            id: undoLbl
                            anchors.centerIn: parent
                            text: "Отменить"
                            color: "#dbbc7f"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            id: animMa_3
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.undo()
                        }
                    }

                    Rectangle {
                        scale: animMa_4.pressed ? 0.93 : (animMa_4.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        width: copyLbl.implicitWidth + 22
                        height: 34
                        radius: Theme.r(10)
                        color: "#323c41"
                        Text {
                            id: copyLbl
                            anchors.centerIn: parent
                            text: "Копировать"
                            color: "#d3c6aa"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            id: animMa_4
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runExport("copy")
                        }
                    }

                    Rectangle {
                        scale: animMa_5.pressed ? 0.93 : (animMa_5.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        width: saveLbl.implicitWidth + 22
                        height: 34
                        radius: Theme.r(10)
                        color: "#a7c080"
                        Text {
                            id: saveLbl
                            anchors.centerIn: parent
                            text: "Сохранить"
                            color: "#232a2e"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            id: animMa_5
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runExport("save")
                        }
                    }

                    Rectangle {
                        scale: animMa_6.pressed ? 0.93 : (animMa_6.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        width: 34
                        height: 34
                        radius: Theme.r(10)
                        color: "#323c41"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: "#e67e80"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            id: animMa_6
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }
            }
        }
    }
}
