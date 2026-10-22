import QtQuick
import "../core"

Rectangle {
    property alias text: key.text
    implicitWidth: Math.max(18, key.implicitWidth + 10)
    implicitHeight: 18
    radius: 4
    color: Theme.raised
    border.color: Theme.borderStrong
    Label { id: key; anchors.centerIn: parent; font.pixelSize: Theme.textCaption; color: Theme.secondary }
}
