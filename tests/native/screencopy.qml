import QtQuick
import Quickshell
import Quickshell.Wayland
import Island.Test

// ScreenProbe is test-only. It reproduces the state between QScreen destruction
// and ShellScreen deletion without disconnecting a physical monitor.
ShellRoot {
    PanelWindow {
        implicitWidth: 100; implicitHeight: 100
        color: "#161616"
        ScreencopyView {
            id: frame
            width: 100; height: 100
            captureSource: Quickshell.screens[0]
            live: false
        }
        Timer {
            interval: 50; running: true; repeat: true
            onTriggered: {
                if (!frame.hasContent) return;
                stop();
                console.log("VALID_CAPTURE");
                if (!ScreenProbe.invalidate(frame.captureSource)) throw new Error("Screen invalidation failed");
                // Reinitializing buffers after resume follows the same manager path.
                frame.paintCursor = true;
                if (frame.hasContent) throw new Error("Dangling screen must not supply content");
                console.log("DANGLING_CAPTURE_DECLINED");
                Qt.quit();
            }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("Capture test timed out"); Qt.quit(); } }
}
