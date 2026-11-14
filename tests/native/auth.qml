import QtQuick
import Quickshell
import Quickshell.Services.Pam
import "core"
ShellRoot {
    id: root
    property int successes: 0
    property int responses: 0
    property int starts: 0
    property int aborts: 0
    property bool refuse: false
    property int step: 0
    QtObject {
        id: fakePam
        property bool active: false
        property bool responseRequired: false
        property bool responseVisible: false
        property bool messageIsError: false
        property string message: ""
        signal pamMessage()
        signal completed(int result)
        function start() { ++root.starts; active = !root.refuse; return active; }
        function respond(value) { if (value !== "fixture") throw new Error("Unexpected test response"); ++root.responses; responseRequired = false; }
        function abort() { ++root.aborts; active = false; responseRequired = false; completed(PamResult.Error); }
        function ask(text) { message = text; responseRequired = true; pamMessage(); }
        function info(text) { message = text; responseRequired = false; messageIsError = false; pamMessage(); }
        function finish(result) { active = false; responseRequired = false; completed(result); }
    }
    LockAuthController { id: auth; pam: fakePam; onAuthenticated: ++root.successes }
    function check(value, message) { if (!value) throw new Error(message + " (stage " + auth.stage + ")"); }
    // Each step runs after the controller's deferred restarts have settled.
    readonly property var steps: [
        () => {
            auth.submit("fixture");
            check(root.starts === 0 && auth.stage === "starting", "No PAM before secure lock");
            root.refuse = true; auth.secure = true;
        },
        () => {
            check(root.starts === 1 && auth.stage === "failed" && auth.error, "Start refusal waits for an explicit retry");
            root.refuse = false; auth.retry();
        },
        () => {
            check(fakePam.active && auth.stage === "verifying", "Retry starts a conversation");
            auth.submit("fixture"); check(root.responses === 0, "No response without a prompt");
            fakePam.ask("Password: ");
            check(auth.stage === "prompt" && auth.prompt === "Password", "Prompt label");
            auth.submit("fixture");
            check(root.responses === 1 && auth.stage === "verifying", "Response is passed through once");
            fakePam.finish(PamResult.Failed);
            check(root.successes === 0 && auth.error && auth.message.includes("password"), "Wrong password stays locked");
        },
        () => {
            check(root.starts === 3 && fakePam.active && auth.error, "A typed failure re-arms with its message kept");
            // PIN-only: the prompt goes straight to completion, never to touch.
            fakePam.ask("Please enter the PIN: ");
            check(auth.stage === "prompt" && auth.prompt.includes("PIN") && auth.message !== "", "PIN prompt");
            auth.submit("fixture");
            check(auth.stage === "verifying" && auth.message === "" && !auth.error, "Submitted PIN verifies without a touch step");
            fakePam.finish(PamResult.Failed);
            check(auth.message.includes("PIN"), "PIN failure names the PIN");
        },
        () => {
            check(root.starts === 4 && fakePam.active, "PIN failure re-arms");
            // A pending-touch marker during PIN acquisition must not hide the field.
            auth.keyTouch = true; fakePam.ask("Please enter the PIN: ");
            check(auth.stage === "prompt", "Prompt outranks the touch marker");
            auth.submit("fixture"); check(auth.stage === "touch", "Touch shown only while PAM waits");
            auth.keyTouch = false; check(auth.stage === "verifying", "Touch follows the marker");
            fakePam.info("Please touch the device."); check(auth.stage === "touch", "pam-u2f cue shows touch");
            fakePam.finish(PamResult.Failed);
            check(auth.message.includes("security key"), "Unconfirmed key is named");
        },
        () => {
            check(root.starts === 5, "Typed PIN then untouched key re-arms once");
            fakePam.finish(PamResult.Failed);
            check(auth.stage === "failed", "Untouched key without input waits for retry");
        },
        () => {
            check(root.starts === 5 && auth.stage === "failed", "No loop without a typed response");
            auth.retry();
        },
        () => {
            check(root.starts === 6 && fakePam.active, "Explicit retry");
            auth.chooseService("fixture-password");
            check(root.aborts === 1 && auth.stage === "starting" && auth.message === "", "Switch aborts silently");
        },
        () => {
            check(auth.service === "fixture-password" && root.starts === 7 && fakePam.active && !auth.switching, "Switch restarts with the chosen service");
            fakePam.ask("Password: "); fakePam.finish(PamResult.Error);
            check(root.successes === 0 && auth.stage === "failed", "PAM error stays locked");
        },
        () => {
            check(root.starts === 7, "PAM error is not retried automatically");
            auth.retry();
        },
        () => {
            fakePam.ask("Password: "); auth.submit("fixture"); fakePam.finish(PamResult.Success);
            check(root.successes === 1, "Only success unlocks");
            auth.secure = false; check(auth.stage === "starting", "Unsecured lock shows no input");
        }
    ]
    Timer {
        interval: 60; running: true; repeat: true
        onTriggered: {
            try {
                root.steps[root.step++]();
                if (root.step < root.steps.length) return;
                console.info("AUTH_TEST_PASS");
            } catch (error) { console.error("AUTH_TEST_FAIL", error); }
            stop(); Qt.quit();
        }
    }
}
