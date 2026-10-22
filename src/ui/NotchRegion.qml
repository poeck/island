import QtQuick
import Quickshell
import "../core"

Region {
    id: root
    required property real bodyX
    required property real bodyWidth
    required property real bodyHeight
    required property real bottomRadius
    required property real joinRadius
    property bool active: true
    property real topOffset: 0
    // Only the centered clock belongs to this surface within the bar. Expanded
    // body width must not intercept the network/audio/stats/tray hit regions.
    Region {
        x: root.bodyX + (root.bodyWidth - Theme.clockWidth) / 2; y: root.topOffset
        width: root.active ? Theme.clockWidth : 0
        height: root.active ? Theme.barHeight : 0
    }
    Region {
        x: root.bodyX; y: Theme.barHeight + root.topOffset
        width: root.active ? root.bodyWidth : 0
        height: root.active ? root.bodyHeight : 0
        bottomLeftRadius: root.bottomRadius; bottomRightRadius: root.bottomRadius
    }
    Region {
        x: root.bodyX - root.joinRadius; y: Theme.barHeight + root.topOffset
        width: root.active ? root.joinRadius : 0
        height: root.active ? root.joinRadius : 0
        Region {
            x: root.bodyX - 2 * root.joinRadius; y: Theme.barHeight + root.topOffset
            width: 2 * root.joinRadius; height: width
            shape: RegionShape.Ellipse; intersection: Intersection.Subtract
        }
    }
    Region {
        x: root.bodyX + root.bodyWidth; y: Theme.barHeight + root.topOffset
        width: root.active ? root.joinRadius : 0
        height: root.active ? root.joinRadius : 0
        Region {
            x: root.bodyX + root.bodyWidth; y: Theme.barHeight + root.topOffset
            width: 2 * root.joinRadius; height: width
            shape: RegionShape.Ellipse; intersection: Intersection.Subtract
        }
    }
}
