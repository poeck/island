// PanelWindow is provided by the Wayland backend at runtime.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    property real topInset: 0
    property bool topVisible: true
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "island-corners"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}
    CornerCutouts { anchors.fill: parent; topInset: root.topInset; topVisible: root.topVisible }
}
