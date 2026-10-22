import QtQuick
import "../core"

Item {
    id: root
    property real topInset: 0
    property bool topVisible: true
    property bool bottomVisible: true
    Repeater {
        model: 4
        delegate: Canvas {
            required property int index
            visible: index < 2 ? root.topVisible : root.bottomVisible
            width: Theme.cornerRadius; height: width
            x: index === 1 || index === 2 ? parent.width - width : 0
            y: index >= 2 ? parent.height - height : root.topInset
            rotation: index * 90
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                ctx.fillStyle = "black"; ctx.fillRect(0, 0, width, height);
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath(); ctx.arc(width, height, width, 0, Math.PI * 2); ctx.fill();
            }
        }
    }
}
