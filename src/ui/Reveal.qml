import QtQuick
import "../core"

// Panel content enters after the island starts growing: a short fade with a
// small downward settle, and leaves faster than it arrives.
Item {
    id: root
    property bool shown: false
    anchors.fill: parent
    opacity: shown ? 1 : 0
    visible: shown || opacity > 0
    enabled: shown
    transform: [
        Translate { y: Settings.reducedMotion ? 0 : (1 - root.opacity) * -6 },
        Scale { origin.x: root.width / 2; origin.y: 0; xScale: Settings.reducedMotion ? 1 : 0.985 + 0.015 * root.opacity; yScale: xScale }
    ]
    Behavior on opacity {
        NumberAnimation { duration: root.shown ? Theme.fadeInDuration : Theme.fadeOutDuration; easing.type: Easing.OutCubic }
    }
}
