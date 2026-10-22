import QtQuick
import QtQuick.Layouts
import "../core"

Card {
    id: root
    required property var service
    readonly property bool available: !!service && service.available
    visible: available
    implicitHeight: layout.implicitHeight + 24
    ColumnLayout {
        id: layout
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 10
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Label { text: "Power profile"; font.weight: Theme.weightSemibold }
            Badge { visible: !!root.service && root.service.demo; text: "Preview" }
            Item { Layout.fillWidth: true }
            Label { text: root.service && root.service.busy ? "Switching…" : root.service ? root.service.title(root.service.profile) : ""; color: Theme.secondary; font.pixelSize: Theme.textSmall }
        }
        SegmentedTrack {
            Layout.fillWidth: true; implicitHeight: 34
            Repeater {
                // Stable delegates preserve a pressed button during status updates.
                model: ["power-saver","balanced","performance"]
                delegate: Segment {
                    id: option
                    required property string modelData
                    readonly property bool supported: !!root.service && root.service.profiles.includes(modelData)
                    objectName: "powerProfile-" + modelData
                    visible: supported
                    Layout.fillHeight: true
                    accent: true
                    selected: root.available && root.service.profile === modelData
                    enabled: root.available && !root.service.busy && !selected && !(modelData === "performance" && root.service.inhibited)
                    iconName: modelData === "power-saver" ? "leaf" : modelData === "performance" ? "performance" : "balance"
                    text: root.service ? root.service.title(modelData) : ""
                    Accessible.name: root.service ? root.service.title(modelData) + (selected ? ", selected" : "") : modelData
                    onClicked: root.service.select(modelData)
                }
            }
        }
        Label {
            Layout.fillWidth: true; visible: text !== ""
            text: root.service ? root.service.notice : ""; wrapMode: Text.Wrap; maximumLineCount: 3
            color: !root.service ? Theme.secondary : root.service.error ? Theme.error : root.service.inhibited || root.service.degraded ? Theme.warning : Theme.secondary
            font.pixelSize: Theme.textCaption
        }
    }
}
