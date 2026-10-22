import QtQuick
import Quickshell.Io
import "../core"

Item {
    id: root
    property bool active: true
    property bool demo: false
    property var status: ({available: false, profile: "", profiles: [], degraded: "", inhibited: "", holds: []})
    readonly property bool available: status.available
    readonly property string profile: status.profile
    readonly property var profiles: status.profiles
    readonly property string degraded: status.degraded
    readonly property string inhibited: status.inhibited
    readonly property var holds: status.holds
    property bool busy: false
    property int requestId: 0
    property string error: ""
    property string requested: ""
    readonly property string notice: error || (inhibited ? "Performance unavailable: " + reason(inhibited) : degraded ? "Performance limited: " + reason(degraded) : holds.length ? "Application requests: " + holds.map(h => h.reason || h.app || title(h.profile)).join(" · ") + ". Choosing another profile overrides these requests." : "")
    function title(value) { return value === "power-saver" ? "Power Saver" : value === "performance" ? "Performance" : value === "balanced" ? "Balanced" : "Unknown"; }
    function reason(value) { return value === "lap-detected" ? "lap detection is active" : value === "high-operating-temperature" ? "the system is too hot" : value.replace(/-/g," "); }
    function select(value) {
        if (!active || busy || !available || !profiles.includes(value) || value === profile || (value === "performance" && inhibited)) return;
        error = "";
        if (demo) { status = Object.assign({},status,{profile:value,holds:[]}); return; }
        if (!watcher.running) { error = "Power-profile service is not connected. Reopen the system panel to retry."; return; }
        busy = true; requested = value;
        watcher.write(JSON.stringify({id:++requestId,profile:value}) + "\n");
    }
    function receive(value) {
        if (value.event === "state") status = value;
        else if (value.event === "result" && value.id === requestId) { busy = false; requested = ""; if (!value.ok) error = value.error; }
    }
    function reset() {
        busy = false; requested = ""; error = "";
        status = demo ? {available:true,profile:"balanced",profiles:["power-saver","balanced","performance"],degraded:"",inhibited:"",holds:[]} : {available:false,profile:"",profiles:[],degraded:"",inhibited:"",holds:[]};
    }
    onDemoChanged: { reset(); watcher.running = active && !demo; }
    onActiveChanged: {
        if (!active) { busy = false; requested = ""; }
        watcher.running = active && !demo;
    }
    Process {
        id: watcher
        command: [Settings.executable,"internal","watch-power-profiles"]
        running: root.active && !root.demo
        stdinEnabled: true
        stdout: SplitParser { onRead: data => { try { if (!root.demo) root.receive(JSON.parse(data)); } catch (_) { root.error = "Could not read power-profile status."; } } }
        onRunningChanged: if (!running && root.active && !root.demo) retry.restart()
        // Qt's process exit enum is absent from the QML tooling metadata.
        // qmllint disable signal-handler-parameters
        onExited: if (!root.demo) { root.busy = false; root.requested = ""; root.status = {available:false,profile:"",profiles:[],degraded:"",inhibited:"",holds:[]}; }
        // qmllint enable signal-handler-parameters
    }
    Timer { id: retry; interval: 5000; onTriggered: if (root.active && !root.demo) watcher.running = true }
}
