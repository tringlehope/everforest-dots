import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

Scope {
    id: mgr

    property bool recording: false
    property bool paused: false
    property int elapsedSec: 0
    property int segIndex: 0
    property bool screenSharing: false
    property bool showSaveDialog: false
    property bool stoppingForPause: false
    property bool stoppingFinal: false

    readonly property string elapsedText: {
        var m = Math.floor(elapsedSec / 60)
        var s = elapsedSec % 60
        return ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2)
    }

    function startRecording() {
        if (recording) return
        showSaveDialog = false
        segIndex = 0
        elapsedSec = 0
        paused = false
        stoppingForPause = false
        stoppingFinal = false
        cleanProc.running = true
    }

    function togglePause() {
        if (!recording) return
        if (!paused) {
            stoppingForPause = true
            paused = true
            killRecProc.running = true
        } else {
            paused = false
            segIndex += 1
            startSegment()
        }
    }

    function stopRecording() {
        if (!recording) return
        stoppingFinal = true
        stoppingForPause = false
        if (paused) {
            finalizeSegments()
        } else {
            killRecProc.running = true
        }
    }

    function startSegment() {
        var out = "/tmp/qs-rec-" + segIndex + ".mp4"
        var audioFlag = hasAudioMix ? "-a=qs_rec_mix.monitor " : ""
        recProc.command = ["sh", "-c", "wf-recorder -y " + audioFlag + "-f " + JSON.stringify(out)]
        recProc.running = true
    }

    property bool hasAudioMix: false

    function finalizeSegments() {
        recording = false
        paused = false
        unloadAudioProc.running = true
        var cmd = "if [ " + segIndex + " -eq 0 ]; then mv -f /tmp/qs-rec-0.mp4 /tmp/qs-rec-final.mp4; else : > /tmp/qs-rec-list.txt; for i in $(seq 0 " + segIndex + "); do echo \"file '/tmp/qs-rec-$i.mp4'\" >> /tmp/qs-rec-list.txt; done; ffmpeg -y -f concat -safe 0 -i /tmp/qs-rec-list.txt -c copy /tmp/qs-rec-final.mp4; fi"
        mergeProc.command = ["sh", "-c", cmd]
        mergeProc.running = true
    }

    Process {
        id: cleanProc
        command: ["sh", "-c", "rm -f /tmp/qs-rec-*.mp4 /tmp/qs-rec-list.txt /tmp/qs-rec-mods && for m in $(pactl list short modules | awk '/qs_rec_mix/{print $1}'); do pactl unload-module $m 2>/dev/null; done; MIX=$(pactl load-module module-null-sink sink_name=qs_rec_mix sink_properties=device.description=qs_rec_mix 2>/dev/null); if [ -n \"$MIX\" ]; then echo $MIX >> /tmp/qs-rec-mods; MON=$(pactl get-default-sink 2>/dev/null).monitor; MIC=$(pactl get-default-source 2>/dev/null); L1=$(pactl load-module module-loopback source=\"$MON\" sink=qs_rec_mix 2>/dev/null); [ -n \"$L1\" ] && echo $L1 >> /tmp/qs-rec-mods; if [ -n \"$MIC\" ] && [ \"$MIC\" != \"$MON\" ]; then L2=$(pactl load-module module-loopback source=\"$MIC\" sink=qs_rec_mix 2>/dev/null); [ -n \"$L2\" ] && echo $L2 >> /tmp/qs-rec-mods; fi; echo 1; else echo 0; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                mgr.hasAudioMix = (text.trim().endsWith("1"))
                mgr.recording = true
                mgr.startSegment()
            }
        }
    }

    Process {
        id: unloadAudioProc
        command: ["sh", "-c", "if [ -f /tmp/qs-rec-mods ]; then tac /tmp/qs-rec-mods | xargs -r -n1 pactl unload-module 2>/dev/null; rm -f /tmp/qs-rec-mods; fi"]
    }

    Process {
        id: recProc
        onExited: {
            if (mgr.stoppingFinal) {
                mgr.stoppingFinal = false
                mgr.finalizeSegments()
            } else if (mgr.stoppingForPause) {
                mgr.stoppingForPause = false
            }
        }
    }

    Process {
        id: killRecProc
        command: ["pkill", "-INT", "wf-recorder"]
    }

    Process {
        id: mergeProc
        onExited: (code) => {
            if (code === 0) {
                mgr.showSaveDialog = true
            }
        }
    }

    Process {
        id: saveProc
        command: ["sh", "-c", "mkdir -p \"$HOME/Pictures/Screenshots\" && mv -f /tmp/qs-rec-final.mp4 \"$HOME/Pictures/Screenshots/recording-$(date +%Y%m%d-%H%M%S).mp4\" && rm -f /tmp/qs-rec-*.mp4 /tmp/qs-rec-list.txt"]
        onExited: mgr.showSaveDialog = false
    }

    Process {
        id: deleteProc
        command: ["sh", "-c", "rm -f /tmp/qs-rec-*.mp4 /tmp/qs-rec-list.txt"]
        onExited: mgr.showSaveDialog = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: mgr.recording && !mgr.paused
        onTriggered: mgr.elapsedSec += 1
    }

    // Проверка активной трансляции экрана через PipeWire
    Process {
        id: castCheckProc
        command: ["sh", "-c", "pw-dump 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(1 if any(o.get('type')=='PipeWire:Interface:Node' and 'Video/Source' in str(o.get('info',{}).get('props',{}).get('media.class','')) and any(k in (str(o.get('info',{}).get('props',{}).get('node.name',''))+str(o.get('info',{}).get('props',{}).get('application.name',''))).lower() for k in ('xdph','portal','hyprland')) for o in d) else 0)\" 2>/dev/null || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: mgr.screenSharing = (text.trim() === "1")
        }
    }

    Timer {
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!castCheckProc.running) castCheckProc.running = true
        }
    }

    // Окно «Сохранить или удалить запись»
    PanelWindow {
        visible: mgr.showSaveDialog
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: mgr.showSaveDialog ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Rectangle {
            scale: delM.pressed ? 0.94 : (delM.containsMouse ? 1.04 : 1.0)
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 140 } }
            anchors.centerIn: parent
            width: 340
            height: dlgCol.implicitHeight + 36
            radius: Theme.radiusCard
            color: Theme.bgSurface
            border.color: Theme.accent
            border.width: 3

            ColumnLayout {
                id: dlgCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 14

                Text {
                    Layout.fillWidth: true
                    text: "Запись завершена (" + mgr.elapsedText + ")"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.ExtraBold
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: "Сохранить видео в ~/Pictures/Screenshots?"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.ExtraBold
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        scale: delM.pressed ? 0.93 : (delM.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Theme.r(12)
                        color: delM.containsMouse ? Theme.bgPillHover : Theme.bgPill
                        Text {
                            anchors.centerIn: parent
                            text: "Удалить"
                            color: Theme.danger
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.ExtraBold
                        }
                        MouseArea {
                            id: delM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: deleteProc.running = true
                        }
                    }

                    Rectangle {
                        scale: saveM.pressed ? 0.93 : (saveM.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Theme.r(12)
                        color: saveM.containsMouse ? "#b8cf93" : Theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: "Сохранить"
                            color: Theme.accentOn
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.ExtraBold
                        }
                        MouseArea {
                            id: saveM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: saveProc.running = true
                        }
                    }
                }
            }
        }
    }
}
