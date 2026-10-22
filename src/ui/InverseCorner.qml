import QtQuick
import QtQuick.Shapes
import "../core"

Shape {
    id: root
    property bool mirrored: false
    preferredRendererType: Shape.CurveRenderer
    transform: Scale { origin.x: root.width / 2; xScale: root.mirrored ? -1 : 1 }
    ShapePath {
        strokeWidth: -1
        fillColor: Theme.background
        startX: 0; startY: 0
        PathLine { x: root.width; y: 0 }
        PathLine { x: root.width; y: root.height }
        // Quarter circle, with black filling the outside of the curve. The
        // vertical tangent meets the panel; the horizontal tangent meets the bar.
        PathCubic {
            x: 0; y: 0
            control1X: root.width; control1Y: root.height * 0.44771525
            control2X: root.width * 0.55228475; control2Y: 0
        }
    }
}
