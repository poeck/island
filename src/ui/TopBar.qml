// PanelWindow is provided by the Wayland backend at runtime.
// qmllint disable uncreatable-type
import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Wayland
import "../core"

PanelWindow {
    id: root
    readonly property bool trayOpen: tray.expanded
    function trayGeometry() { return tray.geometry(); }
    property bool reserve: false
    property bool selected: false
    property real slideOffset: 0
    property var systemService: null
    property bool systemOpen: false
    signal systemToggle()
    property var audioService: null
    property bool audioOpen: false
    signal audioToggle()
    property bool notificationsAvailable: false
    property bool notificationsOpen: false
    signal notificationsToggle()
    property var bluetoothService: null
    property bool bluetoothOpen: false
    signal bluetoothToggle()
    property var networkService: null
    property bool networkOpen: false
    signal networkToggle()
    property bool weatherAvailable: false
    property bool weatherOpen: false
    signal weatherToggle()
    property bool sessionAvailable: false
    property bool sessionOpen: false
    signal sessionToggle()
    readonly property var barLayout: {
        const result = {};
        for (const key of Object.keys(stats.buttonLayout)) {
            const metric = stats.buttonLayout[key];
            result[key] = {x: stats.x + metric.x, y: root.slideOffset, width: metric.width, height: Theme.barHeight, value: metric.value};
        }
        const controls = {tray: tray, weather: weather, bluetooth: bluetooth, network: network, notifications: notifications, audio: audio, power: power};
        for (const key of Object.keys(controls)) {
            const item = controls[key];
            if (item.visible) result[key] = {x: rightControls.x + item.x, y: root.slideOffset, width: item.width, height: Theme.barHeight};
        }
        return result;
    }
    required property date date
    // Keep the native surface mapped through fullscreen transitions. Only the
    // clipped contents move, so compositor map/unmap fades cannot replace motion.
    visible: selected
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight + Theme.cornerRadius
    color: "transparent"
    exclusiveZone: reserve ? Theme.barHeight : 0
    mask: Region {
        Region {
            x: rightControls.x; y: root.slideOffset
            width: root.selected && root.slideOffset === 0 ? rightControls.width : 0
            height: root.selected && root.slideOffset === 0 ? Theme.barHeight : 0
        }
        Region {
            x: stats.x; y: root.slideOffset
            width: stats.active ? stats.width : 0
            height: stats.active ? Theme.barHeight : 0
        }
    }
    WlrLayershell.namespace: "island-bar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: tray.keyboardWanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Item {
        anchors.fill: parent
        clip: true
        Item {
            y: root.slideOffset
            width: parent.width; height: parent.height
            Rectangle {
                width: parent.width; height: Theme.barHeight
                color: Theme.background
                Label {
                    anchors.centerIn: parent
                    text: Qt.formatTime(root.date, "HH:mm")
                    font.pixelSize: Theme.compactClockSize
                    font.weight: Theme.weightSemibold
                    font.features: Theme.numeric
                }
                SystemStats {
                    id: stats
                    x: Theme.barEdgeMargin
                    service: root.systemService
                    selected: root.systemOpen
                    active: root.selected && root.slideOffset === 0
                    maximumWidth: (parent.width - Theme.clockWidth) / 2 - 24
                    onToggle: root.systemToggle()
                }
                Row {
                    id: rightControls
                    anchors { right: parent.right; rightMargin: Theme.barEdgeMargin }
                    height: Theme.barHeight
                    spacing: Theme.barControlSpacing
                    SystemTrayView {
                        id: tray
                        active: root.selected && root.slideOffset === 0
                    }
                    BarButton {
                        id: weather
                        iconName: "weather-partly"
                        visible: root.weatherAvailable; enabled: root.selected && root.slideOffset === 0
                        selected: root.weatherOpen
                        Accessible.name: "Weather"
                        onClicked: root.weatherToggle()
                    }
                    BluetoothIndicator {
                        id: bluetooth
                        service: root.bluetoothService
                        selected: root.bluetoothOpen
                        enabled: root.selected && root.slideOffset === 0
                        onClicked: root.bluetoothToggle()
                    }
                    NetworkIndicator {
                        id: network
                        service: root.networkService
                        selected: root.networkOpen
                        enabled: root.selected && root.slideOffset === 0
                        onClicked: root.networkToggle()
                    }
                    NotificationIndicator {
                        id: notifications
                        visible: root.notificationsAvailable
                        selected: root.notificationsOpen
                        enabled: root.selected && root.slideOffset === 0
                        onClicked: root.notificationsToggle()
                    }
                    AudioIndicator {
                        id: audio
                        service: root.audioService
                        selected: root.audioOpen
                        enabled: root.selected && root.slideOffset === 0
                        onClicked: root.audioToggle()
                    }
                    BarButton {
                        id: power
                        iconName: "power"
                        visible: root.sessionAvailable
                        selected: root.sessionOpen
                        enabled: root.selected && root.slideOffset === 0
                        Accessible.name: "Session controls"
                        onClicked: root.sessionToggle()
                    }
                }
            }
            CornerCutouts { anchors.fill: parent; topInset: Theme.barHeight; bottomVisible: false }
        }
    }
}
