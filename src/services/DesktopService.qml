import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../core/Displays.js" as Displays

Item {
    id: root
    readonly property var screens: Quickshell.screens
    readonly property var monitors: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? Hyprland.monitors.values : []
    readonly property var screen: Displays.select(screens, monitors, Settings.monitor)
    readonly property var monitor: screen ? monitors.find(m => m.name === screen.name) || null : null
    readonly property bool fullscreen: !!(monitor && monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen)
}
