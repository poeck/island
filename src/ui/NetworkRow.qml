import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../core"

Button {
    id: root
    property string title: ""
    property string subtitle: ""
    property string iconName: "wifi"
    property string trailing: ""
    property bool selected: false
    implicitHeight: 48; leftPadding: 10; rightPadding: 10; topPadding: 0; bottomPadding: 0; hoverEnabled: true
    Accessible.name: title + ", " + subtitle + ", " + trailing
    background: Rectangle {
        radius: Theme.radiusControl
        color: root.down ? Theme.pressed : root.selected ? Theme.selection : root.hovered ? Theme.raised : "transparent"
        border.color: root.visualFocus ? Theme.focus : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
    }
    contentItem: RowLayout {
        spacing: 10
        Icon { name: root.iconName; Layout.preferredWidth: 16; Layout.preferredHeight: 16; color: root.selected ? Theme.text : Theme.secondary }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Label { Layout.fillWidth: true; text: root.title; font.weight: root.selected ? Theme.weightMedium : Theme.weightRegular; color: root.enabled ? Theme.text : Theme.muted }
            Label { Layout.fillWidth: true; text: root.subtitle; font.pixelSize: Theme.textCaption; color: Theme.secondary }
        }
        Label { text: root.trailing; font.pixelSize: Theme.textCaption; font.features: Theme.numeric; color: root.selected ? Theme.text : Theme.secondary }
    }
}
