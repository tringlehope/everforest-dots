import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../components"
import ".."

PanelWindow {
    id: win
    property bool open: false
    property int tabIndex: 0
    property var appStreams: []
    property var audioSinks: []
    property var audioSources: []
    property bool isInteracting: false

    visible: card.scale > 0.05 || open
    exclusiveZone: -1
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"

    Process {
        id: pactlProc
        command: ["python3", "-c", "import subprocess,json\ndef out(cmd):\n  return subprocess.run(cmd,capture_output=True,text=True).stdout.strip()\nins=json.loads(out(['pactl','-f','json','list','sink-inputs']) or '[]')\nsinks=json.loads(out(['pactl','-f','json','list','sinks']) or '[]')\nsources=json.loads(out(['pactl','-f','json','list','sources']) or '[]')\ndefault_s=out(['pactl','get-default-sink'])\ndefault_src=out(['pactl','get-default-source'])\napps=[]\nfor x in ins:\n  p=x.get('properties',{})\n  v='100'\n  if x.get('volume'):\n    v=list(x['volume'].values())[0].get('value_percent','100%').replace('%','').strip()\n  apps.append({'id':x['index'],'name':p.get('application.name') or p.get('media.name') or 'App','vol':int(v)/100.0})\ndevs=[{'name':x['name'],'desc':x.get('description') or x['name'],'def':x['name']==default_s} for x in sinks]\nsrcs=[{'name':x['name'],'desc':x.get('description') or x['name'],'def':x['name']==default_src} for x in sources if not x.get('monitor_of') and not x['name'].endswith('.monitor')]\nprint(json.dumps({'apps':apps,'devs':devs,'srcs':srcs}))"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (win.isInteracting) return;
                try {
                    var data = JSON.parse(text);
                    win.appStreams = data.apps || [];
                    win.audioSinks = data.devs || [];
                    win.audioSources = data.srcs || [];
                } catch (e) {}
            }
        }
    }

    onOpenChanged: if (open) pactlProc.running = true
    Timer { interval: 1000; running: win.open && !win.isInteracting; repeat: true; onTriggered: pactlProc.running = true }

    MouseArea { anchors.fill: parent; onClicked: win.open = false }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.topBarHeight + 8
        width: 440
        height: Math.min(440, contentCol.implicitHeight + 28)
        radius: Theme.radiusCard
        color: Theme.bgSurface
        border.color: Theme.accent
        border.width: 3

        transformOrigin: Item.Top
        scale: win.open ? 1.0 : 0.0
        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: contentCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            Rectangle {
                Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.005 } }
                Layout.fillWidth: true
                implicitHeight: 34
                radius: Theme.r(14)
                color: Theme.bgFrame

                RowLayout {
                    anchors.fill: parent; anchors.margins: 3; spacing: 4
                    Repeater {
                        model: ["Микшер", "Источники"]
                        delegate: Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: Theme.r(11)
                            color: win.tabIndex === index ? Theme.accentWarm : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold
                                color: win.tabIndex === index ? Theme.accentOn : Theme.fgMuted
                            }
                            MouseArea { hoverEnabled: true; id: btnMa_8; cursorShape: Qt.PointingHandCursor; anchors.fill: parent; onClicked: win.tabIndex = index }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: win.tabIndex === 0
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: win.appStreams
                    delegate: Rectangle {
                        required property var modelData
                        property real localVol: modelData.vol
                        Layout.fillWidth: true
                        implicitHeight: 58
                        radius: Theme.r(14)
                        color: appHover.hovered ? Theme.bgPillHover : Theme.bgPill

                        HoverHandler { id: appHover }
                        WheelHandler {
                            onWheel: event => {
                                var next = Math.max(0, Math.min(1, localVol + (event.angleDelta.y > 0 ? 0.05 : -0.05)));
                                localVol = next;
                                Quickshell.execDetached(["pactl", "set-sink-input-volume", String(modelData.id), Math.round(next * 100) + "%"]);
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.fg
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: Math.round(localVol * 100) + "%"
                                    font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 11; color: Theme.fgMuted
                                }
                            }
                            WavySlider {
                                Layout.fillWidth: true
                                value: localVol
                                onMoved: v => {
                                    win.isInteracting = true;
                                    localVol = v;
                                    Quickshell.execDetached(["pactl", "set-sink-input-volume", String(modelData.id), Math.round(v * 100) + "%"]);
                                    interactTimer.restart();
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: win.appStreams.length === 0
                    text: "Нет активных аудиопотоков"
                    font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12; color: Theme.fgMuted
                }
            }

            Flickable {
        OverscrollStretch {}
                visible: win.tabIndex === 1
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(368, srcCol.implicitHeight)
                contentHeight: srcCol.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: srcCol
                    width: parent.width
                    spacing: 6

                    Text {
                        text: "Устройства вывода"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.fgMuted
                    }

                    Repeater {
                        model: win.audioSinks
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Theme.r(12)
                            color: modelData.def ? Theme.accent : (sinkM.containsMouse ? Theme.bgPillHover : Theme.bgPill)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 12
                                text: modelData.desc
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold
                                color: modelData.def ? Theme.accentOn : Theme.fg
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                cursorShape: Qt.PointingHandCursor
                                id: sinkM
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    Quickshell.execDetached(["pactl", "set-default-sink", modelData.name]);
                                    pactlProc.running = true;
                                }
                            }
                        }
                    }

                    Text {
                        Layout.topMargin: 6
                        text: "Устройства ввода"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.fgMuted
                    }

                    Repeater {
                        model: win.audioSources
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Theme.r(12)
                            color: modelData.def ? Theme.accent : (srcM.containsMouse ? Theme.bgPillHover : Theme.bgPill)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 12
                                text: modelData.desc
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold
                                color: modelData.def ? Theme.accentOn : Theme.fg
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                cursorShape: Qt.PointingHandCursor
                                id: srcM
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    Quickshell.execDetached(["pactl", "set-default-source", modelData.name]);
                                    pactlProc.running = true;
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: win.audioSources.length === 0
                        text: "Нет устройств ввода"
                        font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12; color: Theme.fgMuted
                    }
                }
            }
        }
    }

    Timer {
        id: interactTimer
        interval: 600
        onTriggered: win.isInteracting = false
    }
}
