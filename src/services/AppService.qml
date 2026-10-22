import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/Search.js" as Search

Item {
    id: root
    property string query: ""
    property int selection: 0
    property var history: ({})
    property string error: ""
    property var visibleIds: []
    readonly property var catalog: DesktopEntries.applications.values
    readonly property var entries: catalog.filter(e => !e.noDisplay && (visibleIds.includes(e.id) || visibleIds.includes(e.id + ".desktop")))
    onCatalogChanged: visibilityRefresh.restart()
    readonly property var results: Search.rank(entries, query, history)
    onQueryChanged: { selection = 0; error = ""; }
    onResultsChanged: selection = Math.max(0, Math.min(selection, results.length - 1))
    function move(delta) { if (results.length) selection = (selection + delta + results.length) % results.length; }
    function launch(index) {
        const entry = results[index];
        if (!entry) return false;
        let args = Array.from(entry.command);
        if (!args.length) { error = "This application has no launch command."; return false; }
        if (entry.runInTerminal) args = Array.from(Settings.terminal).concat(args);
        Quickshell.execDetached({command: args, workingDirectory: entry.workingDirectory});
        const next = Object.assign({}, history); next[entry.id] = Date.now(); history = next;
        historyFile.setText(JSON.stringify(next));
        query = ""; return true;
    }
    FileView {
        id: historyFile
        path: Settings.stateDirectory + "/launch-history.json"
        printErrors: false
        onLoaded: {
            try { const value = JSON.parse(text()); if (value && typeof value === "object") root.history = value; }
            catch (e) { root.history = {}; }
        }
    }
    Timer { id: visibilityRefresh; interval: 60; running: true; onTriggered: visibility.running = true }
    Process {
        id: visibility
        command: [Settings.executable, "internal", "app-visibility"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.visibleIds = JSON.parse(text); }
                catch (e) { root.error = "Could not read application visibility."; }
            }
        }
    }
}
