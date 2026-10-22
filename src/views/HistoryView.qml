import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../core"
import "../ui"

FocusScope {
    id: root
    property bool active: false
    onActiveChanged: if (active) Qt.callLater(() => forceActiveFocus())
    required property var service
    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.contentMargin; spacing: 14
        ViewHeader {
            title: "Notifications"
            Label { text: "Do not disturb"; color: Theme.secondary; font.pixelSize: Theme.textSmall }
            Toggle { active: root.service.dnd; Accessible.name: "Do not disturb"; onClicked: root.service.dnd = !root.service.dnd; Layout.rightMargin: 6 }
            ActionButton { text: "Clear all"; enabled: root.service.history.length > 0; onClicked: root.service.clear() }
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
            model: root.service.history
            ScrollBar.vertical: ScrollBar {}
            delegate: Card {
                required property var modelData
                width: list.width; height: modelData.actions.length ? 122 : 84
                NotificationView { anchors.fill: parent; notification: parent.modelData; service: root.service }
            }
            Column {
                visible: list.count === 0; anchors.centerIn: parent; spacing: 10
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "bell"; width: 22; height: 22; color: Theme.muted }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: "You're all caught up"; color: Theme.text; font.weight: Theme.weightMedium }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.service.dnd ? "Do not disturb is on. New notifications are kept here." : "New notifications will appear here."; color: Theme.muted; font.pixelSize: Theme.textSmall }
            }
        }
    }
}
