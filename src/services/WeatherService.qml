import QtQuick
import Quickshell.Io
import "../core"
import "../core/Weather.js" as Weather

Item {
    id: root
    property bool expanded: false
    property bool demo: false
    // Overridden only by the isolated native fixture; never expose endpoint overrides.
    property var requestCommand: [Settings.executable, "internal", "weather-request"]
    property var location: ({name:"Vienna",country:"Austria",latitude:48.2085,longitude:16.3721,timezone:"Europe/Vienna"})
    property var liveData: null
    readonly property var forecastData: demo ? sample : liveData
    readonly property var sample: Weather.demo()
    property bool stale: false
    property string error: ""
    property string query: ""
    property var results: []
    property bool searched: false
    property string searchError: ""
    readonly property bool loading: !demo && (reader.running || pending !== null)
    readonly property bool searching: !demo && (searcher.running || debounce.running)
    property int revision: 0
    property var pending: null
    property var currentRequest: null
    property string searchQuery: ""
    function enqueue(request) { pending = {request:request, revision:revision}; pump(); }
    function pump() {
        if (demo || reader.running || pending === null) return;
        currentRequest = pending; pending = null;
        reader.command = requestCommand.concat([JSON.stringify(currentRequest.request)]);
        reader.running = true;
    }
    function load() { if (!demo) enqueue({op:"load"}); }
    function refresh(force) { if (!demo) enqueue({op:"forecast",location:location,force:!!force}); }
    function choose(city) {
        if (demo) return;
        revision++; location = city; liveData = null; error = ""; results = []; query = "";
        refresh(false);
    }
    function search() {
        if (demo || !expanded || query.trim().length < 2) { results=[]; searched=false; return; }
        if (searcher.running) return;
        searchQuery = query.trim(); searched=false; searchError="";
        searcher.command = requestCommand.concat([JSON.stringify({op:"search",query:searchQuery})]);
        searcher.running = true;
    }
    onQueryChanged: { results=[]; searched=false; searchError=""; debounce.restart(); }
    onExpandedChanged: {
        if (expanded) { if (!demo) load(); }
        else { query=""; results=[]; debounce.stop(); }
    }
    onDemoChanged: {
        revision++; pending=null; error=""; query=""; results=[];
        if (!demo && expanded) Qt.callLater(load);
    }
    Timer { id: debounce; interval:350; onTriggered: root.search() }
    Timer { interval:900000; repeat:true; running:root.expanded && !root.demo; onTriggered:root.refresh(false) }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.demo || !root.currentRequest || root.currentRequest.revision !== root.revision) return;
                try {
                    const result=JSON.parse(text);
                    if (result.location) root.location=result.location;
                    root.liveData=result.data || null; root.stale=!!result.stale; root.error=result.error || "";
                    if (root.currentRequest.request.op === "load" && root.expanded && !result.error)
                        root.pending={request:{op:"forecast",location:root.location},revision:root.revision};
                } catch (_) { root.error="Could not read weather. Please retry."; }
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: Qt.callLater(root.pump)
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: searcher
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.demo || !root.expanded || root.query.trim() !== root.searchQuery) return;
                try { const result=JSON.parse(text); root.results=result.results || []; root.searchError=result.error || ""; root.searched=true; }
                catch (_) { root.searchError="City search unavailable. Please retry."; root.searched=true; }
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: if (root.query.trim() !== root.searchQuery && root.expanded) Qt.callLater(root.search)
        // qmllint enable signal-handler-parameters
    }
}
