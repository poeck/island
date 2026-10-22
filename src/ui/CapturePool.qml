// PanelWindow is provided by the Wayland backend at runtime.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland

// A mapped, transparent surface initializes Qt's capture buffers. No pixels leave RAM.
Item {
    id: root
    property bool finished: false
    signal ready()
    property var frames: ({})
    function take(screen) {
        if (!screen) return null;
        const frame = frames[screen.name];
        return frame && frame.accepted ? frame : null;
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            for (const key of Object.keys(root.frames)) root.frames[key].accepted = root.frames[key].hasContent;
            root.finished = true;
            root.ready();
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: host
            required property var modelData
            screen: modelData
            implicitWidth: 1; implicitHeight: 1
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            anchors.top: true; anchors.left: true
            WlrLayershell.namespace: "island-capture"
            mask: Region {}
            ScreencopyView {
                id: frame
                property bool accepted: false
                property string outputName: ""
                width: host.modelData ? host.modelData.width : 0; height: host.modelData ? host.modelData.height : 0
                live: false; paintCursor: false; visible: false
                Component.onCompleted: {
                    outputName = host.modelData.name;
                    root.frames[outputName] = frame;
                    if (!root.finished) captureSource = host.modelData;
                }
                Component.onDestruction: delete root.frames[outputName]
            }
        }
    }
}
