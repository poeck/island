// PanelWindow is provided by the Wayland backend at runtime.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../ui"
import "../core"

PanelWindow {
    id: root
    required property date date
    property var snapshot: null
    signal dismiss()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-lock-preview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: Theme.background
    FrozenBackdrop { anchors.fill: parent; snapshot: root.snapshot; showcase: Settings.showcase }
    LockContent { anchors.fill: parent; date: root.date; preview: true; onPreviewDismiss: root.dismiss() }
}
