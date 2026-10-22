import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import "../core"
import "../core/Bluetooth.js" as Format

Item {
    id: root
    property bool demo: false
    property var backend: demo ? simulated : Bluetooth
    DemoBluetoothBackend { id: simulated }
    property bool expanded: false
    readonly property var adapters: backend.adapters.values
    property string selectedAdapterId: ""
    readonly property var adapter: adapters.find(a => a.adapterId === selectedAdapterId) || backend.defaultAdapter || adapters[0] || null
    readonly property var devices: adapter ? Format.sorted(adapter.devices.values) : []
    readonly property var connected: devices.filter(d => d.connected)
    property var selectedDevice: null
    property var prompt: null
    property string error: ""
    property string notice: ""
    property var pending: null
    property var queued: null
    property var scans: []
    property bool ready: false
    property bool bridgeWanted: false
    property int sequence: 0
    readonly property bool busy: pending !== null
    readonly property bool powered: !!adapter && adapter.enabled
    readonly property bool blocked: !!adapter && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool transitioning: !!adapter && [BluetoothAdapterState.Enabling,BluetoothAdapterState.Disabling].includes(adapter.state)
    readonly property bool scanning: !!adapter && scans.includes(adapter.dbusPath)
    readonly property string status: !adapter ? "No Bluetooth adapter" : blocked ? "Hardware blocked" : transitioning ? "Changing power…" : !powered ? "Bluetooth off" : connected.length ? connected.length + (connected.length === 1 ? " device connected" : " devices connected") : "Ready to connect"
    function name(device) { return Format.name(device); }
    function icon(device) { return Format.icon(device); }
    function battery(device) { return Format.battery(device); }
    function deviceStatus(device) {
        if (pending && pending.path === device.dbusPath) return pending.action === "pair" ? "Pairing…" : pending.action === "connect" ? "Connecting…" : pending.action === "disconnect" ? "Disconnecting…" : Format.status(device);
        return Format.status(device);
    }
    function selectAdapter(index) {
        if (busy || !adapters[index]) return;
        if (scanning) send("stop-scan", adapter);
        selectedAdapterId = adapters[index].adapterId;
        selectedDevice = null; error = ""; notice = "";
    }
    function send(action, target, value) {
        if (!expanded || busy || !target) return;
        if (![...adapters, ...devices].includes(target)) return;
        error = ""; notice = "";
        pending = {id: ++sequence, action: action, path: target.dbusPath, value: value === undefined ? null : value};
        if (demo) { simulated.request(pending); return; }
        if (ready) daemon.write(JSON.stringify(pending) + "\n");
        else { queued = pending; if (!daemon.running) bridgeWanted = true; }
    }
    function power() { if (!blocked && !transitioning) send("power", adapter, !powered); }
    function scan() { if (powered) send(scanning ? "stop-scan" : "scan", adapter); }
    function visibility() { if (powered) send("visible", adapter, !adapter.discoverable); }
    function activate(device) {
        if (!devices.includes(device) || !powered || busy || device.blocked) return;
        selectedDevice = device;
        send(device.connected ? "disconnect" : device.paired ? "connect" : "pair", device);
    }
    function trust(device) { if (device && device.paired) send("trust", device, !device.trusted); }
    function forget(device) { if (device && device.paired) send("forget", device); }
    function reply(value) {
        if (!prompt) return;
        const request = {action: "reply", token: prompt.token, value: value};
        if (demo) simulated.reply(request);
        else if (ready) daemon.write(JSON.stringify(request) + "\n");
    }
    function cancel() {
        if (demo) simulated.cancel();
        else if (ready) daemon.write(JSON.stringify({action: "cancel"}) + "\n");
        prompt = null;
    }
    function receive(message) {
        if (message.event === "ready") {
            ready = true;
            if (queued) { daemon.write(JSON.stringify(queued) + "\n"); queued = null; }
        } else if (message.event === "scan") scans = message.paths;
        else if (message.event === "prompt") prompt = message;
        else if (message.event === "prompt-clear") prompt = null;
        else if (message.event === "error") { error = message.error; pending = null; queued = null; }
        else if (message.event === "done" && pending && pending.id === message.id) {
            notice = message.ok ? pending.action === "pair" ? "Paired and connected. Automatic reconnect is controlled by Trust." : pending.action === "forget" ? "Device forgotten." : "" : "";
            if (!message.ok) error = message.error;
            pending = null; queued = null; prompt = null;
        }
    }
    onExpandedChanged: {
        if (!expanded) { cancel(); prompt = null; error = ""; notice = ""; }
        bridgeWanted = expanded && !demo;
    }
    onDemoChanged: { bridgeWanted = expanded && !demo; ready = false; queued = null; pending = null; prompt = null; scans = []; error = ""; notice = ""; selectedDevice = null; }
    onDevicesChanged: {
        if (selectedDevice && !devices.includes(selectedDevice)) selectedDevice = null;
        if (pending && ![...adapters,...devices].some(o => o.dbusPath === pending.path)) {
            if (pending.action === "forget") notice = "Device forgotten.";
            else { cancel(); error = "The device or adapter was removed."; }
            pending = null; queued = null;
        }
    }
    Connections { target: simulated; function onMessage(value) { if (root.demo) root.receive(value); } }
    Process {
        id: daemon
        command: [Settings.executable, "internal", "bluetooth-bridge"]
        running: root.bridgeWanted && !root.demo
        stdinEnabled: true
        stdout: SplitParser { onRead: data => { try { if (!root.demo) root.receive(JSON.parse(data)); } catch (_) { root.error = "Invalid response from Bluetooth service."; } } }
        // Qt's process exit enum is missing from Quickshell tooling metadata.
        // qmllint disable signal-handler-parameters
        onExited: {
            if (!root.demo) {
                if (root.pending && root.expanded) root.error = "Bluetooth service stopped. Try the action again.";
                root.bridgeWanted = false; root.ready = false; root.pending = null; root.queued = null; root.prompt = null; root.scans = [];
            }
        }
        // qmllint enable signal-handler-parameters
    }
}
