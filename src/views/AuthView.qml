import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"
import "../ui"
import "../core/AuthText.js" as AuthText

FocusScope {
    id: root
    property var flow: null
    property bool demo: false
    // Demo only: "password" or "touch". Nothing is ever evaluated.
    property string demoStage: "password"
    property bool active: false
    // UI hint that this request's PAM stack is waiting for a key touch.
    property bool keyTouchPending: false
    property string demoError: ""
    signal demoFinished()
    // A touch-only notice for a request Island cannot answer or cancel.
    readonly property bool passive: !demo && !!(flow && flow.passive)
    property bool demoFallback: false
    readonly property bool demoTouch: demo && demoStage === "touch" && !demoFallback
    readonly property bool responseRequired: demo ? !demoTouch : !!(flow && flow.isResponseRequired)
    readonly property string supplementary: demo ? demoError : flow ? flow.supplementaryMessage || "" : ""
    readonly property bool supplementaryIsError: !demo && !!(flow && flow.supplementaryIsError)
    readonly property bool cue: !supplementaryIsError && AuthText.isTouchCue(supplementary)
    // prompt | touch | verifying
    readonly property string stage: responseRequired ? "prompt"
        : (demo ? demoTouch : keyTouchPending || passive || cue) ? "touch" : "verifying"
    readonly property string inputLabel: demo ? "Password" : flow ? AuthText.promptLabel(flow.inputPrompt, keyTouchPending || Settings.securityKeysEnabled) : ""
    property string attempt: ""
    readonly property string errorText: supplementaryIsError ? supplementary
        : !demo && flow && flow.failed ? AuthText.failureMessage(attempt || "other", false) : ""
    // A key that went unconfirmed hands over to the stack's next prompt.
    readonly property string fallbackText: attempt === "touch" && stage === "prompt" && inputLabel === "Password" ? "Security key not confirmed. You can use your password instead." : ""
    readonly property string noteText: errorText || (cue ? "" : supplementary) || fallbackText
    readonly property var details: !demo && flow && Array.isArray(flow.details) ? flow.details : []
    readonly property string source: demo ? "org.island.preview" : !flow ? "" : passive ? (flow.source || "") : flow.actionId

    function settle() {
        password.clear();
        if (!active) return;
        if (stage === "prompt") Qt.callLater(() => { if (root.active && root.stage === "prompt") password.forceActiveFocus(); });
        else root.forceActiveFocus();
    }
    onActiveChanged: { attempt = ""; demoFallback = false; demoError = ""; settle(); }
    onDemoStageChanged: demoFallback = false
    onFlowChanged: { attempt = ""; settle(); }
    onStageChanged: { if (stage === "touch" && !demo) attempt = "touch"; settle(); }
    onInputLabelChanged: password.clear()
    onErrorTextChanged: if (errorText && !Settings.reducedMotion) shake.restart()
    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onSelectedIdentityChanged() { password.clear(); }
    }
    function cancel() { password.clear(); if (demo) demoFinished(); else if (flow) flow.cancelAuthenticationRequest(); }
    function submit() {
        if (demoTouch) { demoFallback = true; return; }
        if (stage !== "prompt" || !password.text) return;
        const response = password.text; password.clear();
        if (demo) { demoError = "Preview only — no authentication was attempted."; return; }
        attempt = AuthText.promptKind(flow.inputPrompt);
        flow.submit(response);
    }
    Keys.onReturnPressed: submit()
    Keys.onEnterPressed: submit()
    implicitHeight: layout.implicitHeight + 2 * Theme.contentMargin + 4
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeOffset; property: "x"; to: -6; duration: 50; easing.type: Easing.OutCubic }
        NumberAnimation { target: shakeOffset; property: "x"; to: 4; duration: 70; easing.type: Easing.InOutCubic }
        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 70; easing.type: Easing.OutCubic }
    }
    ColumnLayout {
        id: layout
        anchors.fill: parent; anchors.margins: Theme.contentMargin; anchors.topMargin: Theme.contentMargin + 4; spacing: 10
        RowLayout {
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 9; color: Theme.raised; border.color: Theme.border
                Icon { anchors.centerIn: parent; name: root.passive ? "security-key" : "lock"; width: 16; height: 16; color: Theme.text }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Label { text: root.passive ? "Confirm with your security key" : "Authentication required"; font.pixelSize: Theme.textTitle; font.weight: Theme.weightSemibold }
                Label { Layout.fillWidth: true; visible: text !== ""; text: root.source; color: Theme.muted; font.pixelSize: Theme.textCaption; elide: Text.ElideMiddle }
            }
        }
        Label {
            Layout.fillWidth: true; Layout.topMargin: 4
            text: root.demo ? "Authentication is needed to perform a privileged action." : root.flow ? root.flow.message : ""
            color: Theme.secondary; wrapMode: Text.Wrap; maximumLineCount: 3; lineHeight: 1.15
        }
        // Request context, shown only when the requester supplied it.
        GridLayout {
            Layout.fillWidth: true; visible: root.details.length > 0
            columns: 2; columnSpacing: 12; rowSpacing: 3
            Repeater {
                model: root.details.length * 2
                Label {
                    required property int index
                    readonly property var entry: root.details[Math.floor(index / 2)]
                    readonly property bool isValue: index % 2 === 1
                    Layout.fillWidth: isValue
                    text: entry ? (isValue ? entry.value : entry.label) : ""
                    color: isValue ? Theme.secondary : Theme.muted
                    font.pixelSize: Theme.textSmall
                    elide: Text.ElideMiddle
                }
            }
        }
        ComboBox {
            id: identity
            font.family: Theme.font; font.pixelSize: Theme.textBody
            font.styleName: ""; font.weight: Theme.weightMedium
            onFontChanged: Theme.syncFontWeight(identity)
            palette.buttonText: Theme.text; palette.text: Theme.text; palette.base: Theme.surface
            palette.window: Theme.surface; palette.highlight: Theme.selection; palette.highlightedText: Theme.text
            background: Rectangle { radius: Theme.radiusControl; color: identity.hovered ? Theme.raised : Theme.surface; border.color: identity.visualFocus ? Theme.focus : Theme.borderStrong }
            visible: !root.demo && !root.passive && !!root.flow && !!root.flow.identities && root.flow.identities.length > 1
            Layout.fillWidth: true; Layout.preferredHeight: 34
            model: visible ? root.flow.identities : []
            textRole: "displayName"
            onActivated: if (root.flow) root.flow.selectedIdentity = root.flow.identities[currentIndex]
        }
        // One slot for the current step; steps cross-fade without resizing.
        Item {
            Layout.fillWidth: true; Layout.topMargin: 4; Layout.preferredHeight: 40
            transform: Translate { id: shakeOffset }
            Input {
                id: password
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                opacity: root.stage === "prompt" ? 1 : 0; visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Settings.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
                placeholderText: root.inputLabel
                echoMode: !root.demo && root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                enabled: root.stage === "prompt"
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                onAccepted: root.submit()
            }
            SecurityKeyHint {
                anchors.left: parent.left; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter
                opacity: root.stage === "touch" ? 1 : 0; visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Settings.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
                waiting: root.active && root.stage === "touch"; glyphSize: 34
                detail: "Its light may blink while it waits"
            }
            Label {
                anchors.left: parent.left; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter
                opacity: root.stage === "verifying" ? 1 : 0; visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Settings.reducedMotion ? 0 : 140 } }
                text: "Verifying…"; color: Theme.secondary
            }
        }
        Label {
            Layout.fillWidth: true; visible: text !== ""
            text: root.noteText
            color: root.demo ? Theme.warning : root.errorText ? Theme.error : Theme.secondary
            font.pixelSize: Theme.textSmall; maximumLineCount: 2; wrapMode: Text.Wrap
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Label {
                Layout.fillWidth: true
                text: root.demoTouch ? "Preview · Enter shows the password fallback"
                    : root.passive ? root.flow.cancelHint || "" : ""
                color: Theme.muted; font.pixelSize: Theme.textCaption
            }
            ActionButton { text: root.passive ? "Hide" : "Cancel"; onClicked: root.cancel() }
            ActionButton { text: "Authenticate"; visible: root.stage === "prompt"; accent: true; enabled: password.text.length > 0; onClicked: root.submit() }
        }
    }
}
