import QtQuick
import Quickshell.Io
import "../core"

Item {
    id: root
    signal changed(real value)
    Process {
        command: [Settings.executable, "internal", "watch-backlight"]
        running: !Settings.preview
        stdout: SplitParser {
            onRead: data => {
                try { const event = JSON.parse(data); if (event.changed) root.changed(event.value); }
                catch (e) { console.warn("Island: invalid backlight event"); }
            }
        }
    }
}
