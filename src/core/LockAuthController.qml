import QtQuick
import Quickshell.Services.Pam
import "AuthText.js" as AuthText

// Drives the locker's PAM conversation and derives what the lock surface shows.
// Presentation only: PamContext.completed(Success) is the sole unlock path, and
// responses are passed straight through without being retained.
Item {
    id: root
    required property var pam
    property bool secure: false
    // UI hint from the pending-touch observer; never an authentication input.
    property bool keyTouch: false
    property string service: Settings.pamService
    property string nextService: ""
    readonly property bool switching: nextService !== ""
    // starting | prompt | touch | verifying | failed
    readonly property string stage: !secure || switching || pendingStart ? "starting"
        : pam.active ? (pam.responseRequired ? "prompt" : touching ? "touch" : "verifying")
        : failed ? "failed" : "starting"
    readonly property bool touching: pam.active && !pam.responseRequired && (keyTouch || cue)
    readonly property bool busy: stage !== "prompt"
    // The last prompt label survives restarts, so the field does not flicker
    // through an empty or generic label while PAM begins the next attempt.
    property string prompt: ""
    readonly property bool responseVisible: pam.active && pam.responseRequired && pam.responseVisible
    // The explicitly configured password service, or the way back from it.
    readonly property string alternative: Settings.passwordPamService === "" ? ""
        : (switching ? nextService : service) === Settings.passwordPamService ? Settings.pamService : Settings.passwordPamService
    readonly property string alternativeLabel: alternative === "" ? ""
        : alternative === Settings.passwordPamService ? "Use password instead"
        : Settings.securityKeysEnabled ? "Use security key instead" : "Use default sign-in"
    property string message: ""
    property bool error: false
    property bool failed: false
    property bool pendingStart: false
    property bool cue: false
    property bool responded: false
    // The step the user last acted on in this conversation ("" before any).
    property string attempt: ""
    signal authenticated()

    function start() {
        if (!secure || switching || pam.active) return;
        failed = false; cue = false; attempt = ""; responded = false;
        if (!pam.start()) { failed = true; message = "Couldn't start authentication."; error = true; }
    }
    // Begin once PAM is idle, after any abort or completion has settled.
    function schedule() { pendingStart = true; Qt.callLater(flush); }
    function flush() {
        if (!pendingStart || pam.active) return;
        pendingStart = false;
        if (!secure) return;
        if (switching) { service = nextService; nextService = ""; prompt = ""; }
        start();
    }
    function retry() {
        if (stage !== "failed") return;
        message = ""; error = false;
        schedule();
    }
    function submit(value) {
        if (stage !== "prompt") return;
        attempt = AuthText.promptKind(pam.message); responded = true;
        message = ""; error = false;
        pam.respond(value);
    }
    function chooseService(value) {
        if (!secure || !value || value === (switching ? nextService : service)) return;
        nextService = value; message = ""; error = false; failed = false;
        if (pam.active) pam.abort();
        schedule();
    }
    function useAlternative() { chooseService(alternative); }
    onTouchingChanged: if (touching) attempt = "touch"
    onSecureChanged: {
        if (secure) schedule();
        else { nextService = ""; pendingStart = false; if (pam.active) pam.abort(); }
    }
    Connections {
        target: root.pam
        function onPamMessage() {
            if (root.pam.responseRequired) {
                root.cue = false;
                root.prompt = AuthText.promptLabel(root.pam.message, Settings.securityKeysEnabled);
                return;
            }
            // pam-u2f's optional cue duplicates the touch state; show the state.
            if (!root.pam.messageIsError && AuthText.isTouchCue(root.pam.message)) { root.cue = true; return; }
            root.message = root.pam.message; root.error = root.pam.messageIsError;
        }
        function onActiveChanged() { if (!root.pam.active && root.pendingStart) Qt.callLater(root.flush); }
        function onCompleted(result) {
            if (!root.secure || root.switching) return;
            if (result === PamResult.Success) { root.authenticated(); return; }
            root.message = result === PamResult.Failed ? AuthText.failureMessage(root.attempt, Settings.securityKeysEnabled)
                : "Authentication is unavailable right now.";
            root.error = true; root.failed = true; root.cue = false;
            // Re-arm only after a typed response, so an absent key, an untouched
            // key or a broken stack cannot loop; otherwise wait for Try again.
            if (result === PamResult.Failed && root.responded) root.schedule();
        }
    }
}
