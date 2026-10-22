import QtQuick
import "../core"
import "../core/Weather.js" as Weather

Item {
    id: root
    property var code: 0
    property bool day: true
    readonly property string kind: Weather.condition(code,day).icon
    property color color: Theme.text
    implicitWidth: 32; implicitHeight: 32
    Icon { anchors.fill:parent; name:"weather-"+root.kind; color:root.color }
}
