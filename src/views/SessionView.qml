import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../core"
import "../ui"

FocusScope {
    id: root
    signal execute(string action)
    property int selection: 0
    property bool active: false
    onActiveChanged: if (active) { selection = 0; forceActiveFocus(); }
    readonly property var actions: [
        {name: "Lock", icon: "lock", id: "lock"}, {name: "Suspend", icon: "moon", id: "suspend"},
        {name: "Log out", icon: "logout", id: "logout"}, {name: "Restart", icon: "reboot", id: "reboot"},
        {name: "Shut down", icon: "power", id: "poweroff"}
    ]
    Keys.onLeftPressed: selection = (selection + 4) % 5
    Keys.onRightPressed: selection = (selection + 1) % 5
    Keys.onReturnPressed: execute(actions[selection].id)
    Keys.onEnterPressed: execute(actions[selection].id)
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.topMargin: 12; anchors.bottomMargin: 16; spacing: 6
        Repeater {
            model: root.actions
            delegate: Button {
                id: button
                required property var modelData
                required property int index
                readonly property bool selected: root.selection === index
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true; hoverEnabled: true
                Accessible.name: modelData.name
                onHoveredChanged: if (hovered) root.selection = index
                onClicked: root.execute(modelData.id)
                scale: down ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: Settings.reducedMotion ? 0 : 90; easing.type: Easing.OutCubic } }
                background: Rectangle {
                    radius: 22
                    color: button.down ? Theme.pressed : button.selected ? Theme.selection : Theme.surface
                    border.color: button.selected ? Theme.borderStrong : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
                }
                contentItem: Item {
                    Column {
                        anchors.centerIn: parent; spacing: 10
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; width: 20; height: 20; name: button.modelData.icon; color: button.selected ? Theme.text : Theme.secondary
                            Behavior on color { ColorAnimation { duration: Theme.hoverDuration } } }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: button.modelData.name; color: button.selected ? Theme.text : Theme.secondary; font.pixelSize: Theme.textSmall; font.weight: Theme.weightMedium }
                    }
                }
            }
        }
    }
}
