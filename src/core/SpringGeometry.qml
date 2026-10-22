import QtQuick
import "Motion.js" as Motion

Item {
    id: root
    // The island rebounds; SpringValue keeps the calm preset for screen chrome.
    property real targetWidth: Theme.dimensions.compact[0]
    property real targetHeight: Theme.dimensions.compact[1]
    property real targetRadius: Theme.dimensions.compact[2]
    property real targetShoulderRadius: 0
    property bool reducedMotion: false
    property real valueWidth: Theme.dimensions.compact[0]
    property real valueHeight: Theme.dimensions.compact[1]
    property real valueRadius: Theme.dimensions.compact[2]
    property real valueShoulderRadius: 0
    property real velocityWidth: 0
    property real velocityHeight: 0
    property real velocityRadius: 0
    property real velocityShoulderRadius: 0
    property double started: 0
    property int settledMs: 0
    property int frameCount: 0
    readonly property alias running: frames.running
    function wake() {
        started = Date.now();
        if (reducedMotion) {
            valueWidth = targetWidth; valueHeight = targetHeight; valueRadius = targetRadius;
            valueShoulderRadius = targetShoulderRadius;
            velocityWidth = 0; velocityHeight = 0; velocityRadius = 0; velocityShoulderRadius = 0; frames.running = false;
        } else frames.running = true;
    }
    onTargetWidthChanged: wake()
    onTargetHeightChanged: wake()
    onTargetRadiusChanged: wake()
    onTargetShoulderRadiusChanged: wake()
    onReducedMotionChanged: wake()
    FrameAnimation {
        id: frames
        onTriggered: {
            ++root.frameCount;
            const w = Motion.step(root.valueWidth, root.velocityWidth, root.targetWidth, frameTime, Motion.island);
            const h = Motion.step(root.valueHeight, root.velocityHeight, root.targetHeight, frameTime, Motion.island);
            const r = Motion.step(root.valueRadius, root.velocityRadius, root.targetRadius, frameTime, Motion.island);
            const top = Motion.step(root.valueShoulderRadius, root.velocityShoulderRadius, root.targetShoulderRadius, frameTime, Motion.island);
            root.valueWidth = w[0]; root.velocityWidth = w[1];
            root.valueHeight = h[0]; root.velocityHeight = h[1];
            root.valueRadius = r[0]; root.velocityRadius = r[1];
            root.valueShoulderRadius = top[0]; root.velocityShoulderRadius = top[1];
            running = w[0] !== root.targetWidth || h[0] !== root.targetHeight || r[0] !== root.targetRadius || top[0] !== root.targetShoulderRadius || w[1] !== 0 || h[1] !== 0 || r[1] !== 0 || top[1] !== 0;
            if (!running) root.settledMs = Date.now() - root.started;
        }
    }
}
