import QtQuick
import Quickshell.Networking

QtObject {
    id: root
    property string name: ""
    property var device: null
    property bool known: false
    property real signalStrength: 0.8
    property int security: WifiSecurityType.Wpa2Psk
    property bool connecting: false
    readonly property bool connected: device && device.current === root
    readonly property int state: connecting ? ConnectionState.Connecting : connected ? ConnectionState.Connected : ConnectionState.Disconnected
    readonly property bool stateChanging: connecting
    signal connectionFailed(int reason)
    function connect() {
        if (device.type === DeviceType.Wifi && !known && security !== WifiSecurityType.Open) { connectionFailed(ConnectionFailReason.NoSecrets); return; }
        connecting = true; completion.restart();
    }
    function connectWithPsk(password) {
        if (password !== "island-demo") { connectionFailed(ConnectionFailReason.NoSecrets); return; }
        known = true; connect();
    }
    function disconnect() { device.disconnect(); }
    property Timer completion: Timer { interval: 350; onTriggered: { root.device.current = root; root.connecting = false; } }
}
