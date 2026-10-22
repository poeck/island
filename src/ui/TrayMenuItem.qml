import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import "../core"

MenuItem {
    id: root
    property QsMenuEntry entry: null
    readonly property bool marked: entry && entry.buttonType !== QsMenuButtonType.None
    readonly property bool hasIcon: icon.source.toString().length > 0
    readonly property color ink: !enabled ? Theme.muted : Theme.text
    implicitWidth: caption.implicitWidth + leftPadding + rightPadding
    implicitHeight: Theme.trayMenuRowHeight
    leftPadding: marked || hasIcon ? 38 : 12
    rightPadding: subMenu ? 34 : 12
    font.family: Theme.font
    font.pixelSize: Theme.textBody
    font.styleName: ""
    font.weight: Theme.weightRegular
    onFontChanged: Theme.syncFontWeight(root)
    hoverEnabled: true
    text: entry ? entry.text : subMenu ? subMenu.title : ""
    enabled: entry ? entry.enabled : subMenu ? subMenu.enabled : true
    icon.source: entry ? entry.icon : subMenu ? subMenu.icon.source : ""
    onTriggered: if (entry) entry.triggered()
    contentItem: Label {
        id: caption
        text: root.text.replace(/&&/g, "\u0000").replace(/&/g, "").replace(/\u0000/g, "&")
        font: root.font
        color: root.ink
        verticalAlignment: Text.AlignVCenter
    }
    indicator: Item {
        x: 12; y: (root.height - height) / 2
        width: 16; height: 16
        visible: root.marked
        Rectangle {
            anchors.centerIn: parent
            width: 12; height: width
            radius: root.entry && root.entry.buttonType === QsMenuButtonType.RadioButton ? 6 : 3
            border.color: root.ink
            color: "transparent"
        }
        Icon {
            anchors.fill: parent
            name: "check"; color: root.ink
            visible: root.entry && root.entry.checkState === Qt.Checked && root.entry.buttonType === QsMenuButtonType.CheckBox
        }
        Rectangle {
            anchors.centerIn: parent
            width: 6; height: root.entry && root.entry.checkState === Qt.PartiallyChecked ? 2 : 6
            radius: height / 2; color: root.ink
            visible: root.entry && (root.entry.checkState === Qt.PartiallyChecked || (root.entry.checkState === Qt.Checked && root.entry.buttonType === QsMenuButtonType.RadioButton))
        }
    }
    Image {
        x: 12; y: (root.height - height) / 2
        width: 16; height: 16
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        source: root.icon.source
        fillMode: Image.PreserveAspectFit
        visible: root.hasIcon && !root.marked
        opacity: root.enabled ? 1 : 0.35
    }
    arrow: Item {
        x: root.width - 25; y: (root.height - height) / 2
        width: 12; height: 12
        visible: !!root.subMenu
        Rectangle {
            x: 4; y: 4; width: 6; height: 1; rotation: 45; color: root.ink
        }
        Rectangle { x: 4; y: 8; width: 6; height: 1; rotation: -45; color: root.ink }
    }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: root.highlighted ? Theme.selection : "transparent"
        Behavior on color { ColorAnimation { duration: Settings.reducedMotion ? 0 : 80 } }
    }
}
