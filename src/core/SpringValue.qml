import QtQuick
import "Motion.js" as Motion

Item {
    id: root
    property real target: 0
    property real value: 0
    property real velocity: 0
    property bool reducedMotion: false
    property bool initialized: false
    property int frameCount: 0
    readonly property alias running: frames.running
    function wake() {
        if (!initialized) return;
        if (reducedMotion) {
            value = target; velocity = 0; frames.running = false;
        } else frames.running = value !== target || velocity !== 0;
    }
    onTargetChanged: wake()
    onReducedMotionChanged: wake()
    Component.onCompleted: { value = target; initialized = true; }
    FrameAnimation {
        id: frames
        onTriggered: {
            ++root.frameCount;
            const next = Motion.step(root.value, root.velocity, root.target, frameTime);
            root.value = next[0]; root.velocity = next[1];
            running = root.value !== root.target || root.velocity !== 0;
        }
    }
}
