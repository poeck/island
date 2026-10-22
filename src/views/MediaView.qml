import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../core"
import "../ui"

FocusScope {
    id: root
    required property var media
    required property date date
    property bool active: false
    onActiveChanged: if (active) Qt.callLater(() => { if (root.active) root.forceActiveFocus(); })
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 22; anchors.rightMargin: 24; anchors.topMargin: 18; anchors.bottomMargin: 22; spacing: 18
        Rectangle {
            Layout.preferredWidth: 104; Layout.preferredHeight: 104
            radius: 14; color: Theme.raised; border.color: Theme.border; clip: true
            visible: root.media.available
            RoundedImage { anchors.fill: parent; source: root.media.art; radius: 14 }
            Icon { anchors.centerIn: parent; name: "music"; visible: !root.media.art; width: 28; height: 28; color: Theme.muted }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Label { Layout.fillWidth: true; visible: root.media.available; text: "Now playing"; font.pixelSize: Theme.textCaption; font.weight: Theme.weightMedium; color: Theme.muted; Layout.bottomMargin: 4 }
            Label { Layout.fillWidth: true; text: root.media.title; font.pixelSize: Theme.textTitle; font.weight: Theme.weightSemibold; font.letterSpacing: -0.1 }
            Label { Layout.fillWidth: true; text: [root.media.artist, root.media.album].filter(Boolean).join(" · "); color: Theme.secondary; visible: root.media.available }
            Label { text: Qt.formatDate(root.date, "dddd, d MMMM"); color: Theme.secondary; visible: !root.media.available }
            Row {
                visible: root.media.available; spacing: 4; Layout.topMargin: 8; Layout.leftMargin: -6
                Repeater {
                    model: ["previous", root.media.playing ? "pause" : "play", "next"]
                    delegate: IconButton {
                        required property string modelData
                        required property int index
                        width: 32; height: 32; padding: 8
                        iconName: modelData
                        hint: index === 0 ? "Previous" : index === 1 ? (root.media.playing ? "Pause" : "Play") : "Next"
                        enabled: index === 0 ? root.media.canPrevious : index === 1 ? root.media.canToggle : root.media.canNext
                        onClicked: index === 0 ? root.media.previous() : index === 1 ? root.media.toggle() : root.media.next()
                    }
                }
            }
        }
        Rectangle { Layout.fillHeight: true; Layout.topMargin: 6; Layout.bottomMargin: 2; implicitWidth: 1; color: Theme.border }
        ColumnLayout {
            Layout.preferredWidth: Math.min(244, root.width * 0.34); spacing: 10
            Label { Layout.alignment: Qt.AlignHCenter; text: Qt.formatTime(root.date, "HH:mm"); font.pixelSize: Theme.textDisplay; font.weight: Theme.weightSemibold; font.letterSpacing: -0.8; font.features: Theme.numeric }
            RowLayout {
                spacing: 2
                Repeater {
                    model: 7
                    delegate: Rectangle {
                        required property int index
                        readonly property date day: new Date(root.date.getFullYear(), root.date.getMonth(), root.date.getDate() - ((root.date.getDay() + 6) % 7) + index)
                        readonly property bool today: day.getDate() === root.date.getDate()
                        Layout.fillWidth: true; Layout.preferredHeight: 50
                        radius: Theme.radiusControl; color: today ? Theme.selection : "transparent"
                        border.color: today ? Theme.borderStrong : "transparent"
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(day, "ddd"); font.pixelSize: Theme.textCaption; color: today ? Theme.secondary : Theme.muted }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: day.getDate(); font.pixelSize: Theme.textTitle; font.weight: today ? Theme.weightSemibold : Theme.weightRegular; font.features: Theme.numeric; color: today ? Theme.text : Theme.secondary }
                        }
                    }
                }
            }
        }
    }
}
