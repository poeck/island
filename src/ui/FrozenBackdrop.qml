import QtQuick
import QtQuick.Effects
import "../core"

Item {
    id: root
    clip: true
    property var snapshot: null
    property bool showcase: false
    onSnapshotChanged: {
        if (snapshot) {
            snapshot.parent = sourceContainer;
            snapshot.width = Qt.binding(() => root.width);
            snapshot.height = Qt.binding(() => root.height);
        }
    }
    Rectangle { anchors.fill: parent; color: Theme.background }
    Item { id: sourceContainer; anchors.fill: parent; visible: false }
    ShowcaseArt { id: sample; anchors.fill: parent; visible: false }
    MultiEffect {
        anchors.fill: parent
        scale: 1.12
        source: root.snapshot || (root.showcase ? sample : null)
        blurEnabled: true; blurMax: 64; blur: 1
        saturation: -0.15
        visible: root.snapshot !== null || root.showcase
    }
}
