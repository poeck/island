import QtQuick
import QtQuick.Layouts
import "../core"

// Segmented control track. One shared pill slides to the selected Segment
// instead of each option fading its own background.
Rectangle {
    id: root
    default property alias segments: row.data
    readonly property var current: {
        for (const child of row.children) if (child.selected && child.visible) return child;
        return null;
    }
    implicitHeight: 32
    radius: Theme.radiusControl
    color: Theme.background
    border.color: Theme.border
    Rectangle {
        id: pill
        visible: root.current !== null
        x: root.current ? row.x + root.current.x : 0
        y: row.y; height: row.height
        width: root.current ? root.current.width : 0
        radius: Theme.radiusSmall
        color: root.current && root.current.accent ? Theme.accent : Theme.pressed
        border.color: root.current && root.current.accent ? "transparent" : Theme.borderStrong
        Behavior on x { enabled: !Settings.reducedMotion; NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
        Behavior on width { enabled: !Settings.reducedMotion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
    RowLayout { id: row; anchors.fill: parent; anchors.margins: 3; spacing: 3 }
}
