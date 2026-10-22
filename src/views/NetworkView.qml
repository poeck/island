import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Networking
import "../core"
import "../core/Network.js" as Format
import "../ui"

FocusScope {
    id: root
    required property var service
    property bool active: false
    signal dismiss()
    readonly property var prompt: service ? service.passwordNetwork : null
    onActiveChanged: {
        password.clear();
        if (active) Qt.callLater(() => { if (root.prompt) password.forceActiveFocus(); else root.forceActiveFocus(); });
    }
    onPromptChanged: { password.clear(); if (prompt && active) Qt.callLater(() => password.forceActiveFocus()); }
    function submit() { const value = password.text; password.clear(); if (root.service) root.service.submitPassword(value); }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.contentMargin; spacing: 10
        ViewHeader {
            title: "Network"; preview: !!root.service && root.service.demo
            Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: Theme.accent; visible: !!root.service && root.service.activeDevices.length > 0 }
            Label { text: root.service ? root.service.connectivity : "Unavailable"; font.pixelSize: Theme.textSmall; color: Theme.secondary; Layout.rightMargin: 4 }
            IconButton { visible: !!root.service && !!root.service.editor && !root.service.demo; iconName: "settings"; hint: "Open advanced network settings"; onClicked: root.service.openEditor() }
            IconButton { iconName: "close"; hint: "Close network controls"; onClicked: root.dismiss() }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.topMargin: 4; spacing: 10
            Card {
                Layout.fillWidth: true; Layout.preferredWidth: 390; Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 28; Layout.leftMargin: 4; Layout.rightMargin: 2; spacing: 8
                        Icon { name: "wifi"; color: root.service && root.service.wifiEnabled ? Theme.text : Theme.secondary; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                        Label { text: "Wi-Fi"; font.weight: Theme.weightSemibold; Layout.fillWidth: true }
                        Toggle {
                            objectName: "networkWifiToggle"
                            active: !!root.service && root.service.wifiEnabled
                            Accessible.name: "Wi-Fi"
                            enabled: !!root.service && root.service.available && root.service.wifiDevices.length > 0 && root.service.wifiHardwareEnabled && !root.service.busy
                            onClicked: root.service.setWifi(!root.service.wifiEnabled)
                        }
                    }
                    Label {
                        Layout.fillWidth: true; Layout.leftMargin: 4; Layout.bottomMargin: 4; font.pixelSize: Theme.textCaption; color: root.service && root.service.available && root.service.wifiDevices.length && !root.service.wifiHardwareEnabled ? Theme.warning : Theme.muted
                        text: !root.service || !root.service.available ? "NetworkManager is not running" : !root.service.wifiDevices.length ? "No wireless adapter" : !root.service.wifiHardwareEnabled ? "Wi-Fi is disabled by a hardware switch" : !root.service.wifiEnabled ? "Wireless is turned off" : "Select a network to connect"
                    }
                    ListView {
                        id: wireless
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                        model: root.service && root.service.wifiEnabled ? root.service.wifiNetworks : []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: NetworkRow {
                            required property var modelData
                            width: wireless.width
                            objectName: "networkWifi-" + modelData.name
                            selected: modelData.connected
                            title: modelData.name
                            subtitle: (modelData.connected ? "Connected" : modelData.known ? "Saved" : root.service.securityName(modelData)) + " · " + modelData.device.name
                            trailing: modelData.stateChanging || root.service.pendingNetwork === modelData ? "Connecting…" : modelData.connected ? "✓  " + Format.signal(modelData.signalStrength) + "%" : Format.signal(modelData.signalStrength) + "%" + (root.service.secured(modelData) ? "  •" : "")
                            enabled: !root.service.busy && !modelData.stateChanging
                            onClicked: { if (modelData.connected) root.service.disconnectDevice(modelData.device); else root.service.connectNetwork(modelData); }
                        }
                        Label { anchors.centerIn: parent; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.service && root.service.wifiEnabled && root.service.wifiDevices.length ? "Searching for networks…" : ""; visible: wireless.count === 0; color: Theme.secondary; font.pixelSize: Theme.textSmall }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border; visible: root.prompt !== null }
                    ColumnLayout {
                        visible: root.prompt !== null; Layout.fillWidth: true; spacing: 8
                        Label { Layout.fillWidth: true; Layout.leftMargin: 4; Layout.topMargin: 4; text: root.prompt ? "Connect to " + root.prompt.name : ""; font.weight: Theme.weightMedium }
                        Input {
                            id: password; objectName: "networkPassword"
                            Layout.fillWidth: true; placeholderText: "Wi-Fi password"; echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                            Accessible.name: "Wi-Fi password"
                            onAccepted: root.submit()
                            Keys.onEscapePressed: { password.clear(); root.service.passwordNetwork = null; root.forceActiveFocus(); }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            ActionButton { text: "Cancel"; onClicked: { password.clear(); root.service.passwordNetwork = null; root.forceActiveFocus(); } }
                            ActionButton { objectName: "networkConnect"; text: "Connect"; accent: true; enabled: password.text.length > 0 && !root.service.busy; onClicked: root.submit() }
                        }
                    }
                    Label {
                        Layout.fillWidth: true; visible: !!root.service && root.service.activeDevices.some(d => d.type === DeviceType.Wifi)
                        text: {
                            if (!root.service) return "";
                            const device = root.service.activeDevices.find(d => d.type === DeviceType.Wifi);
                            if (!device) return "";
                            const detail = root.service.detail(device);
                            return detail.ipv4.length ? detail.ipv4.join(" · ") + (detail.gateway ? "\nRouter  " + detail.gateway : "") : device.name;
                        }
                        Layout.leftMargin: 4; font.pixelSize: Theme.textCaption; font.features: Theme.numeric; color: Theme.muted; wrapMode: Text.Wrap; maximumLineCount: 3
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 300; Layout.fillHeight: true; spacing: 10
                Card {
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 245
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6
                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredHeight: 28; Layout.leftMargin: 4; spacing: 8
                            Icon { name: "ethernet"; color: Theme.secondary; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                            Label { text: "Ethernet"; font.weight: Theme.weightSemibold; Layout.fillWidth: true }
                        }
                        ListView {
                            id: wired
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                            model: root.service ? root.service.wiredDevices : []
                            ScrollBar.vertical: ScrollBar {}
                            delegate: Column {
                                required property var modelData
                                width: wired.width; spacing: 6
                                readonly property var detail: root.service.detail(modelData)
                                NetworkRow {
                                    width: parent.width; iconName: "ethernet"
                                    objectName: "networkWired-" + parent.modelData.name
                                    selected: parent.modelData.connected
                                    title: parent.modelData.name
                                    subtitle: parent.modelData.connected ? Format.speed(parent.modelData.linkSpeed) + " · connected" : !parent.modelData.hasLink ? "Cable unplugged" : "Cable connected"
                                    trailing: parent.modelData.state === ConnectionState.Connecting ? "Connecting…" : parent.modelData.connected ? "Disconnect" : parent.modelData.hasLink ? "Connect" : ""
                                    enabled: parent.modelData.hasLink && parent.modelData.state !== ConnectionState.Connecting && !root.service.busy
                                    onClicked: { const device = parent.modelData; if (device.connected) root.service.disconnectDevice(device); else if (device.network) root.service.connectNetwork(device.network); }
                                }
                                Label { width: parent.width; leftPadding: 10; visible: parent.modelData.connected; text: parent.detail.ipv4.concat(parent.detail.ipv6).join("\n") || "Obtaining IP address…"; font.pixelSize: Theme.textCaption; font.features: Theme.numeric; color: Theme.muted; wrapMode: Text.Wrap }
                                Label { width: parent.width; leftPadding: 10; visible: parent.modelData.connected && !!parent.detail.gateway; text: "Router " + parent.detail.gateway; font.pixelSize: Theme.textCaption; font.features: Theme.numeric; color: Theme.muted }
                                Label { width: parent.width; leftPadding: 10; visible: parent.modelData.connected && parent.detail.dns.length > 0; text: "DNS " + parent.detail.dns.join(", "); font.pixelSize: Theme.textCaption; font.features: Theme.numeric; color: Theme.muted; wrapMode: Text.Wrap }
                            }
                            Label { anchors.centerIn: parent; text: "No wired adapter"; visible: wired.count === 0; color: Theme.secondary; font.pixelSize: Theme.textSmall }
                        }
                    }
                }
                Card {
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 180
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 6
                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredHeight: 28; Layout.leftMargin: 4; Layout.rightMargin: 4; spacing: 8
                            Icon { name: "shield"; color: Theme.secondary; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                            Label { text: "VPN"; font.weight: Theme.weightSemibold; Layout.fillWidth: true }
                            Label { text: "Saved profiles"; color: Theme.muted; font.pixelSize: Theme.textCaption }
                        }
                        ListView {
                            id: tunnels
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                            model: root.service ? root.service.vpns : []
                            ScrollBar.vertical: ScrollBar {}
                            delegate: NetworkRow {
                                required property var modelData
                                width: tunnels.width; iconName: "shield"
                                objectName: "networkVpn-" + modelData.name
                                title: modelData.name; subtitle: modelData.type === "wireguard" ? "WireGuard" : "VPN"
                                selected: modelData.active
                                trailing: root.service.pendingVpn === modelData.uuid ? "Connecting…" : modelData.active ? "Disconnect" : "Connect"
                                enabled: !root.service.busy
                                onClicked: root.service.toggleVpn(modelData)
                            }
                            Label { anchors.centerIn: parent; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: root.service && !root.service.demo && !root.service.metadata.available ? "VPN profiles unavailable" : "No saved VPNs"; visible: tunnels.count === 0; color: Theme.secondary; font.pixelSize: Theme.textSmall }
                        }
                    }
                }
            }
        }
        Label { Layout.fillWidth: true; visible: text !== ""; text: root.service ? root.service.error : ""; color: Theme.error; font.pixelSize: Theme.textSmall; wrapMode: Text.Wrap; maximumLineCount: 3 }
        Label { Layout.fillWidth: true; Layout.leftMargin: 6; text: "Connections update automatically. Select a connected network to disconnect."; color: Theme.muted; font.pixelSize: Theme.textCaption }
    }
}
