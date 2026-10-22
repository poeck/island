import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../core"

Item {
    id: root
    required property var targetScreen
    required property date date
    property bool shown: true
    property bool reserve: true
    property bool reducedMotion: Settings.reducedMotion
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
    function trayGeometry() { return barWindows.length ? barWindows[0].trayGeometry() : ({items: [], menu: []}); }
    readonly property var barLayout: barWindows.length ? barWindows[0].barLayout : ({})
    readonly property var barWindows: barSurfaces.instances.filter(bar => (bar as TopBar).selected)
    readonly property real slideOffset: Math.max(-Theme.barHeight, Math.min(0, slide.value))
    readonly property bool animating: slide.running
    readonly property int animationFrames: slide.frameCount
    readonly property bool trayOpen: barWindows.some(bar => bar.trayOpen)
    readonly property int trayCount: SystemTray.items.values.filter(item => item.status !== Status.Passive).length
    SpringValue {
        id: slide
        target: root.shown ? 0 : -Theme.barHeight
        reducedMotion: root.reducedMotion
    }
    Variants {
        model: Quickshell.screens
        delegate: ScreenCorners {
            required property var modelData
            screen: modelData
            // The primary top corners belong to the moving bar surface.
            topVisible: modelData !== root.targetScreen
        }
    }
    Variants {
        id: barSurfaces
        model: Quickshell.screens
        delegate: TopBar {
            required property var modelData
            screen: modelData
            selected: modelData === root.targetScreen
            reserve: modelData === root.targetScreen && root.reserve
            slideOffset: root.slideOffset
            date: root.date
            sessionAvailable: root.sessionAvailable
            sessionOpen: root.sessionOpen
            onSessionToggle: root.sessionToggle()
            weatherAvailable: root.weatherAvailable
            weatherOpen: root.weatherOpen
            onWeatherToggle: root.weatherToggle()
            systemService: root.systemService
            systemOpen: root.systemOpen
            onSystemToggle: root.systemToggle()
            notificationsAvailable: root.notificationsAvailable
            notificationsOpen: root.notificationsOpen
            onNotificationsToggle: root.notificationsToggle()
            bluetoothService: root.bluetoothService
            bluetoothOpen: root.bluetoothOpen
            onBluetoothToggle: root.bluetoothToggle()
            networkService: root.networkService
            networkOpen: root.networkOpen
            onNetworkToggle: root.networkToggle()
            audioService: root.audioService
            audioOpen: root.audioOpen
            onAudioToggle: root.audioToggle()
        }
    }
}
