import QtQuick
import QtQuick.Controls.Basic
import "../core"

TextField {
    id: field
    color: Theme.text
    placeholderTextColor: Theme.muted
    selectionColor: Qt.alpha(Theme.accent, 0.5)
    selectedTextColor: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.textBody
    font.styleName: ""
    font.weight: Theme.weightRegular
    onFontChanged: Theme.syncFontWeight(field)
    leftPadding: 12
    rightPadding: 12
    implicitHeight: 36
    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusControl
        border.width: 1
        border.color: field.activeFocus ? Theme.focus : field.hovered ? Theme.borderStrong : Theme.border
        Behavior on border.color { ColorAnimation { duration: Theme.hoverDuration } }
        Rectangle {
            anchors.fill: parent; anchors.margins: -3
            radius: parent.radius + 3; color: "transparent"
            border.width: 3; border.color: Qt.alpha(Theme.focus, 0.18)
            opacity: field.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.hoverDuration } }
        }
    }
}
