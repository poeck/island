import QtQuick
import QtQuick.Controls.Basic
import "../core"

// On/off switch. The owner applies the change in onClicked and binds checked
// back from the service, so a refused change snaps back.
Switch {
    id: root
    property bool active: false
    checked: active
    checkable: false
    implicitWidth: 34; implicitHeight: 20
    padding: 0; hoverEnabled: true
    indicator: Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? (root.hovered ? Theme.accentHover : Theme.accent) : root.hovered ? Theme.pressed : Theme.track
        border.color: root.visualFocus ? Theme.text : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
        Rectangle {
            y: 2; x: root.active ? parent.width - width - 2 : 2
            width: parent.height - 4; height: width; radius: width / 2
            color: root.active ? Theme.accentInk : Theme.secondary
            Behavior on x { NumberAnimation { duration: Settings.reducedMotion ? 0 : 160; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
        }
    }
    contentItem: null
    opacity: enabled ? 1 : 0.4
}
