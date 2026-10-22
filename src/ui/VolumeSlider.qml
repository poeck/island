import QtQuick
import QtQuick.Controls.Basic
import "../core"

Slider {
    id: root
    property bool muted: false
    from: 0; to: 1; stepSize: .01
    implicitHeight: 24; implicitWidth: 180
    leftPadding: 7; rightPadding: 7
    hoverEnabled: true
    readonly property bool engaged: pressed || hovered || activeFocus
    background: Rectangle {
        x: root.leftPadding; y: root.topPadding + (root.availableHeight - height) / 2
        width: root.availableWidth; height: root.engaged ? 6 : 4; radius: height / 2; color: Theme.track
        Behavior on height { NumberAnimation { duration: Theme.hoverDuration } }
        Rectangle {
            width: Math.max(parent.height, root.visualPosition * parent.width); height: parent.height; radius: parent.radius
            color: root.muted || !root.enabled ? Theme.muted : Theme.accent
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + (root.availableHeight - height) / 2
        width: root.engaged ? 14 : 10; height: width
        radius: width / 2
        color: root.muted || !root.enabled ? Theme.secondary : Theme.text
        border.width: root.visualFocus ? 2 : 0; border.color: Theme.focus
        Behavior on width { NumberAnimation { duration: Theme.hoverDuration; easing.type: Easing.OutCubic } }
    }
}
