import QtQuick
import "../core"

Rectangle {
    id: root
    property alias text: caption.text
    property color tone: Theme.secondary
    implicitWidth: caption.implicitWidth + 12
    implicitHeight: 18
    radius: 5
    color: "transparent"
    border.color: Theme.borderStrong
    Label { id: caption; anchors.centerIn: parent; font.pixelSize: Theme.textCaption; font.weight: Theme.weightMedium; color: root.tone }
}
