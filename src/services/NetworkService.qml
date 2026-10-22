import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../core"
import "../core/Network.js" as Format

Item {
    id: root
    property bool demo: false
    property var backend: demo ? simulated : Networking
    DemoNetworkBackend { id: simulated }
    property bool expanded: false
    property var metadata: ({available: false, devices: {}, vpns: [], error: ""})
    readonly property bool available: backend.backend !== NetworkBackendType.None && (demo || devices.length > 0 || metadata.available)
    readonly property var devices: backend.devices.values
    readonly property var wifiDevices: devices.filter(d => d.type === DeviceType.Wifi)
    readonly property var wiredDevices: devices.filter(d => d.type === DeviceType.Wired)
    readonly property var networks: devices.reduce((list,d) => list.concat(d.networks.values), [])
    readonly property var wifiNetworks: Format.sorted(wifiDevices.reduce((list,d) => list.concat(d.networks.values), []))
    readonly property var activeDevices: devices.filter(d => d.connected)
    readonly property bool wifiEnabled: backend.wifiEnabled
    readonly property bool wifiHardwareEnabled: backend.wifiHardwareEnabled
    readonly property var vpns: demo ? simulated.vpns : metadata.vpns
    readonly property var editor: DesktopEntries.applications.values.find(e => /(^|[.-])nm-connection-editor($|\.desktop)/.test(e.id)) || null
    readonly property string connectivity: !available ? "NetworkManager unavailable" : backend.connectivity === NetworkConnectivity.Full ? "Internet connected" : backend.connectivity === NetworkConnectivity.Portal ? "Sign-in required" : backend.connectivity === NetworkConnectivity.Limited ? "Limited connectivity" : activeDevices.length ? "Connected · internet unverified" : "Offline"
    readonly property string icon: activeDevices.some(d => d.type === DeviceType.Wired) ? "ethernet" : activeDevices.length ? "wifi" : "network-off"
    property string error: ""
    property var passwordNetwork: null
    property var pendingNetwork: null
    property string pendingVpn: ""
    readonly property bool busy: pendingNetwork !== null || pendingVpn !== ""
    function isPsk(network) { return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security); }
    function secured(network) { return ![WifiSecurityType.Open, WifiSecurityType.Owe].includes(network.security); }
    function securityName(network) {
        return network.security === WifiSecurityType.Open ? "Open network" : network.security === WifiSecurityType.Owe ? "Enhanced open" : isPsk(network) ? network.security === WifiSecurityType.Sae ? "WPA3" : "WPA / WPA2" : "Enterprise / other";
    }
    function detail(device) { return (demo ? simulated.details : metadata.devices)[device.name] || {ipv4: [], ipv6: [], dns: [], gateway: ""}; }
    function networkName(device) { const n = device.networks.values.find(n => n.connected); return n ? n.name : device.type === DeviceType.Wired ? "Ethernet" : "Wi-Fi"; }
    function connectNetwork(network) {
        if (!networks.includes(network) || network.stateChanging || busy) return;
        error = "";
        if (network.device.type === DeviceType.Wifi && !wifiEnabled) return;
        if (network.device.type === DeviceType.Wifi && !network.known && secured(network)) {
            if (isPsk(network)) passwordNetwork = network;
            else error = "Configure this network's identity and certificates in your network editor first.";
            return;
        }
        startConnection(network, "");
    }
    function startConnection(network, password) {
        if (!networks.includes(network) || busy) return;
        pendingNetwork = network;
        deadline.restart();
        if (password) network.connectWithPsk(password);
        else network.connect();
    }
    function submitPassword(password) {
        const network = passwordNetwork;
        passwordNetwork = null;
        if (!network || !networks.includes(network) || !isPsk(network)) return;
        if (password.length < 8 || (password.length > 63 && !/^[0-9a-fA-F]{64}$/.test(password))) {
            error = "Use 8–63 characters, or a 64-digit hexadecimal key.";
            passwordNetwork = network;
            return;
        }
        error = "";
        startConnection(network, password);
    }
    function disconnectDevice(device) { if (devices.includes(device) && !busy) { error = ""; device.disconnect(); refresh(); } }
    function setWifi(enabled) { if (available && wifiDevices.length && wifiHardwareEnabled && !busy) { error = ""; backend.wifiEnabled = enabled; passwordNetwork = null; } }
    function failed(network, reason) {
        if (network !== pendingNetwork) return;
        pendingNetwork = null; deadline.stop();
        if ((reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout) && isPsk(network)) {
            passwordNetwork = network;
            error = "Could not authenticate. Check the Wi-Fi password and try again.";
        } else error = "Connection failed. Check the network and try again.";
    }
    function refresh() { if (expanded && !demo && !reader.running) reader.running = true; }
    function toggleVpn(profile) {
        if (busy || !vpns.some(p => p.uuid === profile.uuid)) return;
        error = "";
        if (demo) { simulated.vpns = vpns.map(p => Object.assign({}, p, {active: p.uuid === profile.uuid ? !p.active : p.active})); return; }
        pendingVpn = profile.uuid;
        vpn.command = [Settings.executable, "internal", "vpn-action", (profile.active ? "down:" : "up:") + profile.uuid];
        vpn.running = true;
    }
    function openEditor() { if (editor) editor.execute(); }
    onExpandedChanged: {
        if (expanded) refresh();
        else { passwordNetwork = null; error = ""; }
    }
    onDemoChanged: { metadata = {available: false, devices: {}, vpns: [], error: ""}; passwordNetwork = null; pendingNetwork = null; deadline.stop(); Qt.callLater(refresh); }
    onNetworksChanged: {
        if (passwordNetwork && !networks.includes(passwordNetwork)) passwordNetwork = null;
        if (pendingNetwork && !networks.includes(pendingNetwork)) { pendingNetwork = null; deadline.stop(); error = "The network or adapter was disconnected."; }
    }
    Repeater {
        model: root.wifiDevices
        delegate: Item {
            required property var modelData
            Binding { target: modelData; property: "scannerEnabled"; value: root.expanded && root.wifiEnabled }
        }
    }
    Repeater {
        model: root.networks
        delegate: Item {
            required property var modelData
            Connections {
                target: modelData
                function onConnectionFailed(reason) { root.failed(modelData, reason); }
                function onConnectedChanged() {
                    if (modelData.connected && root.pendingNetwork === modelData) { root.pendingNetwork = null; deadline.stop(); root.passwordNetwork = null; root.error = ""; }
                    root.refresh();
                }
            }
        }
    }
    Timer { id: deadline; interval: 30000; onTriggered: { root.pendingNetwork = null; root.error = "Connection timed out. Check the network and try again."; } }
    Timer { interval: 5000; repeat: true; running: root.expanded && !root.demo; onTriggered: root.refresh() }
    Process {
        id: reader
        command: [Settings.executable, "internal", "network-snapshot"]
        stdout: StdioCollector { onStreamFinished: { try { if (!root.demo) root.metadata = JSON.parse(text); } catch (_) { if (!root.demo) root.metadata = {available: false, devices: {}, vpns: [], error: "Could not read connection details."}; } } }
    }
    Process {
        id: vpn
        stdout: StdioCollector { onStreamFinished: { try { const result = JSON.parse(text); if (!result.ok) root.error = result.error; } catch (_) { root.error = "VPN request failed."; } } }
        // Qt process exit enum is absent from Quickshell tooling metadata.
        // qmllint disable signal-handler-parameters
        onExited: { root.pendingVpn = ""; root.refresh(); }
        // qmllint enable signal-handler-parameters
    }
}
