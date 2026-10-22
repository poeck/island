import QtQuick
import QtQuick.Controls.Basic
import "../core"

Button {
    id: root
    property string iconName: "close"
    // A latched state such as "muted": shown as a pressed-in grey key.
    property bool accented: false
    property string hint: ""
    implicitWidth: 28; implicitHeight: 28
    padding: 6; hoverEnabled: true
    Accessible.name: hint
    scale: down ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: Settings.reducedMotion ? 0 : 90; easing.type: Easing.OutCubic } }
    background: Rectangle {
        radius: Theme.radiusControl
        color: root.down ? Theme.pressed : root.accented ? Theme.selection : root.hovered ? Theme.raised : "transparent"
        border.color: root.visualFocus ? Theme.focus : root.accented ? Theme.borderStrong : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
    }
    contentItem: Icon { name: root.iconName; color: !root.enabled ? Theme.disabled : root.hovered || root.accented ? Theme.text : Theme.secondary }
}
