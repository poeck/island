import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../core"
import "../core/Audio.js" as Audio

Item {
    id: root
    signal changed(string kind, real value, bool muted)
    property bool demo: false
    property var backend: demo ? simulated : Pipewire
    property bool nativeTracking: !demo
    DemoAudioBackend { id: simulated }
    property bool expanded: false
    property bool osdEnabled: !Settings.preview
    readonly property var nodes: backend.nodes.values
    readonly property bool ready: backend.ready
    readonly property var sink: backend.defaultAudioSink
    readonly property var source: backend.defaultAudioSource
    readonly property var outputs: nodes.filter(n => n.audio && !n.isStream && n.isSink)
    readonly property var inputs: nodes.filter(n => n.audio && !n.isStream && !n.isSink && !n.name.endsWith(".monitor"))
    readonly property var streams: nodes.filter(n => n.audio && n.isStream)
    readonly property var applications: expanded ? Audio.groups(streams) : []
    readonly property var effectsEntry: DesktopEntries.applications.values.find(entry => /easyeffects/i.test(entry.id)) || null
    readonly property var trackedNodes: expanded ? nodes.filter(n => n.audio) : [sink, source].filter(n => n !== null)
    function deviceName(node) { return Audio.deviceName(node); }
    function deviceKind(node) { return Audio.deviceKind(node); }
    function volume(list) { return Audio.volume(list); }
    function muted(list) { return Audio.muted(list); }
    function setVolume(list, value) {
        for (const node of list) if (nodes.includes(node) && node.ready && node.audio) node.audio.volume = Audio.gain(value);
    }
    function toggleMute(list) {
        const value = !Audio.muted(list);
        for (const node of list) if (nodes.includes(node) && node.ready && node.audio) node.audio.muted = value;
    }
    function selectOutput(node) { if (outputs.includes(node) && node.ready) backend.preferredDefaultAudioSink = node; }
    function selectInput(node) { if (inputs.includes(node) && node.ready) backend.preferredDefaultAudioSource = node; }
    function openEffects() { if (effectsEntry) effectsEntry.execute(); }
    property bool sinkSettled: false
    readonly property bool sinkReady: sinkSettled && !!(sink && sink.ready)
    property bool sourceSettled: false
    readonly property bool sourceReady: sourceSettled && !!(source && source.ready)
    onSinkChanged: { sinkSettled = false; baseline.restart(); }
    onSourceChanged: { sourceSettled = false; baseline.restart(); }
    PwObjectTracker { objects: root.nativeTracking ? root.trackedNodes : [] }
    Timer {
        id: baseline; interval: 350; running: true
        onTriggered: { root.sinkSettled = true; root.sourceSettled = true; }
    }
    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumesChanged() { if (root.osdEnabled && root.sinkReady) root.changed("volume", Math.round(root.sink.audio.volume * 100), root.sink.audio.muted); }
        function onMutedChanged() { if (root.osdEnabled && root.sinkReady) root.changed("volume", Math.round(root.sink.audio.volume * 100), root.sink.audio.muted); }
    }
    Connections {
        target: root.source ? root.source.audio : null
        function onMutedChanged() { if (root.osdEnabled && root.sourceReady) root.changed("mic", root.source.audio.muted ? 0 : 100, root.source.audio.muted); }
    }
}
