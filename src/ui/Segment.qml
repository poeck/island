import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../core"

// One option inside a SegmentedTrack, which draws the selection pill.
// Navigation choices stay grey; set accent for choices that change system state.
Button {
    id: root
    property bool selected: false
    property bool accent: false
    property string iconName: ""
    Layout.fillWidth: true; Layout.preferredWidth: 1
    implicitHeight: 26
    padding: 0; hoverEnabled: true
    font.family: Theme.font; font.pixelSize: Theme.textSmall; font.weight: Theme.weightMedium
    font.styleName: ""
    onFontChanged: Theme.syncFontWeight(root)
    background: Rectangle {
        radius: Theme.radiusSmall
        color: !root.selected && root.hovered ? Theme.raised : "transparent"
        border.color: root.visualFocus ? Theme.focus : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
    }
    contentItem: Item {
        implicitWidth: row.implicitWidth
        Row {
            id: row
            anchors.centerIn: parent; spacing: 6
            Icon {
                visible: root.iconName !== ""; name: root.iconName || "circle"
                width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter
                color: root.selected ? (root.accent ? Theme.accentInk : Theme.text) : root.enabled ? Theme.secondary : Theme.disabled
                Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text; font: root.font; renderType: Text.QtRendering
                color: root.selected ? (root.accent ? Theme.accentInk : Theme.text) : root.enabled ? (root.hovered ? Theme.text : Theme.secondary) : Theme.disabled
                Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
            }
        }
    }
}
