import QtQuick
import "../core"
import "../core/SystemFormat.js" as Format

Row {
    id: root
    property var service: null
    property bool active: true
    property bool selected: false
    property real maximumWidth: 400
    signal toggle()
    readonly property bool compact: maximumWidth < Object.keys(readings).reduce((sum,key) => sum + fullWidth(key) + 2, -2)
    function fullWidth(key) { return key === "battery" ? 68 : key === "disk" ? 104 : 92; }
    readonly property var buttonLayout: {
        const layout = {};
        let left = 0;
        for (const key of Object.keys(readings)) {
            const w = compact ? 68 : fullWidth(key);
            layout[key] = {x: left, width: w, value: readings[key].value};
            left += w + spacing;
        }
        return layout;
    }
    readonly property var readings: {
        if (!service) return {};
        const s = service.snapshot, items = {};
        if (s.cpu.name) items.cpu = {icon: "cpu", label: "CPU", value: s.cpu.usage};
        if (s.memory.total) items.memory = {icon: "memory", label: "RAM", value: s.memory.usage};
        if (service.gpu && service.gpu.usage !== null) items.gpu = {icon: "gpu", label: "GPU", value: service.gpu.usage};
        const disk = (s.disks || []).find(item => item.path === "/");
        if (disk && disk.total) items.disk = {icon: "storage", label: "DISK", value: disk.usage};
        if (service.battery) items.battery = {icon: service.battery.charging ? "battery-charging" : "battery", label: "", value: service.battery.percentage, battery: true};
        return items;
    }
    height: Theme.barHeight
    spacing: 2
    Repeater {
        // Keep delegates alive across samples, including an in-progress click.
        model: ["cpu", "memory", "gpu", "disk", "battery"]
        delegate: Rectangle {
            id: button
            required property string modelData
            readonly property var reading: root.readings[modelData] || ({icon: modelData === "disk" ? "storage" : modelData, label: "", value: null})
            visible: !!root.readings[modelData]
            width: root.compact ? 68 : root.fullWidth(modelData)
            y: 3; height: Theme.barHeight - 6
            readonly property color tone: reading.battery && reading.value !== null && reading.value <= 15 ? Theme.error : reading.battery && reading.value !== null && reading.value <= 30 ? Theme.warning : Theme.text
            radius: Theme.radiusSmall
            color: root.selected ? Theme.selection : mouse.containsMouse ? Theme.raised : "transparent"
            enabled: root.active
            Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
            Icon {
                x: 7; anchors.verticalCenter: parent.verticalCenter
                width: 15; height: 15; name: button.reading.icon
                color: button.tone !== Theme.text ? button.tone : root.selected || mouse.containsMouse ? Theme.text : Theme.secondary
            }
            Label {
                x: 27; anchors.verticalCenter: parent.verticalCenter
                visible: !root.compact && !button.reading.battery
                text: button.reading.label; font.pixelSize: Theme.textCaption; font.weight: Theme.weightMedium
                color: Theme.muted
            }
            Label {
                anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                width: 36; horizontalAlignment: Text.AlignRight
                text: Format.percent(button.reading.value)
                font.pixelSize: Theme.textSmall; font.weight: Theme.weightSemibold; font.features: Theme.numeric
                color: button.tone
            }
            MouseArea {
                id: mouse
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle()
            }
        }
    }
}
