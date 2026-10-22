import QtQuick
import Quickshell.Networking

Item {
    id: root
    property int backend: NetworkBackendType.NetworkManager
    property bool wifiEnabled: true
    property bool wifiHardwareEnabled: true
    property int connectivity: NetworkConnectivity.Full
    property QtObject devices: QtObject { property var values: [lan, wifi] }
    property var vpns: [{uuid: "11111111-1111-1111-1111-111111111111", name: "Work tunnel", type: "wireguard", active: false}, {uuid: "22222222-2222-2222-2222-222222222222", name: "Personal VPN", type: "vpn", active: false}]
    property var details: ({enp5s0: {ipv4: ["192.168.178.24/24"], ipv6: ["fd00::24/64"], gateway: "192.168.178.1", dns: ["192.168.178.1"]}, wlan0: {ipv4: ["192.168.178.116/24"], ipv6: [], gateway: "192.168.178.1", dns: ["192.168.178.1"]}})
    onWifiEnabledChanged: if (!wifiEnabled) wifi.disconnect()
    QtObject {
        id: lan
        property string name: "enp5s0"
        property int type: DeviceType.Wired
        property string address: "00:11:22:33:44:55"
        property bool hasLink: true
        property int linkSpeed: 2500
        property var current: ethernet
        readonly property bool connected: current !== null
        readonly property int state: connected ? ConnectionState.Connected : ConnectionState.Disconnected
        property var network: hasLink ? ethernet : null
        property var networks: ({values: hasLink ? [ethernet] : []})
        onHasLinkChanged: if (!hasLink) disconnect()
        function disconnect() { current = null; }
    }
    QtObject {
        id: wifi
        property string name: "wlan0"
        property int type: DeviceType.Wifi
        property string address: "66:77:88:99:AA:BB"
        property bool scannerEnabled: false
        property var current: home
        readonly property bool connected: current !== null
        readonly property int state: connected ? ConnectionState.Connected : ConnectionState.Disconnected
        property var networks: ({values: [home, studio, guest, enterprise]})
        function disconnect() { current = null; }
    }
    DemoNetwork { id: ethernet; name: "Wired connection"; device: lan; known: true }
    DemoNetwork { id: home; name: "FRITZ!Box 7583 LM"; device: wifi; known: true; signalStrength: 0.84 }
    DemoNetwork { id: studio; name: "Studio"; device: wifi; signalStrength: 0.66; security: WifiSecurityType.Sae }
    DemoNetwork { id: guest; name: "Guest Wi-Fi"; device: wifi; signalStrength: 0.42; security: WifiSecurityType.Open }
    DemoNetwork { id: enterprise; name: "Campus"; device: wifi; signalStrength: 0.28; security: WifiSecurityType.Wpa2Eap }
}
