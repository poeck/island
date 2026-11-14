import QtQuick
import Quickshell.Io
import "../core"

Item {
    id: root
    property var pending: []
    // UI status only: which pam-u2f services are currently waiting for a touch.
    readonly property bool sudo: pending.includes("sudo")
    readonly property bool polkit: pending.includes("polkit")
    readonly property bool administrative: sudo || polkit
    readonly property bool locking: pending.includes("lock")
    Process {
        id: monitor
        command: [Settings.executable, "internal", "watch-security-keys"]
        running: Settings.securityKeysEnabled
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data);
                    root.pending = Array.isArray(value.pending) ? value.pending : [];
                } catch (_) { root.pending = []; }
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: { root.pending = []; retry.restart(); }
        // qmllint enable signal-handler-parameters
    }
    Timer { id: retry; interval: 2000; onTriggered: if (Settings.securityKeysEnabled) monitor.running = true }
}
