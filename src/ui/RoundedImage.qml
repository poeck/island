import QtQuick
import QtQuick.Effects

Item {
    id: root
    property alias source: image.source
    property real radius: 18
    readonly property alias status: image.status
    Image { id: image; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false; sourceSize: Qt.size(root.width * Screen.devicePixelRatio, root.height * Screen.devicePixelRatio) }
    Rectangle { id: imageMask; anchors.fill: parent; radius: root.radius; color: "white"; layer.enabled: true; visible: false }
    MultiEffect { anchors.fill: parent; source: image; maskEnabled: true; maskSource: imageMask }
}
