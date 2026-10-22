import QtQuick
import QtQuick.Controls.Basic
import "../core"

Button {
    id: control
    property bool accent: false
    // Destructive confirmations keep the neutral button but read in red.
    property bool destructive: false
    property string iconName: ""
    implicitWidth: Math.max(64, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: 30
    leftPadding: 12; rightPadding: 12; topPadding: 0; bottomPadding: 0
    hoverEnabled: true
    font.family: Theme.font
    font.pixelSize: Theme.textSmall
    font.styleName: ""
    onFontChanged: Theme.syncFontWeight(control)
    font.weight: Theme.weightMedium
    scale: down ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Settings.reducedMotion ? 0 : 90; easing.type: Easing.OutCubic } }
    background: Rectangle {
        radius: Theme.radiusControl
        color: control.accent ? (control.hovered ? Theme.accentHover : Theme.accent)
             : control.down ? Theme.pressed : control.hovered ? Theme.selection : Theme.raised
        border.width: control.accent ? 0 : 1
        border.color: control.visualFocus ? Theme.focus : Theme.borderStrong
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
        Rectangle {
            anchors.fill: parent; anchors.margins: -3
            radius: parent.radius + 3; color: "transparent"
            border.width: 2; border.color: Qt.alpha(Theme.focus, 0.45)
            visible: control.accent && control.visualFocus
        }
    }
    contentItem: Row {
        spacing: 6
        Icon { visible: control.iconName !== ""; name: control.iconName || "circle"; width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter; color: control.accent ? Theme.accentInk : Theme.secondary }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            font: control.font
            color: control.accent ? Theme.accentInk : control.destructive ? Theme.error : Theme.text
            renderType: Text.QtRendering
        }
    }
    opacity: enabled ? 1 : 0.4
}
