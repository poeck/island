import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "../core"
import "../core/Images.js" as Images
import "../ui"

FocusScope {
    id: root
    required property var service
    property bool active: false
    property bool demo: false
    signal dismiss()
    readonly property var applications: service ? service.applications : []
    onActiveChanged: if (active) Qt.callLater(() => { if (root.active) root.forceActiveFocus(); })
    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.contentMargin; spacing: 10
        ViewHeader {
            title: "Audio"; preview: root.demo
            ActionButton {
                id: effectsButton
                visible: !!root.service && !!root.service.effectsEntry && !root.demo
                text: "Effects"; iconName: "effects"
                Accessible.name: "Open EasyEffects"
                onClicked: root.service.openEffects()
            }
            IconButton { iconName: "close"; hint: "Close audio controls"; onClicked: root.dismiss() }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: false; Layout.topMargin: 4
            Layout.preferredHeight: 220; Layout.minimumHeight: 220; Layout.maximumHeight: 220; spacing: 10
            AudioDeviceCard { Layout.fillWidth: true; Layout.fillHeight: true; service: root.service }
            AudioDeviceCard { Layout.fillWidth: true; Layout.fillHeight: true; service: root.service; input: true }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 20; Layout.topMargin: 4; spacing: 6
            Label { text: "Applications"; font.weight: Theme.weightSemibold }
            Label { text: root.applications.length; font.pixelSize: Theme.textSmall; font.features: Theme.numeric; color: Theme.muted }
            Item { Layout.fillWidth: true }
            Label { text: "Independent volume and mute"; font.pixelSize: Theme.textSmall; color: Theme.muted }
        }
        ListView {
            id: apps
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredHeight: 160
            clip: true; spacing: 6
            model: root.applications
            ScrollBar.vertical: ScrollBar {}
            delegate: Card {
                id: app
                required property var modelData
                readonly property real volume: root.service.volume(modelData.nodes)
                readonly property bool muted: root.service.muted(modelData.nodes)
                width: apps.width; height: 56
                Item {
                    x: 14; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24
                    Image {
                        id: appIcon
                        anchors.fill: parent
                        source: Images.resolveIcon(app.modelData.icon, Quickshell.iconPath)
                        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                    }
                    Icon { anchors.centerIn: parent; width: 16; height: 16; name: app.modelData.recording ? "mic" : "app"; color: Theme.secondary; visible: appIcon.status !== Image.Ready }
                }
                Label { x: 52; y: 10; width: 200; text: app.modelData.title; font.weight: Theme.weightMedium; color: app.muted ? Theme.secondary : Theme.text }
                Label { x: 52; y: 29; width: 200; text: app.modelData.recording ? "Recording" : "Playback"; font.pixelSize: Theme.textCaption; color: Theme.muted }
                VolumeSlider {
                    anchors { left: parent.left; leftMargin: 260; right: percent.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    value: app.volume; muted: app.muted
                    Accessible.name: app.modelData.title + " volume"
                    onMoved: root.service.setVolume(app.modelData.nodes, value)
                }
                Label { id: percent; anchors { right: mute.left; rightMargin: 6; verticalCenter: parent.verticalCenter } text: Math.round(app.volume * 100) + "%"; width: 38; horizontalAlignment: Text.AlignRight; font.pixelSize: Theme.textSmall; font.features: Theme.numeric; color: app.muted ? Theme.muted : Theme.secondary }
                IconButton {
                    id: mute
                    objectName: "audioAppMute-" + app.modelData.title
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    iconName: app.modelData.recording ? app.muted ? "mic-muted" : "mic" : app.muted ? "muted" : "volume"
                    accented: app.muted
                    hint: (app.muted ? "Unmute " : "Mute ") + app.modelData.title
                    onClicked: root.service.toggleMute(app.modelData.nodes)
                }
            }
            Column {
                anchors.centerIn: parent; spacing: 6; visible: apps.count === 0
                Icon { anchors.horizontalCenter: parent.horizontalCenter; width: 20; height: 20; name: "music"; color: Theme.muted }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing playing"; color: Theme.secondary; font.weight: Theme.weightMedium }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Apps appear here when they use audio."; font.pixelSize: Theme.textSmall; color: Theme.muted }
            }
        }
    }
}
