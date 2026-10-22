import QtQuick
import Quickshell
import Quickshell.Services.Pam
import "core"
ShellRoot {
    id: root
    property int successes: 0
    property int responses: 0
    property bool refuse: false
    QtObject {
        id: fakePam
        property bool active: false
        property bool responseRequired: false
        property bool messageIsError: false
        property string message: ""
        signal pamMessage()
        signal completed(int result)
        function start() { active = !root.refuse; return active; }
        function respond(value) { if (value !== "fixture") throw new Error("Unexpected test response"); ++root.responses; responseRequired = false; }
    }
    LockAuthController { id: auth; pam: fakePam; onAuthenticated: ++root.successes }
    function check(value, message) { if (!value) throw new Error(message); }
    Timer {
        interval: 100; running: true
        onTriggered: {
            try {
                auth.submit("fixture"); check(!fakePam.active, "No PAM before secure lock");
                auth.secure = true; root.refuse = true; auth.submit("fixture");
                check(!auth.busy && auth.error && auth.pendingResponse === "", "Start refusal clears secret");
                root.refuse = false; auth.submit("fixture"); fakePam.responseRequired = true;
                check(root.responses === 1 && auth.pendingResponse === "", "Initial prompt consumes secret exactly once");
                fakePam.active = false; fakePam.completed(PamResult.Failed);
                check(root.successes === 0 && !auth.busy && auth.error, "Wrong password stays locked");
                auth.submit("fixture"); fakePam.responseRequired = true;
                fakePam.message = "Second factor"; fakePam.responseRequired = true;
                check(!auth.busy, "Second conversation prompt accepts input");
                auth.submit("fixture"); check(root.responses === 3, "Second prompt responds");
                fakePam.active = false; fakePam.completed(PamResult.Error);
                check(root.successes === 0, "PAM error stays locked");
                auth.submit("fixture"); fakePam.responseRequired = true;
                fakePam.active = false; fakePam.completed(PamResult.Success);
                check(root.successes === 1, "Only success unlocks");
                console.info("AUTH_TEST_PASS");
            } catch (error) { console.error("AUTH_TEST_FAIL", error); }
            Qt.quit();
        }
    }
}
