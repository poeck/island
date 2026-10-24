//@ pragma UseQApplication
//@ pragma IconTheme hicolor
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "ui"
import "views"

ShellRoot {
    id: root
    property bool demoAuth: false
    property bool demoLock: false
    property bool demoAudio: false
    property bool demoNetwork: false
    property bool demoWeather: false
    property bool demoBluetooth: false
    readonly property var polkit: polkitLoader.item
    readonly property var askpass: askpassLoader.item
    readonly property bool authActive: !!(polkit && polkit.active) || !!(askpass && askpass.active)
    readonly property var authFlow: polkit && polkit.active ? polkit.flow : askpass ? askpass.flow : null
    onAuthActiveChanged: Qt.callLater(() => stateController.dispatch({type: "auth", value: root.authActive}))
    readonly property bool barShown: !stateController.model.locked && (!desktop.fullscreen || stateController.mode !== "hidden")
    readonly property CapturePool capturePool: previewCaptures.item as CapturePool
    property string lastAction: ""
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Controller { id: stateController }
    DesktopService { id: desktop }
    MediaService { id: mediaService; demo: Settings.showcase }
    AppService { id: applicationService }
    SystemService { id: telemetry; polling: !stateController.model.locked }
    NotificationService {
        id: notices
        blocked: stateController.blocksPopups
        suppressed: stateController.model.locked
        onPopupChanged: Qt.callLater(() => stateController.dispatch({type: "notification", value: notices.popup !== null}))
    }
    AudioService {
        id: sound
        demo: root.demoAudio
        expanded: stateController.model.panel === "audio" && !stateController.model.locked
        onChanged: (kind, value, muted) => { if (stateController.mode !== "audio") stateController.showOsd(kind, value, muted); }
    }
    NetworkService {
        id: networking
        demo: root.demoNetwork
        expanded: stateController.model.panel === "network" && !stateController.model.locked
    }
    BluetoothService {
        id: radios
        demo: root.demoBluetooth
        expanded: stateController.model.panel === "bluetooth" && !stateController.model.locked
    }
    WeatherService {
        id: climate
        demo: root.demoWeather
        expanded: stateController.mode === "weather"
    }
    BacklightService { onChanged: value => stateController.showOsd("brightness", value, false) }
    Connections {
        target: desktop
        function onFullscreenChanged() { stateController.dispatch({type: "fullscreen", value: desktop.fullscreen}); }
    }
    Loader {
        id: polkitLoader; active: Settings.polkitEnabled
        sourceComponent: PolkitService {}
    }
    Loader {
        id: askpassLoader; active: Settings.askpassEnabled
        sourceComponent: AskpassService { blocked: stateController.model.locked || !!(root.polkit && root.polkit.active) }
    }
    Connections {
        target: stateController
        function onModeChanged() {
            if (stateController.mode === "notifications") notices.markRead();
            if (stateController.model.panel !== "audio") root.demoAudio = false;
            if (stateController.model.panel !== "system") telemetry.powerProfiles.demo = false;
            if (stateController.model.panel !== "network") root.demoNetwork = false;
            if (stateController.model.panel !== "weather") root.demoWeather = false;
            if (stateController.model.panel !== "bluetooth") root.demoBluetooth = false;
        }
    }
    function demo(state) {
        if (!Settings.preview) return "Demo commands require preview mode.";
        if (state === "auth") { demoAuth = true; stateController.dispatch({type: "auth", value: true}); }
        else if (state === "notification") notices.demo();
        else if (state === "osd") stateController.showOsd("brightness", 55, false);
        else if (state === "media" || state === "hover") { mediaService.demo = true; stateController.open("media"); }
        else if (state === "weather") { demoWeather = true; stateController.open("weather"); }
        else if (state === "bluetooth") { demoBluetooth = true; stateController.open("bluetooth"); }
        else if (state === "network") { demoNetwork = true; stateController.open("network"); }
        else if (state === "audio") { demoAudio = true; stateController.open("audio"); }
        else if (state === "lock") { demoLock = true; stateController.dispatch({type: "lock", value: true}); }
        else if (state === "compact") {
            demoAuth = false; demoLock = false; stateController.model = ({panel: "", auth: false, locked: false, fullscreen: desktop.fullscreen, barRevealed: false, osd: false, notification: false});
        } else if (["launcher", "notifications", "session", "system", "calendar"].includes(state)) {
            if (state === "launcher") applicationService.query = "";
            if (state === "system") telemetry.powerProfiles.demo = true;
            stateController.toggle(state);
        }
        else return "Unknown demo state.";
        return "ok";
    }
    function sessionAction(action) {
        lastAction = action;
        stateController.dismiss();
        if (Settings.preview) {
            if (action === "lock" || action === "suspend") demo("lock");
            else { console.info("Island preview: would execute", action); stateController.showOsd("check", 100, false); }
            return;
        }
        sessionProcess.command = [Settings.executable, "internal", "session-action", action];
        sessionProcess.running = true;
    }
    Process {
        id: sessionProcess
        stderr: StdioCollector { onStreamFinished: if (text.trim()) { console.error("Island session:", text.trim()); notices.systemError(text.trim()); } }
    }
    Island {
        id: island
        targetScreen: desktop.screen
        chromeOffset: chrome.slideOffset
        controller: stateController; apps: applicationService; media: mediaService; notifications: notices; date: clock.date
        systemService: telemetry
        bluetoothService: radios
        networkService: networking
        audioService: sound
        weatherService: climate
        barWindows: chrome.barWindows
        demoAuth: root.demoAuth; authFlow: root.authFlow
        onSessionAction: action => root.sessionAction(action)
        onCancelDemoAuth: { root.demoAuth = false; stateController.dispatch({type: "auth", value: false}); }
    }
    ScreenChrome {
        id: chrome
        targetScreen: desktop.screen
        shown: root.barShown
        reserve: !desktop.fullscreen
        date: clock.date
        sessionAvailable: true
        sessionOpen: stateController.mode === "session"
        onSessionToggle: stateController.toggle("session")
        systemService: telemetry
        bluetoothService: radios
        networkService: networking
        audioService: sound
        weatherAvailable: true
        weatherOpen: stateController.mode === "weather"
        onWeatherToggle: { root.demoWeather = false; stateController.toggle("weather"); }
        notificationsAvailable: true
        notificationsOpen: stateController.mode === "notifications"
        onNotificationsToggle: stateController.toggle("notifications")
        bluetoothOpen: stateController.mode === "bluetooth"
        onBluetoothToggle: { root.demoBluetooth = false; stateController.toggle("bluetooth"); }
        networkOpen: stateController.mode === "network"
        onNetworkToggle: { root.demoNetwork = false; stateController.toggle("network"); }
        audioOpen: stateController.mode === "audio"
        onAudioToggle: { root.demoAudio = false; stateController.toggle("audio"); }
        systemOpen: stateController.mode === "system"
        onSystemToggle: { telemetry.powerProfiles.demo = false; stateController.toggle("system"); }
    }
    Variants {
        model: Settings.showcase ? Quickshell.screens : []
        delegate: ShowcaseBackdrop { required property var modelData; screen: modelData }
    }
    Loader {
        id: previewCaptures
        active: root.demoLock
        sourceComponent: CapturePool {}
    }
    // The demo never creates a session lock or evaluates credentials.
    Variants {
        model: root.demoLock && previewCaptures.item && (previewCaptures.item as CapturePool).finished ? Quickshell.screens : []
        delegate: LockPreview {
            required property var modelData
            screen: modelData
            date: clock.date
            snapshot: previewCaptures.item ? previewCaptures.item.take(screen) : null
            onDismiss: { root.demoLock = false; stateController.dispatch({type: "lock", value: false}); }
        }
    }
    IpcHandler {
        target: "island"
        function toggle(panel: string): string {
            if (!["launcher", "notifications", "session", "system", "audio", "network", "calendar", "media", "bluetooth", "weather"].includes(panel)) return "Unknown panel";
            if (panel === "system") telemetry.powerProfiles.demo = false;
            if (panel === "media") mediaService.demo = Settings.showcase;
            if (panel === "audio") root.demoAudio = false;
            if (panel === "network") root.demoNetwork = false;
            if (panel === "weather") root.demoWeather = false;
            if (panel === "bluetooth") root.demoBluetooth = false;
            stateController.toggle(panel); return "ok";
        }
        function dismiss(): void { stateController.dismiss(); }
        function toggleBar(): void { stateController.toggleBar(); }
        function dnd(): bool { notices.dnd = !notices.dnd; return notices.dnd; }
        function demo(state: string): string { return root.demo(state); }
        function osd(kind: string, value: real, muted: bool): void {
            if (["volume", "mic", "brightness"].includes(kind)) stateController.showOsd(kind, value, muted);
        }
        function locked(value: bool): void { stateController.dispatch({type: "lock", value: value}); }
        function trayGeometry(): string { return JSON.stringify(chrome.trayGeometry()); }
        function status(): string { return JSON.stringify({mode: stateController.mode, preview: Settings.preview, screen: desktop.screen ? desktop.screen.name : null, windowScreen: island.screen ? island.screen.name : null, shown: island.visible, barShown: root.barShown, barRevealed: stateController.model.barRevealed, fullscreen: desktop.fullscreen, geometry: island.geometry, animating: island.animating || chrome.animating, animationFrames: island.frameCount + chrome.animationFrames, chrome: {offset: chrome.slideOffset, animating: chrome.animating}, settlingMs: island.settledMs, outsideClickRequested: island.grabWanted, outsideClickArmed: island.outsideClickArmed, launcherFocused: island.launcherFocused, query: applicationService.query, history: notices.history.length, dnd: notices.dnd, polkit: root.polkit ? root.polkit.registered : false, askpass: root.askpass ? root.askpass.ready : false, lastAction: root.lastAction, mediaPlaying: mediaService.playing, barLayout: chrome.barLayout, trayCount: chrome.trayCount, trayOpen: chrome.trayOpen, weather: {demo:climate.demo,city:climate.forecastData ? climate.forecastData.location.name : climate.location.name,loaded:climate.forecastData !== null,loading:climate.loading,stale:climate.stale,error:climate.error}, calendar: island.calendarStatus, bluetooth: {demo: root.demoBluetooth, adapters: radios.adapters.length, devices: radios.devices.length, connected: radios.connected.length, powered: radios.powered, scanning: radios.scanning, busy: radios.busy, pairingPrompt: radios.prompt !== null}, network: {demo: root.demoNetwork, available: networking.available, devices: networking.devices.length, connected: networking.activeDevices.length, passwordPrompt: networking.passwordNetwork !== null}, audio: {demo: root.demoAudio, ready: sound.ready, output: sound.sink ? sound.sink.name : null, input: sound.source ? sound.source.name : null, outputs: sound.outputs.length, inputs: sound.inputs.length, applications: sound.applications.length}, powerProfiles: {available:telemetry.powerProfiles.available,profile:telemetry.powerProfiles.profile,profiles:telemetry.powerProfiles.profiles,demo:telemetry.powerProfiles.demo}, system: {cpu: telemetry.snapshot.cpu, memory: telemetry.snapshot.memory, gpu: telemetry.gpu, battery: telemetry.battery, revision: telemetry.revision, historyLength: telemetry.samples.length}, captures: root.capturePool ? Object.keys(root.capturePool.frames).map(k => ({screen:k, ready:root.capturePool.frames[k].hasContent, accepted:root.capturePool.frames[k].accepted})) : []}); }
    }
    Component.onCompleted: {
        Quickshell.watchFiles = Settings.preview && Quickshell.env("ISLAND_WATCH") !== "0";
        stateController.dispatch({type: "fullscreen", value: desktop.fullscreen});
        const initial = Quickshell.env("ISLAND_DEMO");
        if (initial) Qt.callLater(() => demo(initial));
    }
}
