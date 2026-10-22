import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"
import "../core/Images.js" as Images

FocusScope {
    id: root
    required property var apps
    signal dismiss()
    property bool active: false
    readonly property bool inputFocused: search.activeFocus
    onActiveChanged: if (active) Qt.callLater(() => search.forceActiveFocus())
    ColumnLayout {
        anchors.fill: parent; spacing: 0
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: false; Layout.preferredHeight: 52
            Layout.leftMargin: 22; Layout.rightMargin: 22; spacing: 12
            Icon { name: "search"; color: Theme.secondary; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
            TextField {
                id: search
                Layout.fillWidth: true; Layout.fillHeight: true
                background: null; padding: 0; color: Theme.text; placeholderText: "Search applications…"; placeholderTextColor: Theme.muted
                font.family: Theme.font; font.pixelSize: 16; selectionColor: Qt.alpha(Theme.accent, 0.5); selectedTextColor: Theme.text
                font.styleName: ""; font.weight: Theme.weightRegular
                onFontChanged: Theme.syncFontWeight(search)
                verticalAlignment: TextInput.AlignVCenter
                text: root.apps.query
                onTextEdited: root.apps.query = text
                Keys.onDownPressed: root.apps.move(1)
                Keys.onUpPressed: root.apps.move(-1)
                onAccepted: if (root.apps.launch(root.apps.selection)) root.dismiss()
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
        Label {
            Layout.fillWidth: true; Layout.leftMargin: 22; Layout.topMargin: 12; Layout.bottomMargin: 4
            text: root.apps.query ? "Results" : "Applications"; font.pixelSize: Theme.textCaption; font.weight: Theme.weightMedium; color: Theme.muted
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.leftMargin: 10; Layout.rightMargin: 10
            clip: true; spacing: 2
            model: root.apps.results
            currentIndex: root.apps.selection
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: root.apps.selection === index
                width: list.width; height: 44; radius: Theme.radiusControl
                color: selected ? Theme.selection : "transparent"
                Behavior on color { ColorAnimation { duration: 60 } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                    Item {
                        Layout.preferredWidth: 26; Layout.preferredHeight: 26
                        Image { id: appIcon; anchors.fill: parent; source: Images.resolveIcon(row.modelData.icon, Quickshell.iconPath); sourceSize: Qt.size(26 * Screen.devicePixelRatio, 26 * Screen.devicePixelRatio); asynchronous: true }
                        Icon { anchors.centerIn: parent; width: 18; height: 18; name: "app"; visible: appIcon.status !== Image.Ready; color: Theme.secondary }
                    }
                    Label { text: row.modelData.name; font.weight: Theme.weightMedium; Layout.maximumWidth: list.width * 0.5 }
                    Label { Layout.fillWidth: true; text: row.modelData.genericName || row.modelData.comment || "Application"; color: Theme.muted; font.pixelSize: Theme.textSmall }
                    Kbd { text: "↵"; visible: row.selected }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onPositionChanged: root.apps.selection = row.index
                    onClicked: if (root.apps.launch(row.index)) root.dismiss()
                }
            }
            Column {
                anchors.centerIn: parent; spacing: 10; visible: list.count === 0
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "search"; width: 22; height: 22; color: Theme.muted }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.apps.query ? "No applications found" : "No installed applications"; color: Theme.secondary }
            }
        }
        Label { Layout.fillWidth: true; Layout.leftMargin: 22; Layout.rightMargin: 22; visible: root.apps.error !== ""; text: root.apps.error; color: Theme.error; font.pixelSize: Theme.textSmall; wrapMode: Text.Wrap }
        Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; implicitHeight: 1; color: Theme.border }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: false; Layout.preferredHeight: 40
            Layout.leftMargin: 26; Layout.rightMargin: 26; spacing: 6
            Label { text: list.count + (list.count === 1 ? " application" : " applications"); font.pixelSize: Theme.textCaption; font.features: Theme.numeric; color: Theme.muted; Layout.fillWidth: true }
            Kbd { text: "↑↓" }
            Label { text: "Navigate"; font.pixelSize: Theme.textCaption; color: Theme.muted; Layout.rightMargin: 8 }
            Kbd { text: "↵" }
            Label { text: "Open"; font.pixelSize: Theme.textCaption; color: Theme.muted; Layout.rightMargin: 8 }
            Kbd { text: "esc" }
            Label { text: "Close"; font.pixelSize: Theme.textCaption; color: Theme.muted }
        }
    }
}
