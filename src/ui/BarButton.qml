import QtQuick
import QtQuick.Controls.Basic
import "../core"

// Status-bar icon button. Open panels read as a pressed grey key; no colour.
Button {
    id: root
    property bool selected: false
    property string iconName: "circle"
    property bool lit: false
    property real dim: 1
    implicitWidth: 30; implicitHeight: Theme.barHeight
    padding: 6; topPadding: 6; bottomPadding: 6; hoverEnabled: true
    background: Rectangle {
        anchors.centerIn: parent
        width: parent.width; height: Theme.barHeight - 6
        radius: Theme.radiusSmall
        color: root.selected ? Theme.selection : root.hovered ? Theme.raised : "transparent"
        border.color: root.visualFocus ? Theme.focus : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
    }
    contentItem: Icon {
        name: root.iconName
        opacity: root.dim
        color: root.hovered || root.selected || root.lit ? Theme.text : Theme.secondary
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
    }
}
