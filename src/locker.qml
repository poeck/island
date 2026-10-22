//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "core"
import "views"
import "ui"

ShellRoot {
    id: root
    property string error: ""
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Component.onCompleted: Quickshell.watchFiles = false
    CapturePool { id: captures; onReady: { lock.locked = true; acquisition.start(); } }
    Timer {
        id: acquisition; interval: 4000
        onTriggered: if (!lock.secure) { root.error = "The compositor refused the session lock."; console.error(root.error); Qt.quit(); }
    }
    PamContext { id: pam; config: Settings.pamService; user: Settings.user }
    LockAuthController {
        id: authentication
        pam: pam; secure: lock.secure
        onAuthenticated: { lock.locked = false; unlockNotice.running = true; }
    }
    WlSessionLock {
        id: lock
        onSecureChanged: if (secure) { acquisition.stop(); lockNotice.running = true; }
        surface: WlSessionLockSurface {
            id: surface
            color: "black"
            FrozenBackdrop { anchors.fill: parent; snapshot: captures.take(surface.screen) }
            LockContent {
                anchors.fill: parent; date: clock.date
                busy: authentication.busy; message: authentication.message; error: authentication.error
                responseVisible: pam.active && pam.responseVisible
                prompt: pam.active && pam.responseRequired ? pam.message : "Password"
                onResponse: value => authentication.submit(value)
            }
        }
    }
    Process { id: lockNotice; command: [Settings.executable, "internal", "locked", "true"] }
    // Quickshell 0.3.2 omits QProcess::ExitStatus from its tooling metadata.
    // qmllint disable signal-handler-parameters
    Process { id: unlockNotice; command: [Settings.executable, "internal", "locked", "false"]; onExited: Qt.quit() }
    // qmllint enable signal-handler-parameters
    IpcHandler {
        target: "lock"
        function status(): string { return JSON.stringify({secure: lock.secure, error: root.error, outputs: Quickshell.screens.map(s => s.name), captured: Object.keys(captures.frames).filter(k => captures.frames[k].accepted)}); }
    }
}
