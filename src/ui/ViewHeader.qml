import QtQuick
import QtQuick.Layouts
import "../core"

// Title row shared by every panel: title, optional preview badge, trailing controls.
RowLayout {
    id: root
    property string title: ""
    property bool preview: false
    default property alias trailing: actions.data
    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.preferredHeight: 28
    spacing: 8
    Label { text: root.title; font.pixelSize: Theme.textTitle; font.weight: Theme.weightSemibold; font.letterSpacing: -0.1 }
    Badge { visible: root.preview; text: "Preview" }
    Item { Layout.fillWidth: true }
    RowLayout { id: actions; spacing: 6 }
}
