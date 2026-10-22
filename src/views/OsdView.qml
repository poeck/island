import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

Item {
    id: root
    required property var value
    property bool compact: false
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: root.compact ? 26 : 20; anchors.rightMargin: root.compact ? 26 : 20; spacing: 14
        Icon { name: root.value.kind === "volume" ? root.value.muted ? "muted" : "volume" : root.value.kind; Layout.preferredWidth: 16; Layout.preferredHeight: 16; color: root.value.muted ? Theme.muted : Theme.text }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 4; radius: 2; color: Theme.track
            Rectangle {
                width: Math.max(parent.height, parent.width * Math.min(root.value.value, 100) / 100); height: parent.height; radius: 2
                color: root.value.muted ? Theme.muted : Theme.accent
                Behavior on width { NumberAnimation { duration: Settings.reducedMotion ? 0 : 120; easing.type: Easing.OutCubic } }
            }
        }
        Label {
            Layout.preferredWidth: root.value.kind === "check" ? 56 : root.value.muted ? 44 : 40; horizontalAlignment: Text.AlignRight
            text: root.value.kind === "check" ? "Preview" : root.value.muted ? "Muted" : Math.round(root.value.value) + "%"
            color: Theme.secondary; font.pixelSize: Theme.textSmall; font.weight: Theme.weightMedium; font.features: Theme.numeric
        }
    }
}
