import QtQuick

Rectangle {
    anchors.fill: parent
    gradient: Gradient {
        GradientStop { position: 0; color: "#224f74" }
        GradientStop { position: 0.55; color: "#83b9c3" }
        GradientStop { position: 1; color: "#dae4c9" }
    }
    Canvas {
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d"); ctx.reset();
            const w = width, h = height;
            ctx.fillStyle = "#658b89";
            ctx.beginPath(); ctx.moveTo(0, h * 0.76); ctx.bezierCurveTo(w * 0.2, h * 0.42, w * 0.33, h * 0.96, w * 0.56, h * 0.67); ctx.bezierCurveTo(w * 0.8, h * 0.35, w * 0.94, h * 0.73, w, h * 0.58); ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.fill();
            ctx.fillStyle = "#264f52"; ctx.beginPath(); ctx.moveTo(0, h * 0.8); ctx.bezierCurveTo(w * 0.35, h * 0.97, w * 0.65, h * 0.62, w, h * 0.81); ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.fill();
        }
    }
}
