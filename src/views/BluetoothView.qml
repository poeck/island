import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../core"
import "../ui"

FocusScope {
    id: root
    required property var service
    property bool active: false
    signal dismiss()
    readonly property var adapter: service ? service.adapter : null
    readonly property var device: service ? service.selectedDevice : null
    readonly property var prompt: service ? service.prompt : null
    readonly property bool inputRequired: prompt && ["pin","passkey"].includes(prompt.kind)
    property bool confirmForget: false
    function group(d) { return d.connected ? "Connected" : d.paired ? "Saved" : "Nearby"; }
    function submit() { const value = pin.text; pin.clear(); if (root.service) root.service.reply(value); }
    onDeviceChanged: confirmForget = false
    onPromptChanged: { pin.clear(); if (active && inputRequired) Qt.callLater(() => pin.forceActiveFocus()); }
    onActiveChanged: {
        pin.clear(); confirmForget = false;
        if (active) Qt.callLater(() => { if (root.inputRequired) pin.forceActiveFocus(); else root.forceActiveFocus(); });
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.contentMargin; spacing: 10
        ViewHeader {
            title: "Bluetooth"; preview: !!root.service && root.service.demo
            Label { text: root.service ? root.service.status : "Unavailable"; color: Theme.secondary; font.pixelSize: Theme.textSmall; Layout.rightMargin: 4 }
            IconButton { iconName: "close"; hint: "Close Bluetooth controls"; onClicked: root.dismiss() }
        }
        Card {
            Layout.fillWidth: true; implicitHeight: 58; Layout.topMargin: 4
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                Icon { Layout.preferredWidth: 16; Layout.preferredHeight: 16; name: "bluetooth"; color: root.service && root.service.powered ? Theme.text : Theme.secondary }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Label { Layout.fillWidth: true; text: root.adapter ? root.adapter.name + " · " + root.adapter.adapterId : "No Bluetooth adapter"; font.weight: Theme.weightMedium }
                    Label { Layout.fillWidth: true; text: root.service && root.service.blocked ? "Release the hardware switch to enable Bluetooth" : root.adapter && root.adapter.discoverable ? "Visible to nearby devices for up to 2 minutes" : "Hidden from nearby devices"; color: root.service && root.service.blocked ? Theme.warning : Theme.secondary; font.pixelSize: Theme.textCaption }
                }
                ComboBox {
                    id: adapterPicker
                    visible: !!root.service && root.service.adapters.length > 1
                    implicitWidth: 96; implicitHeight: 28
                    model: root.service ? root.service.adapters : []; textRole: "adapterId"
                    currentIndex: root.service ? root.service.adapters.indexOf(root.adapter) : -1
                    enabled: !!root.service && !root.service.busy
                    font.family: Theme.font; font.pixelSize: Theme.textSmall
                    font.styleName: ""; font.weight: Theme.weightMedium
                    onFontChanged: Theme.syncFontWeight(adapterPicker)
                    palette.buttonText: Theme.text; palette.text: Theme.text; palette.base: Theme.surface; palette.window: Theme.surface; palette.highlight: Theme.selection; palette.highlightedText: Theme.text
                    background: Rectangle { radius: Theme.radiusControl; color: adapterPicker.hovered ? Theme.selection : Theme.raised; border.color: adapterPicker.visualFocus ? Theme.focus : Theme.borderStrong }
                    onActivated: root.service.selectAdapter(currentIndex)
                }
                Toggle {
                    objectName: "bluetoothPower"
                    active: !!root.service && root.service.powered
                    Accessible.name: "Bluetooth power"
                    enabled: !!root.adapter && !!root.service && !root.service.busy && !root.service.blocked && !root.service.transitioning
                    onClicked: root.service.power()
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Card {
                Layout.fillWidth: true; Layout.preferredWidth: 420; Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 28; Layout.leftMargin: 4; spacing: 8
                        Label { text: "Devices"; font.weight: Theme.weightSemibold }
                        Rectangle {
                            visible: !!root.adapter && root.adapter.discovering
                            implicitWidth: 6; implicitHeight: 6; radius: 3; color: Theme.accent
                            SequentialAnimation on opacity {
                                running: !!root.adapter && root.adapter.discovering && !Settings.reducedMotion; loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                        Label { visible: !!root.adapter && root.adapter.discovering; text: "Scanning…"; font.pixelSize: Theme.textSmall; color: Theme.secondary }
                        Item { Layout.fillWidth: true }
                        ActionButton {
                            objectName: "bluetoothScan"; implicitHeight: 26
                            text: root.service && root.service.scanning ? "Stop" : "Scan"; iconName: "search"
                            enabled: !!root.service && root.service.powered && !root.service.busy
                            onClicked: root.service.scan()
                        }
                    }
                    ListView {
                        id: list; objectName: "bluetoothDeviceList"; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 2
                        model: root.service && root.service.powered ? root.service.devices : []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Column {
                            id: row
                            required property var modelData
                            required property int index
                            width: list.width; spacing: 2
                            readonly property bool heading: index === 0 || root.group(modelData) !== root.group(root.service.devices[index-1])
                            Label { visible: row.heading; height: 24; leftPadding: 8; verticalAlignment: Text.AlignBottom; bottomPadding: 4; text: root.group(row.modelData); color: Theme.muted; font.pixelSize: Theme.textCaption; font.weight: Theme.weightMedium }
                            Rectangle {
                                width: row.width; height: 48; radius: Theme.radiusControl
                                color: select.down ? Theme.pressed : root.device === row.modelData ? Theme.selection : select.hovered ? Theme.raised : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
                                Button {
                                    id: select; objectName: "bluetoothSelect-" + row.modelData.address
                                    x: 0; y: 0; width: parent.width - 92; height: parent.height
                                    leftPadding: 10; rightPadding: 6; topPadding: 0; bottomPadding: 0; hoverEnabled: true
                                    Accessible.name: "Details for " + root.service.name(row.modelData)
                                    background: Rectangle { radius: Theme.radiusControl; color: "transparent"; border.color: select.visualFocus ? Theme.focus : "transparent" }
                                    contentItem: RowLayout {
                                        spacing: 10
                                        Icon { name: root.service.icon(row.modelData); color: row.modelData.connected ? Theme.text : Theme.secondary; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Label { Layout.fillWidth: true; text: root.service.name(row.modelData); font.weight: row.modelData.connected ? Theme.weightMedium : Theme.weightRegular }
                                            Label { Layout.fillWidth: true; text: root.service.deviceStatus(row.modelData) + (row.modelData.batteryAvailable ? " · " + root.service.battery(row.modelData) + " battery" : ""); font.pixelSize: Theme.textCaption; font.features: Theme.numeric; color: Theme.secondary }
                                        }
                                    }
                                    onClicked: root.service.selectedDevice = row.modelData
                                }
                                ActionButton {
                                    objectName: "bluetoothAction-" + row.modelData.address
                                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    text: row.modelData.pairing ? "Pairing…" : row.modelData.connected ? "Disconnect" : row.modelData.paired ? "Connect" : "Pair"
                                    implicitWidth: 80; implicitHeight: 26; font.pixelSize: Theme.textCaption
                                    enabled: !root.service.busy && !row.modelData.blocked && [BluetoothDeviceState.Connected,BluetoothDeviceState.Disconnected].includes(row.modelData.state)
                                    onClicked: root.service.activate(row.modelData)
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent; width: parent.width - 24; spacing: 6
                            visible: list.count === 0
                            Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Theme.secondary; font.weight: Theme.weightMedium
                                text: !root.adapter ? "No Bluetooth adapter" : !root.service.powered ? "Bluetooth is off" : "No devices yet" }
                            Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: Theme.textSmall
                                text: !root.adapter ? "Connect an adapter to get started." : !root.service.powered ? "Turn it on to see your devices." : "Put your device in pairing mode, then scan." }
                        }
                    }
                }
            }
            Card {
                Layout.fillWidth: true; Layout.preferredWidth: 270; Layout.fillHeight: true
                Flickable {
                    id: detailsScroll
                    anchors.fill: parent; anchors.margins: 14; clip: true
                    contentWidth: width; contentHeight: Math.max(height, detailLayout.implicitHeight)
                    ScrollBar.vertical: ScrollBar {}
                    ColumnLayout {
                        id: detailLayout
                        width: detailsScroll.width; height: Math.max(implicitHeight, detailsScroll.height); spacing: 8
                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 10; color: Theme.raised; border.color: Theme.border
                            Icon { anchors.centerIn: parent; width: 18; height: 18; name: root.device ? root.service.icon(root.device) : "bluetooth"; color: root.device ? Theme.text : Theme.secondary }
                        }
                        Label { Layout.fillWidth: true; Layout.topMargin: 4; text: root.device ? root.service.name(root.device) : "No device selected"; font.weight: Theme.weightSemibold; wrapMode: Text.Wrap; maximumLineCount: 2 }
                        Label { Layout.fillWidth: true; text: root.device ? root.device.address : "Select a device to see its details."; font.pixelSize: Theme.textCaption; font.features: Theme.numeric; color: Theme.muted; wrapMode: Text.Wrap }
                        Label { visible: !!root.device; text: root.device ? root.service.deviceStatus(root.device) + (root.device.batteryAvailable ? " · Battery " + root.service.battery(root.device) : "") : ""; font.pixelSize: Theme.textSmall; font.features: Theme.numeric; color: Theme.secondary; Layout.fillWidth: true }
                        Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
                        RowLayout {
                            visible: !!root.device && root.device.paired; Layout.fillWidth: true; Layout.preferredHeight: 30
                            Label { text: "Reconnect automatically"; font.pixelSize: Theme.textSmall; Layout.fillWidth: true }
                            Toggle {
                                objectName: "bluetoothTrust"
                                active: !!root.device && root.device.trusted
                                Accessible.name: "Reconnect automatically"
                                enabled: !!root.service && !root.service.busy && root.service.powered
                                onClicked: root.service.trust(root.device)
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredHeight: 30
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Label { text: "Discoverable"; font.pixelSize: Theme.textSmall; Layout.fillWidth: true }
                                Label { text: "For 2 minutes"; font.pixelSize: Theme.textCaption; color: Theme.muted; Layout.fillWidth: true }
                            }
                            Toggle {
                                objectName: "bluetoothVisible"
                                active: !!root.adapter && root.adapter.discoverable
                                Accessible.name: "Discoverable for 2 minutes"
                                enabled: !!root.service && root.service.powered && !root.service.busy
                                onClicked: root.service.visibility()
                            }
                        }
                        ActionButton {
                            objectName: "bluetoothForget"; visible: !!root.device && root.device.paired
                            Layout.fillWidth: true; Layout.topMargin: 4
                            text: root.confirmForget ? "Confirm forget device" : "Forget device"
                            destructive: root.confirmForget
                            enabled: !!root.service && !root.service.busy && root.service.powered
                            onClicked: { if (root.confirmForget) { root.service.forget(root.device); root.confirmForget = false; } else root.confirmForget = true; }
                        }
                    }
                }
            }
        }
        Card {
            visible: root.prompt !== null
            Layout.fillWidth: true; implicitHeight: root.inputRequired ? 116 : 96
            color: Theme.raised; border.color: Theme.borderStrong
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; anchors.leftMargin: 14; spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: root.prompt && root.prompt.kind === "confirm" ? "Does this code match on your device?" : root.prompt && root.prompt.kind === "display" ? "Type this code on your Bluetooth device" : root.prompt && root.prompt.kind === "authorize" ? "Allow this device to pair or use a service?" : root.prompt && root.prompt.kind === "pin" ? "Enter the device's PIN" : "Enter the device's passkey"; Layout.fillWidth: true; font.weight: Theme.weightMedium }
                    IconButton { objectName: "bluetoothPairCancel"; iconName: "close"; hint: "Cancel pairing"; onClicked: root.service.cancel() }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Label { visible: !!root.prompt && ["confirm","display"].includes(root.prompt.kind); text: root.prompt ? root.prompt.code || "" : ""; font.pixelSize: Theme.textDisplay; font.weight: Theme.weightMedium; font.features: Theme.numeric; font.letterSpacing: 4 }
                    Input {
                        id: pin; objectName: "bluetoothPin"; visible: root.inputRequired; Layout.fillWidth: true
                        placeholderText: root.prompt && root.prompt.kind === "pin" ? "PIN (1–16 letters or numbers)" : "Passkey (up to 6 digits)"
                        maximumLength: root.prompt && root.prompt.kind === "pin" ? 16 : 6
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                        Accessible.name: "Bluetooth PIN or passkey"; onAccepted: root.submit()
                    }
                    Item { Layout.fillWidth: true; visible: !root.inputRequired }
                    ActionButton { objectName: "bluetoothPairConfirm"; visible: !root.prompt || root.prompt.kind !== "display"; text: root.inputRequired ? "Pair" : "Confirm"; accent: true; enabled: !root.inputRequired || pin.text.length > 0; onClicked: { if (root.inputRequired) root.submit(); else root.service.reply(true); } }
                }
            }
        }
        Label { Layout.fillWidth: true; visible: text !== ""; text: root.service ? root.service.error || root.service.notice : ""; color: root.service && root.service.error ? Theme.error : Theme.secondary; font.pixelSize: Theme.textSmall; wrapMode: Text.Wrap; maximumLineCount: 2 }
    }
}
