import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import "../components"
import ".."

PanelWindow {
    id: win
    property bool open: false
    property int tabIndex: 0
    property var appGroups: []
    property var audioSinks: []
    property var audioSources: []
    property var expandedApps: ({})
    property bool isInteracting: false

    visible: card.scale > 0.05 || open
    exclusiveZone: -1
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"

    function toggleExpand(appName) {
        var next = Object.assign({}, win.expandedApps);
        next[appName] = !next[appName];
        win.expandedApps = next;
    }

    Process {
        id: pactlProc
        command: ["python3", "-c", "import subprocess,json
def out(cmd):
  return subprocess.run(cmd,capture_output=True,text=True).stdout.strip()
ins=json.loads(out(['pactl','-f','json','list','sink-inputs']) or '[]')
sinks=json.loads(out(['pactl','-f','json','list','sinks']) or '[]')
sources=json.loads(out(['pactl','-f','json','list','sources']) or '[]')
default_s=out(['pactl','get-default-sink'])
default_src=out(['pactl','get-default-source'])
active_ins=[x for x in ins if not x.get('corked', False)] or ins
groups={}
order=[]
for x in active_ins:
  p=x.get('properties',{})
  app=p.get('application.name') or p.get('application.process.binary') or 'App'
  icon=p.get('application.icon-name') or p.get('application.process.binary') or app.lower()
  media=p.get('media.name') or 'Аудиопоток'
  v='100'
  if x.get('volume'):
    v=list(x['volume'].values())[0].get('value_percent','100%').replace('%','').strip()
  vol=max(0.0, min(1.0, int(v)/100.0))
  if app not in groups:
    groups[app]={'name':app,'icon':icon,'by_media':{},'m_order':[]}
    order.append(app)
  bm=groups[app]['by_media']
  if media not in bm:
    bm[media]={'ids':[],'name':media,'vols':[]}
    groups[app]['m_order'].append(media)
  bm[media]['ids'].append(x['index'])
  bm[media]['vols'].append(vol)
apps=[]
for k in order:
  g=groups[k]
  streams=[]
  for m in g['m_order']:
    item=g['by_media'][m]
    streams.append({'ids':item['ids'],'name':item['name'],'vol':sum(item['vols'])/len(item['vols'])})
  apps.append({'name':g['name'],'icon':g['icon'],'streams':streams,'vol':sum(s['vol'] for s in streams)/len(streams)})
devs=[{'name':x['name'],'desc':x.get('description') or x['name'],'def':x['name']==default_s} for x in sinks]
srcs=[{'name':x['name'],'desc':x.get('description') or x['name'],'def':x['name']==default_src} for x in sources if not x.get('monitor_of') and not x['name'].endswith('.monitor')]
print(json.dumps({'apps':apps,'devs':devs,'srcs':srcs}))"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (win.isInteracting) return;
                try {
                    var data = JSON.parse(text);
                    win.appGroups = data.apps || [];
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
        width: 450
        height: Math.min(500, contentCol.implicitHeight + 28)
        radius: Theme.radiusCard
        color: Theme.bgSurface
        border.color: Theme.accent
        border.width: 3

        Behavior on height { SpringAnimation { spring: 7.5; damping: 0.38; epsilon: 0.5 } }

        transformOrigin: Item.Top
        scale: 0.0
        states: [
            State { name: "open"; when: win.open; PropertyChanges { target: card; scale: 1.0 } },
            State { name: "closed"; when: !win.open; PropertyChanges { target: card; scale: 0.0 } }
        ]
        transitions: [
            Transition {
                to: "open"
                NumberAnimation { property: "scale"; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.75 }
            },
            Transition {
                to: "closed"
                NumberAnimation { property: "scale"; duration: 150; easing.type: Easing.InCubic }
            }
        ]

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: contentCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            // Желейный переключатель вкладок со скользящей пилюлей
            Rectangle {
                id: tabBarBg
                Layout.fillWidth: true
                implicitHeight: 34
                radius: Theme.r(14)
                color: Theme.bgFrame

                Rectangle {
                    id: tabIndicator
                    y: 3
                    height: parent.height - 6
                    width: (parent.width - 10) / 2
                    x: 3 + win.tabIndex * (width + 4)
                    radius: Theme.r(11)
                    color: Theme.accentWarm
                    Behavior on x { SpringAnimation { spring: 5.5; damping: 0.28; epsilon: 0.5 } }
                }

                RowLayout {
                    anchors.fill: parent; anchors.margins: 3; spacing: 4
                    Repeater {
                        model: ["Микшер", "Источники"]
                        delegate: Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold
                                color: win.tabIndex === index ? Theme.accentOn : Theme.fgMuted
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                            MouseArea {
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor; anchors.fill: parent
                                onClicked: win.tabIndex = index
                            }
                        }
                    }
                }
            }

            // Вкладка 1: Микшер приложений с выпадающими вкладками
            Flickable {
                visible: win.tabIndex === 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(410, mixerCol.implicitHeight)
                contentHeight: mixerCol.implicitHeight
                clip: true
                interactive: contentHeight > height
                OverscrollStretch {}

                ColumnLayout {
                    id: mixerCol
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: win.appGroups
                        delegate: Rectangle {
                            id: appCard
                            required property var modelData
                            property real groupVol: modelData.vol
                            readonly property bool expanded: !!win.expandedApps[modelData.name]
                            readonly property bool hasChildren: modelData.streams && modelData.streams.length > 0

                            onModelDataChanged: if (!win.isInteracting) groupVol = modelData.vol

                            Layout.fillWidth: true
                            implicitHeight: appCardCol.implicitHeight + 20
                            radius: Theme.r(14)
                            color: appHover.hovered ? Theme.bgPillHover : Theme.bgPill
                            clip: true

                            Behavior on implicitHeight { SpringAnimation { spring: 7.5; damping: 0.38; epsilon: 0.5 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            HoverHandler { id: appHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: appCard.hasChildren ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (appCard.hasChildren) win.toggleExpand(appCard.modelData.name)
                            }

                            ColumnLayout {
                                id: appCardCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // Монохромная иконка приложения
                                    Item {
                                        width: 18; height: 18
                                        IconImage {
                                            id: appIconImg
                                            anchors.fill: parent
                                            implicitSize: 18
                                            source: {
                                                var ic = appCard.modelData.icon || "";
                                                var entry = DesktopEntries.byId(ic) || DesktopEntries.byId(appCard.modelData.name);
                                                return entry ? Quickshell.iconPath(entry.icon, "audio-x-generic") : Quickshell.iconPath(ic, "audio-x-generic");
                                            }
                                            visible: false
                                        }
                                        MultiEffect {
                                            anchors.fill: appIconImg
                                            source: appIconImg
                                            saturation: -1.0
                                            colorization: 0.85
                                            colorizationColor: Theme.accent
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: appCard.modelData.name + (appCard.modelData.streams.length > 1 ? " (" + appCard.modelData.streams.length + ")" : "")
                                        font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.fg
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: Math.round(appCard.groupVol * 100) + "%"
                                        font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 11; color: Theme.fgMuted
                                    }

                                    // Кнопка раскрытия списка вкладок/потоков
                                    Rectangle {
                                        visible: appCard.hasChildren
                                        width: 24; height: 24
                                        radius: Theme.r(expM.pressed ? 6 : 12)
                                        scale: expM.pressed ? 0.90 : (expM.containsMouse ? 1.08 : 1.0)
                                        color: expM.containsMouse ? Theme.bgElevated : "transparent"
                                        Behavior on scale { SpringAnimation { spring: 4.5; damping: 0.25; epsilon: 0.005 } }
                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            font.family: Theme.iconFont; font.pixelSize: 10
                                            color: appCard.expanded ? Theme.accent : Theme.fgMuted
                                            rotation: appCard.expanded ? 180 : 0
                                            Behavior on rotation { SpringAnimation { spring: 4.2; damping: 0.26; epsilon: 0.5 } }
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            id: expM
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: win.toggleExpand(appCard.modelData.name)
                                        }
                                    }
                                }

                                // Общий ползунок приложения
                                WavySlider {
                                    Layout.fillWidth: true
                                    value: appCard.groupVol
                                    onMoved: v => {
                                        win.isInteracting = true;
                                        appCard.groupVol = v;
                                        var pct = Math.round(v * 100) + "%";
                                        var st = appCard.modelData.streams || [];
                                        for (var i = 0; i < st.length; i++) {
                                            var ids = st[i].ids || [];
                                            for (var j = 0; j < ids.length; j++) {
                                                Quickshell.execDetached(["pactl", "set-sink-input-volume", String(ids[j]), pct]);
                                            }
                                        }
                                        interactTimer.restart();
                                    }
                                }

                                // Выпадающий список вкладок / аудиопотоков
                                ColumnLayout {
                                    visible: appCard.expanded
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    spacing: 6

                                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle }

                                    Repeater {
                                        model: appCard.expanded ? appCard.modelData.streams : []
                                        delegate: Rectangle {
                                            id: stItem
                                            required property var modelData
                                            property real streamVol: modelData.vol
                                            onModelDataChanged: if (!win.isInteracting) streamVol = modelData.vol

                                            Layout.fillWidth: true
                                            implicitHeight: 50
                                            radius: Theme.r(10)
                                            color: stHover.hovered ? Theme.bgElevated : Theme.bgSurface
                                            Behavior on color { ColorAnimation { duration: 140 } }
                                            HoverHandler { id: stHover }

                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: 8; spacing: 3
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: 6
                                                    Text {
                                                        text: ""
                                                        font.family: Theme.iconFont; font.pixelSize: 11; color: Theme.accentWarm
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: stItem.modelData.name
                                                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.fg
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: Math.round(stItem.streamVol * 100) + "%"
                                                        font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.fgMuted
                                                    }
                                                }
                                                WavySlider {
                                                    Layout.fillWidth: true
                                                    value: stItem.streamVol
                                                    onMoved: v => {
                                                        win.isInteracting = true;
                                                        stItem.streamVol = v;
                                                        var ids = stItem.modelData.ids || [];
                                                        var pct = Math.round(v * 100) + "%";
                                                        for (var j = 0; j < ids.length; j++) {
                                                            Quickshell.execDetached(["pactl", "set-sink-input-volume", String(ids[j]), pct]);
                                                        }
                                                        interactTimer.restart();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: win.appGroups.length === 0
                        text: "Нет активных аудиопотоков"
                        font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12; color: Theme.fgMuted
                    }
                }
            }

            // Вкладка 2: Источники (Вывод + Ввод)
            Flickable {
                visible: win.tabIndex === 1
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(410, srcCol.implicitHeight)
                contentHeight: srcCol.implicitHeight
                clip: true
                interactive: contentHeight > height
                OverscrollStretch {}

                ColumnLayout {
                    id: srcCol
                    width: parent.width
                    spacing: 6

                    Text {
                        text: "Устройства вывода"
                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.fgMuted
                    }

                    Repeater {
                        model: win.audioSinks
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Theme.r(12)
                            color: modelData.def ? Theme.accent : (sinkM.containsMouse ? Theme.bgPillHover : Theme.bgPill)
                            Behavior on color { ColorAnimation { duration: 150 } }

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
                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.fgMuted
                    }

                    Repeater {
                        model: win.audioSources
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Theme.r(12)
                            color: modelData.def ? Theme.accent : (srcM.containsMouse ? Theme.bgPillHover : Theme.bgPill)
                            Behavior on color { ColorAnimation { duration: 150 } }

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
