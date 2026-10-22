import QtQuick
import "../core"

Card {
    id: root
    property string title: ""
    property string iconName: "cpu"
    property string value: ""
    property string detail: ""
    property string caption: ""
    property var samples: []
    property real maximum: 100
    property color tone: Theme.text
    property bool active: true
    implicitHeight: 112
    Icon { x: 14; y: 14; width: 14; height: 14; name: root.iconName; color: Theme.secondary }
    Label { x: 34; y: 13; text: root.title; font.pixelSize: Theme.textSmall; font.weight: Theme.weightMedium; color: Theme.secondary }
    Label {
        anchors { right: parent.right; rightMargin: 14 }
        y: 13; width: parent.width / 2 - 14
        horizontalAlignment: Text.AlignRight
        text: root.detail; font.pixelSize: Theme.textSmall; font.features: Theme.numeric; color: Theme.secondary
    }
    Label { x: 14; y: 34; text: root.value; font.pixelSize: 22; font.weight: Theme.weightSemibold; font.letterSpacing: -0.4; font.features: Theme.numeric; color: root.tone }
    Sparkline { x: 14; y: 64; width: parent.width - 28; height: 22; values: root.samples; maximum: root.maximum; active: root.active }
    Label { x: 14; y: 92; width: parent.width - 28; text: root.caption; font.pixelSize: Theme.textCaption; color: Theme.muted }
}
