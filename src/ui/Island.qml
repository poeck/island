// PanelWindow is provided by the Wayland backend at runtime.
// qmllint disable uncreatable-type
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../views"

PanelWindow {
    id: window
    required property var targetScreen
    required property var controller
    required property var apps
    required property var media
    required property var notifications
    required property date date
    property var authFlow: null
    property bool demoAuth: false
    property real chromeOffset: 0
    property var systemService: null
    property var bluetoothService: null
    property var networkService: null
    property var weatherService: null
    property var audioService: null
    property var barWindows: []
    signal sessionAction(string action)
    signal cancelDemoAuth()
    readonly property string mode: controller.mode
    readonly property bool inlineOsd: controller.interactive && controller.model.osd
    readonly property var dimensions: Theme.dimensions[mode] || Theme.dimensions.compact
    readonly property real targetWidth: Math.min(dimensions[0], Math.max(Theme.clockWidth, width - 2 * Theme.notchJoinRadius))
    readonly property int inlineOsdHeight: 40
    readonly property real contentHeight: mode === "auth" ? Math.max(dimensions[1], authView.implicitHeight) : mode === "system" ? systemView.preferredHeight : dimensions[1]
    readonly property real targetHeight: Math.max(0, Math.min(height - Theme.barHeight - 24, contentHeight + (inlineOsd ? inlineOsdHeight : 0) + (mode === "notification" && notifications.popup && notifications.popup.actions.length ? 38 : 0)))
    // Height of a panel without the inline OSD strip beneath it.
    readonly property real panelHeight: targetHeight - (inlineOsd ? inlineOsdHeight : 0)
    readonly property real joinRadius: Math.max(0, Math.min(motion.valueShoulderRadius, silhouette.height, (width - silhouette.width) / 2))
    readonly property var geometry: ({x: silhouette.x, y: silhouette.y, width: silhouette.width, height: silhouette.height, radius: silhouette.radius, joinRadius: joinRadius, barHeight: Theme.barHeight})
    readonly property real expansion: Math.max(0, Math.min(1, motion.valueHeight / Theme.dimensions.media[1]))
    readonly property int frameCount: motion.frameCount
    readonly property int settledMs: motion.settledMs
    readonly property bool animating: motion.running
    readonly property var calendarStatus: ({month: Qt.formatDate(calendarView.displayedMonth,"yyyy-MM"), selected: Qt.formatDate(calendarView.selectedDate,"yyyy-MM-dd"), time: Qt.formatTime(calendarView.now,"HH:mm:ss"), date: Qt.formatDate(calendarView.now,"yyyy-MM-dd"), ticking: calendarView.active})
    readonly property bool launcherFocused: launcherView.inputFocused
    // The focus-grab protocol belongs to the connected Wayland compositor. It
    // does not require Hyprland's IPC environment variable (launchers and user
    // services do not always inherit that variable).
    readonly property bool grabWanted: controller.interactive && !controller.model.auth
    readonly property bool outsideClickArmed: grab.active
    property bool grabIncludesBar: false
    onOutsideClickArmedChanged: {
        if (outsideClickArmed) barGrabArm.restart();
        else { barGrabArm.stop(); grabIncludesBar = false; }
    }
    onGrabWantedChanged: {
        if (grabWanted) grabArm.restart();
        else { grabArm.stop(); grab.active = false; }
    }
    implicitWidth: screen ? Math.min(screen.width, 920) : 920
    implicitHeight: screen ? Math.min(screen.height, 620) : 620
    anchors.top: true
    visible: false
    onTargetScreenChanged: { visible = false; relocation.restart(); }
    Component.onCompleted: relocation.restart()
    // A layer-shell surface's output is fixed at creation. Remap only on output
    // handover; all normal morphs keep this same native surface alive.
    Timer {
        id: relocation; interval: 1
        onTriggered: { window.screen = window.targetScreen; window.visible = window.targetScreen !== null; }
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "island"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive layer focus also traps pointer hit-testing in Hyprland, so an
    // outside press can never reach the focus grab's dismissal path. Bootstrap
    // keyboard focus until the grab takes over, then let that grab own focus.
    // Authentication and compositors without this protocol retain exclusivity.
    WlrLayershell.keyboardFocus: !controller.interactive ? WlrKeyboardFocus.None
        : controller.model.auth || !window.outsideClickArmed ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.OnDemand
    mask: NotchRegion {
        bodyX: silhouette.x; bodyWidth: silhouette.width; bodyHeight: silhouette.height
        bottomRadius: silhouette.radius; joinRadius: window.joinRadius
        topOffset: window.chromeOffset
        active: window.mode !== "hidden"
    }
    SpringGeometry {
        id: motion
        targetWidth: window.targetWidth
        targetHeight: window.targetHeight
        targetRadius: window.dimensions[2]
        targetShoulderRadius: Math.min(Theme.notchJoinRadius, window.dimensions[2])
        reducedMotion: Settings.reducedMotion
    }

    HyprlandFocusGrab {
        id: grab
        // Start with the island so keyboard focus cannot land on the bar while
        // its exclusive layer focus is being released. Whitelist the bar once
        // that handover has committed; the focused island stays in the grab.
        windows: window.grabIncludesBar ? [window, ...window.barWindows] : [window]
        onCleared: if (window.grabWanted) window.controller.dismiss()
    }
    // Commit keyboard interactivity before requesting the compositor grab. Grabbing
    // in the same transaction can be immediately cancelled by Hyprland.
    Timer { id: grabArm; interval: 32; onTriggered: if (window.grabWanted) grab.active = true }
    Timer { id: barGrabArm; interval: 64; onTriggered: if (window.grabWanted && grab.active) window.grabIncludesBar = true }
    Item {
        x: (window.width - width) / 2; y: window.chromeOffset
        width: Theme.clockWidth; height: Theme.barHeight
        enabled: window.mode !== "hidden" && !window.controller.model.auth
        TapHandler {
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onTapped: window.controller.toggle("calendar")
        }
    }
    RectangularShadow {
        anchors.fill: silhouette
        visible: silhouette.opacity > 0 && silhouette.height > 0
        offset: Qt.vector2d(0, 3 + 9 * window.expansion)
        radius: silhouette.radius
        blur: 8 + 22 * window.expansion
        spread: 2 * window.expansion
        color: Qt.alpha(Theme.background, 0.33)
        opacity: silhouette.opacity * window.expansion
    }
    InverseCorner {
        x: silhouette.x - width; y: silhouette.y
        width: window.joinRadius; height: width
        opacity: silhouette.opacity
    }
    InverseCorner {
        x: silhouette.x + silhouette.width; y: silhouette.y
        width: window.joinRadius; height: width
        mirrored: true
        opacity: silhouette.opacity
    }
    Rectangle {
        id: silhouette
        objectName: "islandSilhouette"
        x: (window.width - width) / 2; y: Theme.barHeight + window.chromeOffset
        width: Math.max(0, motion.valueWidth); height: Math.max(0, motion.valueHeight)
        radius: Math.max(0, Math.min(motion.valueRadius, height / 2))
        topLeftRadius: 0; topRightRadius: 0
        color: Theme.background
        opacity: window.mode === "hidden" ? 0 : 1
        visible: opacity > 0
        enabled: window.mode !== "hidden"
        antialiasing: true
        Behavior on opacity { NumberAnimation { duration: Theme.fadeOutDuration } }
        Rectangle {
            id: maskShape
            width: silhouette.width; height: silhouette.height; radius: silhouette.radius
            topLeftRadius: silhouette.topLeftRadius; topRightRadius: silhouette.topRightRadius
            color: "white"; visible: false; layer.enabled: height > 0
        }
        FocusScope {
            id: content
            anchors.fill: parent
            layer.enabled: silhouette.height > 0
            layer.effect: MultiEffect { maskEnabled: true; maskSource: maskShape }
            Keys.onEscapePressed: {
                if (window.demoAuth) window.cancelDemoAuth();
                else if (window.authFlow) window.authFlow.cancelAuthenticationRequest();
                else window.controller.dismiss();
            }
            Reveal {
                shown: window.mode === "weather"
                WeatherView {
                    width: Math.min(Theme.dimensions.weather[0], window.width - 48); height: window.panelHeight; anchors.horizontalCenter: parent.horizontalCenter
                    service: window.weatherService; active: window.mode === "weather"
                    onDismiss: window.controller.dismiss()
                }
            }
            Reveal {
                shown: window.mode === "calendar"
                CalendarView {
                    id: calendarView
                    width: Math.min(Theme.dimensions.calendar[0], window.width - 48); height: window.panelHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    opened: window.controller.model.panel === "calendar"
                    active: window.mode === "calendar"
                    onDismiss: window.controller.dismiss()
                }
            }
            Reveal {
                shown: window.mode === "media"
                MediaView {
                    width: Math.min(Theme.dimensions.media[0], window.width - 48); height: Theme.dimensions.media[1]; anchors.horizontalCenter: parent.horizontalCenter
                    media: window.media; date: window.date
                    active: window.mode === "media"
                }
            }
            Reveal {
                shown: window.mode === "launcher"
                LauncherView {
                    id: launcherView
                    width: Math.min(Theme.dimensions.launcher[0], window.width - 48); height: Math.min(Theme.dimensions.launcher[1], window.height - 94); anchors.horizontalCenter: parent.horizontalCenter
                    apps: window.apps; active: window.mode === "launcher"
                    onDismiss: window.controller.dismiss()
                }
            }
            Reveal {
                shown: window.mode === "notifications"
                HistoryView {
                    width: Math.min(Theme.dimensions.notifications[0], window.width - 48); height: Math.min(Theme.dimensions.notifications[1], window.height - 94); anchors.horizontalCenter: parent.horizontalCenter
                    service: window.notifications
                    active: window.mode === "notifications"
                }
            }
            Reveal {
                shown: window.mode === "system"
                SystemView {
                    id: systemView
                    width: Math.min(Theme.dimensions.system[0], window.width - 48); height: window.panelHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    service: window.systemService
                    active: window.mode === "system"
                    onDismiss: window.controller.dismiss()
                }
            }
            Reveal {
                shown: window.mode === "bluetooth"
                BluetoothView {
                    width: Math.min(Theme.dimensions.bluetooth[0], window.width - 48); height: window.panelHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    service: window.bluetoothService
                    active: window.mode === "bluetooth"
                    onDismiss: window.controller.dismiss()
                }
            }
            Reveal {
                shown: window.mode === "network"
                NetworkView {
                    width: Math.min(Theme.dimensions.network[0], window.width - 48); height: window.panelHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    service: window.networkService
                    active: window.mode === "network"
                    onDismiss: window.controller.dismiss()
                }
            }
            Reveal {
                shown: window.mode === "audio"
                AudioView {
                    width: Math.min(Theme.dimensions.audio[0], window.width - 48); height: window.panelHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    service: window.audioService
                    demo: window.audioService ? window.audioService.demo : false
                    active: window.mode === "audio"
                    onDismiss: window.controller.dismiss()
                }
            }
            Reveal {
                shown: window.mode === "notification"
                NotificationView {
                    width: Math.min(Theme.dimensions.notification[0], window.width - 48); height: window.targetHeight; anchors.horizontalCenter: parent.horizontalCenter
                    notification: window.notifications.popup; service: window.notifications
                }
            }
            Reveal {
                shown: window.mode === "osd"
                OsdView {
                    width: Math.min(Theme.dimensions.osd[0], window.width - 48); height: Theme.dimensions.osd[1]; anchors.horizontalCenter: parent.horizontalCenter
                    value: window.controller.osd
                }
            }
            Reveal {
                shown: window.mode === "session"
                SessionView {
                    width: Math.min(Theme.dimensions.session[0], window.width - 48); height: Theme.dimensions.session[1]; anchors.horizontalCenter: parent.horizontalCenter
                    active: window.mode === "session"
                    onExecute: action => window.sessionAction(action)
                }
            }
            Reveal {
                shown: window.mode === "auth"
                AuthView {
                    id: authView
                    width: Math.min(Theme.dimensions.auth[0], window.width - 48); height: window.panelHeight; anchors.horizontalCenter: parent.horizontalCenter
                    flow: window.authFlow; demo: window.demoAuth; active: window.mode === "auth"
                    onDemoFinished: window.cancelDemoAuth()
                }
            }
            Reveal {
                shown: window.inlineOsd
                OsdView {
                    width: window.targetWidth; height: window.inlineOsdHeight; y: window.targetHeight - window.inlineOsdHeight
                    value: window.controller.osd; compact: true
                }
            }
        }
    }
}
