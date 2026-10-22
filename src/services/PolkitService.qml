import QtQuick
import Quickshell.Services.Polkit

Item {
    // Native AuthFlow is exposed at runtime but incompletely declared in 0.3.2 qmltypes.
    // qmllint disable unresolved-type
    readonly property var flow: agent.flow
    // qmllint enable unresolved-type
    readonly property alias active: agent.isActive
    readonly property alias registered: agent.isRegistered
    PolkitAgent { id: agent; path: "/org/island/Polkit" }
    Timer {
        interval: 1500; running: true
        onTriggered: if (!agent.isRegistered) console.error("Island: polkit registration failed; another agent may already own this session. See island doctor.")
    }
}
