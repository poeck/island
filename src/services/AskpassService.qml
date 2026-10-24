import QtQuick
import Quickshell.Io
import "../core"

Item {
    id: root
    property bool blocked: false
    property bool ready: false
    property var request: null
    readonly property bool active: request !== null && !blocked
    readonly property var flow: active ? adapter : null
    function receive(message) {
        if (message.event === "ready") ready = true;
        else if (message.event === "request") request = message;
        else if (message.event === "clear" && request && request.id === message.id) request = null;
    }
    function reply(response) {
        if (!active) return;
        daemon.write(JSON.stringify({id: request.id, response: response}) + "\n");
        request = null;
    }
    // Match the native Polkit AuthFlow interface consumed by AuthView.
    QtObject {
        id: adapter
        readonly property string actionId: "sudo"
        readonly property string message: root.request ? root.request.action : ""
        readonly property string context: root.request ? "Run as: " + root.request.target + "\nDirectory: " + root.request.directory : ""
        readonly property string inputPrompt: root.request ? root.request.prompt : ""
        readonly property bool isResponseRequired: root.active
        readonly property bool responseVisible: false
        readonly property var identities: []
        property var selectedIdentity: null
        readonly property string supplementaryMessage: ""
        readonly property bool supplementaryIsError: false
        function submit(response) { root.reply(response); }
        function cancelAuthenticationRequest() { root.reply(null); }
    }
    Process {
        id: daemon
        command: [Settings.executable, "internal", "askpass-bridge"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try { root.receive(JSON.parse(data)); }
                catch (_) { console.error("Island: invalid askpass broker message."); }
            }
        }
        // Qt's process exit enum is missing from Quickshell tooling metadata.
        // qmllint disable signal-handler-parameters
        onExited: { root.ready = false; root.request = null; }
        // qmllint enable signal-handler-parameters
    }
}
