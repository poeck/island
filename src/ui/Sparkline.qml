import QtQuick
import "../core"

Canvas {
    id: root
    property var values: []
    property real maximum: 100
    property color lineColor: Theme.text
    property bool active: true
    onValuesChanged: if (active) requestPaint()
    onActiveChanged: if (active) requestPaint()
    onWidthChanged: if (active) requestPaint()
    onHeightChanged: if (active) requestPaint()
    onLineColorChanged: if (active) requestPaint()
    onMaximumChanged: if (active) requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const pad = 2, bottom = height - pad, span = height - 2 * pad;
        ctx.strokeStyle = Theme.border; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(0, bottom); ctx.lineTo(width, bottom); ctx.stroke();
        if (!values.length) return;
        let segment = [];
        function draw() {
            if (!segment.length) return;
            ctx.beginPath(); ctx.moveTo(segment[0][0], bottom);
            for (const point of segment) ctx.lineTo(point[0], point[1]);
            ctx.lineTo(segment[segment.length - 1][0], bottom); ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.alpha(root.lineColor, .10)); fill.addColorStop(1, Qt.alpha(root.lineColor, 0));
            ctx.fillStyle = fill; ctx.fill();
            ctx.beginPath(); ctx.moveTo(segment[0][0], segment[0][1]);
            for (const point of segment) ctx.lineTo(point[0], point[1]);
            ctx.strokeStyle = root.lineColor; ctx.lineWidth = 1.25; ctx.lineJoin = "round"; ctx.stroke();
            segment = [];
        }
        for (let i = 0; i < values.length; i++) {
            if (values[i] === null || values[i] === undefined) { draw(); continue; }
            const x = width * (30 - values.length + 1 + i) / 30;
            segment.push([x, bottom - Math.min(1, Math.max(0, values[i] / Math.max(1, maximum))) * span]);
        }
        draw();
    }
}
