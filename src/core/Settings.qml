pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property var config: {
        try { return JSON.parse(Quickshell.env("ISLAND_CONFIG") || "{}"); }
        catch (e) { console.error("Island: invalid configuration", e); return {}; }
    }
    readonly property bool preview: Quickshell.env("ISLAND_MODE") !== "live"
    readonly property bool showcase: Quickshell.env("ISLAND_SHOWCASE") === "1"
    readonly property bool reducedMotion: config.reducedMotion === true
    readonly property string monitor: config.monitor || "AOC Q27G4ZR"
    readonly property string pamService: config.pamService || "swaylock"
    readonly property string backlightDevice: config.backlightDevice || ""
    readonly property var terminal: config.terminal || ["alacritty", "-e"]
    readonly property bool notificationsEnabled: !preview && config.notifications === true
    readonly property bool polkitEnabled: !preview && config.polkit === true
    readonly property bool askpassEnabled: !preview && config.askpass === true
    readonly property string executable: Quickshell.env("ISLAND_EXECUTABLE") || "island"
    readonly property string user: Quickshell.env("USER") || "User"
    readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/island"
}
