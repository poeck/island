import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import "../core"
import "../ui"
import "../core/Images.js" as Images

Item {
    id: root
    property var notification: null
    required property var service
    readonly property bool hasActions: !!notification && notification.actions.some(a => a.id !== "default")
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 16; anchors.topMargin: 14; anchors.bottomMargin: 14; spacing: 14
        Rectangle {
            Layout.preferredWidth: 36; Layout.preferredHeight: 36; Layout.alignment: root.hasActions ? Qt.AlignTop : Qt.AlignVCenter
            radius: 10; color: Theme.raised; border.color: Theme.border
            Image { id: appIcon; anchors.fill: parent; anchors.margins: 7; source: root.notification ? Images.resolveIcon(root.notification.icon, Quickshell.iconPath) : ""; asynchronous: true }
            Icon { anchors.centerIn: parent; width: 16; height: 16; name: "bell"; color: Theme.secondary; visible: appIcon.status !== Image.Ready }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: root.hasActions ? Qt.AlignTop : Qt.AlignVCenter; spacing: 2
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Label { Layout.fillWidth: true; Layout.maximumWidth: implicitWidth; text: root.notification ? root.notification.summary : ""; font.weight: Theme.weightSemibold }
                Label { text: root.notification ? "· " + root.notification.app : ""; color: Theme.muted; font.pixelSize: Theme.textSmall; Layout.fillWidth: true }
            }
            Label { Layout.fillWidth: true; text: root.notification ? root.notification.body : ""; color: Theme.secondary; font.pixelSize: Theme.textSmall; maximumLineCount: 2; wrapMode: Text.Wrap; lineHeight: 1.15 }
            Flickable {
                Layout.fillWidth: true; Layout.topMargin: 6; implicitHeight: 30
                visible: root.hasActions
                contentWidth: actions.implicitWidth; contentHeight: 28
                clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                Row {
                    id: actions; spacing: 6
                    Repeater {
                        model: root.notification ? root.notification.actions.filter(a => a.id !== "default") : []
                        delegate: ActionButton { required property var modelData; text: modelData.text; implicitHeight: 28; onClicked: root.service.invoke(root.notification.id, modelData.id) }
                    }
                }
            }
        }
        IconButton {
            Layout.alignment: root.hasActions ? Qt.AlignTop : Qt.AlignVCenter
            iconName: "close"; hint: "Dismiss notification"
            onClicked: if (root.notification) root.service.dismiss(root.notification.id)
        }
    }
    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: if (root.notification) root.service.invoke(root.notification.id, "default") }
}
