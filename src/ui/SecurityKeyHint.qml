import QtQuick
import "../core"

// A security key waiting for a physical touch: a quiet ring travels outward
// from the key, like a contact being sensed. Reduced motion holds a still ring.
// This is guidance only; the key and PAM decide the outcome.
Row {
    id: root
    property bool waiting: false
    property color foreground: Theme.text
    property color tint: Theme.accent
    property int glyphSize: 36
    property string title: "Touch your security key"
    property string detail: ""
    property int titleSize: Theme.textBody
    spacing: Math.round(glyphSize * 0.36)
    Item {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyphSize; height: root.glyphSize
        Rectangle {
            id: halo
            anchors.centerIn: parent
            width: parent.width; height: width; radius: width / 2
            color: "transparent"; border.width: 1.5; border.color: root.tint
            opacity: Settings.reducedMotion && root.waiting ? 0.35 : 0
            scale: Settings.reducedMotion ? 1.3 : 1
        }
        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: Qt.alpha(root.tint, 0.16)
            border.width: 1; border.color: Qt.alpha(root.tint, root.waiting ? 0.6 : 0.3)
            Icon { anchors.centerIn: parent; name: "security-key"; width: Math.round(root.glyphSize * 0.56); height: width; color: root.foreground }
        }
        SequentialAnimation {
            running: root.visible && root.waiting && !Settings.reducedMotion
            loops: Animation.Infinite
            onRunningChanged: if (!running) { halo.scale = Settings.reducedMotion ? 1.3 : 1; halo.opacity = Settings.reducedMotion && root.waiting ? 0.35 : 0; }
            ParallelAnimation {
                NumberAnimation { target: halo; property: "scale"; from: 1; to: 1.7; duration: 1500; easing.type: Easing.OutCubic }
                NumberAnimation { target: halo; property: "opacity"; from: 0.55; to: 0; duration: 1500; easing.type: Easing.OutQuad }
            }
            PauseAnimation { duration: 450 }
        }
    }
    Column {
        anchors.verticalCenter: parent.verticalCenter; spacing: 2
        Label { text: root.title; color: root.foreground; font.pixelSize: root.titleSize; font.weight: Theme.weightMedium }
        Label { visible: text !== ""; text: root.detail; color: Qt.alpha(root.foreground, 0.6); font.pixelSize: Theme.textSmall }
    }
}
