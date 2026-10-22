import QtQuick
import QtQuick.Effects
import "../core"

Item {
    id: root
    property string name: "circle"
    property color color: Theme.text
    implicitWidth: 24
    implicitHeight: 24
    // Monochrome SVGs are rendered at the actual device scale by Qt's image provider.
    Image {
        anchors.fill: parent
        source: "../assets/icons/" + root.name + ".svg"
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        visible: false
        id: image
    }
    MultiEffect {
        anchors.fill: parent
        source: image
        colorization: 1
        colorizationColor: root.color
    }
}
