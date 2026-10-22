import QtQuick
import Quickshell.Services.Pam

Item {
    id: root
    required property var pam
    property bool secure: false
    property bool busy: false
    property string message: ""
    property bool error: false
    property string pendingResponse: ""
    signal authenticated()
    function submit(value) {
        if (!secure || busy) return;
        message = ""; error = false; busy = true;
        if (pam.active && pam.responseRequired) pam.respond(value);
        else {
            pendingResponse = value;
            if (!pam.start()) {
                pendingResponse = ""; busy = false;
                message = "Could not start authentication."; error = true;
            }
        }
    }
    Connections {
        target: root.pam
        function onPamMessage() {
            if (!root.pam.responseRequired) root.message = root.pam.message;
            root.error = root.pam.messageIsError;
        }
        function onResponseRequiredChanged() {
            root.busy = root.pam.active && !root.pam.responseRequired;
            if (root.pam.responseRequired && root.pendingResponse) {
                const response = root.pendingResponse;
                root.pendingResponse = ""; root.busy = true;
                root.pam.respond(response);
            }
        }
        function onCompleted(result) {
            root.busy = false; root.pendingResponse = "";
            if (result === PamResult.Success) root.authenticated();
            else {
                root.message = result === PamResult.Failed ? "That password didn't work. Try again." : "Authentication is unavailable. Please try again.";
                root.error = true;
            }
        }
    }
}
