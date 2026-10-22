import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../core"

Card {
    id: root
    required property var service
    property bool input: false
    readonly property var devices: service ? input ? service.inputs : service.outputs : []
    readonly property var selected: service ? input ? service.source : service.sink : null
    readonly property bool available: selected && selected.ready && selected.audio
    readonly property bool muted: available && selected.audio.muted
    function revealSelection() {
        const index = devices.indexOf(selected);
        if (index >= 0) list.positionViewAtIndex(index, ListView.Contain);
    }
    onSelectedChanged: Qt.callLater(revealSelection)
    onDevicesChanged: Qt.callLater(revealSelection)
    implicitHeight: 220
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 6
        RowLayout {
            objectName: root.input ? "audioInputHeader" : "audioOutputHeader"
            Layout.fillWidth: true; Layout.preferredHeight: 32; spacing: 10
            Icon { Layout.preferredWidth: 16; Layout.preferredHeight: 16; Layout.leftMargin: 2; name: root.input ? "mic" : "headphones"; color: Theme.secondary }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Label { Layout.fillWidth: true; text: root.input ? "Input" : "Output"; font.weight: Theme.weightSemibold }
                Label { Layout.fillWidth: true; text: root.service ? root.service.deviceName(root.selected) : "No device connected"; font.pixelSize: Theme.textCaption; color: Theme.secondary }
            }
            Label {
                text: root.available ? Math.round(root.selected.audio.volume * 100) + "%" : "—"
                font.pixelSize: Theme.textTitle; font.weight: Theme.weightSemibold; font.features: Theme.numeric; color: root.muted ? Theme.muted : Theme.text
            }
            IconButton {
                objectName: root.input ? "audioInputMute" : "audioOutputMute"
                enabled: root.available
                iconName: root.input ? root.muted ? "mic-muted" : "mic" : root.muted ? "muted" : "volume"
                accented: root.muted
                hint: (root.muted ? "Unmute " : "Mute ") + (root.input ? "microphone" : "output")
                onClicked: root.service.toggleMute([root.selected])
            }
        }
        VolumeSlider {
            Layout.fillWidth: true
            enabled: root.available; muted: root.muted
            value: root.available ? root.selected.audio.volume : 0
            Accessible.name: root.input ? "Microphone volume" : "Output volume"
            onMoved: root.service.setVolume([root.selected], value)
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 2
            model: root.devices
            ScrollBar.vertical: ScrollBar {}
            delegate: Button {
                id: device
                required property var modelData
                readonly property bool selected: root.selected === modelData
                width: list.width; height: 38
                enabled: modelData.ready
                leftPadding: 8; rightPadding: 8; topPadding: 0; bottomPadding: 0; hoverEnabled: true
                Accessible.name: root.service.deviceName(modelData)
                Accessible.description: selected ? "Selected device" : "Use this device"
                background: Rectangle {
                    radius: Theme.radiusControl
                    color: device.down ? Theme.pressed : device.selected ? Theme.selection : device.hovered ? Theme.raised : "transparent"
                    border.color: device.visualFocus ? Theme.focus : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
                }
                contentItem: RowLayout {
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Label { Layout.fillWidth: true; text: root.service.deviceName(device.modelData); font.pixelSize: Theme.textSmall; font.weight: device.selected ? Theme.weightMedium : Theme.weightRegular; color: device.selected ? Theme.text : Theme.secondary }
                        Label { Layout.fillWidth: true; text: root.service.deviceKind(device.modelData); font.pixelSize: Theme.textCaption; color: Theme.muted }
                    }
                    Icon { Layout.preferredWidth: 14; Layout.preferredHeight: 14; name: "check"; color: Theme.text; visible: device.selected }
                }
                onClicked: root.input ? root.service.selectInput(modelData) : root.service.selectOutput(modelData)
            }
            Label {
                anchors.centerIn: parent; width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; elide: Text.ElideNone
                visible: list.count === 0
                text: root.service && root.service.ready ? root.input ? "No microphone connected" : "No output connected" : "Connecting to audio…"
                font.pixelSize: Theme.textSmall; color: Theme.secondary
            }
        }
    }
}
