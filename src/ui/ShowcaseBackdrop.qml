// PanelWindow is provided by the Wayland backend at runtime.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "island-showcase"
    mask: Region {}
    ShowcaseArt { anchors.fill: parent }
}
