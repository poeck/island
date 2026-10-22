import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../core"
import "../core/SystemFormat.js" as Format
import "../ui"

FocusScope {
    id: root
    required property var service
    property bool active: false
    readonly property var stats: service ? service.snapshot : ({cpu: {}, memory: {}, network: {}, disks: [], gpus: []})
    readonly property var gpu: service ? service.gpu : null
    readonly property var battery: service ? service.battery : null
    // The island sizes itself to the content, which grows with battery and power-profile cards.
    readonly property real preferredHeight: layout.implicitHeight + 2 * Theme.contentMargin
    signal dismiss()
    onActiveChanged: if (active) Qt.callLater(() => { if (root.active) root.forceActiveFocus(); })
    Flickable {
        id: scroll
        anchors.fill: parent; anchors.margins: Theme.contentMargin
        contentHeight: layout.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: layout
            width: scroll.width; spacing: 10
            ViewHeader {
                title: "System"
                Layout.bottomMargin: 4
                Rectangle {
                    implicitWidth: 6; implicitHeight: 6; radius: 3; color: Theme.accent; visible: !!root.service && root.service.revision > 0
                    SequentialAnimation on opacity {
                        running: root.active && !Settings.reducedMotion; loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
                Label { text: "Live · last 60 s"; color: Theme.secondary; font.pixelSize: Theme.textSmall; Layout.rightMargin: 4 }
                IconButton { iconName: "close"; hint: "Close system overview"; onClicked: root.dismiss() }
            }
            PowerProfileCard {
                Layout.fillWidth: true
                service: root.service ? root.service.powerProfiles : null
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2; rowSpacing: 10; columnSpacing: 10
                MetricCard {
                    Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
                    title: "Processor"; iconName: "cpu"
                    value: Format.percent(root.stats.cpu.usage)
                    detail: Format.temperature(root.stats.cpu.temperature)
                    caption: root.stats.cpu.name || "Reading processor…"
                    samples: root.active && root.service ? root.service.history("cpu") : []
                    active: root.active
                }
                MetricCard {
                    Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
                    title: "Memory"; iconName: "memory"
                    value: Format.percent(root.stats.memory.usage)
                    tone: root.stats.memory.usage >= 90 ? Theme.warning : Theme.text
                    detail: Format.bytes(root.stats.memory.used) + " / " + Format.bytes(root.stats.memory.total)
                    caption: root.stats.memory.swapTotal ? "Swap " + Format.bytes(root.stats.memory.swapUsed) + " / " + Format.bytes(root.stats.memory.swapTotal) : "Swap is disabled"
                    samples: root.active && root.service ? root.service.history("memory") : []
                    active: root.active
                }
                MetricCard {
                    Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
                    title: "Graphics"; iconName: "gpu"
                    value: root.gpu ? Format.percent(root.gpu.usage) : "Unavailable"
                    detail: root.gpu ? Format.temperature(root.gpu.temperature) + (root.gpu.power != null ? " · " + Math.round(root.gpu.power) + " W" : "") : ""
                    caption: root.gpu ? root.gpu.name + (root.gpu.sleeping ? " · Sleeping" : root.gpu.memoryTotal ? " · " + Format.bytes(root.gpu.memoryUsed) + " / " + Format.bytes(root.gpu.memoryTotal) + " VRAM" : root.gpu.usage === null ? " · Usage unavailable" : root.gpu.usageScope === "session" ? " · Session activity" : "") : "No supported graphics device detected"
                    samples: root.active && root.service ? root.service.history("gpu") : []
                    active: root.active
                }
                MetricCard {
                    Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
                    title: "Network"; iconName: "network"
                    value: root.stats.network.download == null ? "—" : "↓ " + Format.bytes(root.stats.network.download) + "/s"
                    detail: root.stats.network.upload == null ? "" : "↑ " + Format.bytes(root.stats.network.upload) + "/s"
                    caption: (root.stats.network.interfaces || []).join(" · ") || "No active interfaces"
                    samples: root.active && root.service ? root.service.history("download") : []
                    maximum: Math.max(1024, ...samples.filter(value => value !== null))
                    active: root.active
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Card {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 104
                    Column {
                        x: 14; y: 13; width: parent.width - 28; spacing: 7
                        Row {
                            spacing: 8
                            Icon { name: "reboot"; width: 14; height: 14; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: "Up " + Format.duration(root.stats.uptime); font.weight: Theme.weightMedium; font.features: Theme.numeric }
                        }
                        Label { width: parent.width; text: root.stats.os || "Linux"; font.pixelSize: Theme.textSmall; color: Theme.secondary }
                        Label { width: parent.width; text: "Kernel " + (root.stats.kernel || "—"); font.pixelSize: Theme.textSmall; color: Theme.secondary }
                        Label { width: parent.width; text: "Load " + (root.stats.cpu.load || []).map(value => value.toFixed(2)).join(" · ") + "  ·  " + (root.stats.cpu.threads || "—") + " threads"; font.pixelSize: Theme.textSmall; font.features: Theme.numeric; color: Theme.secondary }
                    }
                }
                Card {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 104
                    Column {
                        x: 14; y: 13; width: parent.width - 28; spacing: 10
                        Row {
                            spacing: 8
                            Icon { name: "storage"; width: 14; height: 14; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: "Storage"; font.weight: Theme.weightSemibold }
                        }
                        Repeater {
                            model: root.stats.disks || []
                            delegate: Column {
                                id: disk
                                required property var modelData
                                readonly property color tone: modelData.usage >= 90 ? Theme.error : modelData.usage >= 80 ? Theme.warning : Theme.text
                                width: parent.width; spacing: 5
                                RowLayout {
                                    width: parent.width
                                    Label { text: disk.modelData.path; font.pixelSize: Theme.textSmall; Layout.fillWidth: true }
                                    Label { text: Format.bytes(disk.modelData.used) + " / " + Format.bytes(disk.modelData.total) + " · " + Format.percent(disk.modelData.usage); font.pixelSize: Theme.textCaption; font.features: Theme.numeric; color: disk.tone === Theme.text ? Theme.secondary : disk.tone }
                                }
                                Rectangle {
                                    width: parent.width; height: 4; radius: 2; color: Theme.track
                                    Rectangle { width: Math.max(parent.height, parent.width * (disk.modelData.usage || 0) / 100); height: parent.height; radius: 2; color: disk.tone === Theme.text ? Theme.secondary : disk.tone }
                                }
                            }
                        }
                    }
                }
            }
            Card {
                Layout.fillWidth: true; Layout.preferredHeight: 40
                visible: !!root.battery
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 8
                    Icon {
                        name: root.battery && root.battery.charging ? "battery-charging" : "battery"; Layout.preferredWidth: 14; Layout.preferredHeight: 14
                        color: !root.battery || root.battery.charging ? Theme.secondary : root.battery.percentage <= 15 ? Theme.error : root.battery.percentage <= 30 ? Theme.warning : Theme.secondary
                    }
                    Label { text: root.battery ? Format.percent(root.battery.percentage) + (root.battery.charging ? " · Charging" : " · " + root.battery.state) : ""; font.weight: Theme.weightMedium; font.features: Theme.numeric; Layout.fillWidth: true }
                    Label { text: root.battery ? (root.battery.seconds > 0 ? Format.duration(root.battery.seconds) + (root.battery.charging ? " until full" : " remaining") + "  ·  " : "") + root.battery.watts.toFixed(1) + " W" + (root.battery.health !== null ? "  ·  " + Math.round(root.battery.health) + "% health" : "") : ""; font.pixelSize: Theme.textSmall; font.features: Theme.numeric; color: Theme.secondary }
                }
            }
        }
    }
}
