import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"
import "../ui"

FocusScope {
    id: root
    property var flow: null
    property bool demo: false
    property bool active: false
    property string demoError: ""
    signal demoFinished()
    readonly property bool responseRequired: demo || !!(flow && flow.isResponseRequired)
    onActiveChanged: { password.clear(); if (active) Qt.callLater(() => password.forceActiveFocus()); }
    onFlowChanged: { password.clear(); if (active) Qt.callLater(() => password.forceActiveFocus()); }
    Connections {
        target: root.flow
        function onIsResponseRequiredChanged() { if (root.active && root.responseRequired) Qt.callLater(() => password.forceActiveFocus()); }
        function onSelectedIdentityChanged() { password.clear(); }
    }
    function cancel() { password.clear(); if (demo) demoFinished(); else if (flow) flow.cancelAuthenticationRequest(); }
    function submit() {
        if (!responseRequired || !password.text) return;
        const response = password.text; password.clear();
        if (demo) { demoError = "Preview only — no authentication was attempted."; return; }
        flow.submit(response);
    }
    implicitHeight: layout.implicitHeight + 2 * Theme.contentMargin + 4
    ColumnLayout {
        id: layout
        anchors.fill: parent; anchors.margins: Theme.contentMargin; anchors.topMargin: Theme.contentMargin + 4; spacing: 10
        RowLayout {
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 9; color: Theme.raised; border.color: Theme.border
                Icon { anchors.centerIn: parent; name: "lock"; width: 16; height: 16; color: Theme.text }
            }
            ColumnLayout {
                spacing: 1
                Label { text: "Authentication required"; font.pixelSize: Theme.textTitle; font.weight: Theme.weightSemibold }
                Label { text: root.demo ? "org.island.preview" : root.flow ? root.flow.actionId : ""; color: Theme.muted; font.pixelSize: Theme.textCaption }
            }
        }
        Label { Layout.fillWidth: true; Layout.topMargin: 4; text: root.demo ? "Authentication is needed to perform a privileged action." : root.flow ? root.flow.message : ""; color: Theme.secondary; wrapMode: Text.Wrap; maximumLineCount: 3; lineHeight: 1.15 }
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.flow && root.flow.actionId === "sudo" ? root.flow.context : ""
            color: Theme.muted; font.pixelSize: Theme.textSmall
            wrapMode: Text.Wrap; maximumLineCount: 3
        }
        ComboBox {
            id: identity
            font.family: Theme.font; font.pixelSize: Theme.textBody
            font.styleName: ""; font.weight: Theme.weightMedium
            onFontChanged: Theme.syncFontWeight(identity)
            palette.buttonText: Theme.text; palette.text: Theme.text; palette.base: Theme.surface
            palette.window: Theme.surface; palette.highlight: Theme.selection; palette.highlightedText: Theme.text
            background: Rectangle { radius: Theme.radiusControl; color: identity.hovered ? Theme.raised : Theme.surface; border.color: identity.visualFocus ? Theme.focus : Theme.borderStrong }
            visible: !root.demo && root.flow && root.flow.identities.length > 1
            Layout.fillWidth: true; Layout.preferredHeight: 34
            model: root.flow ? root.flow.identities : []
            textRole: "displayName"
            onActivated: if (root.flow) root.flow.selectedIdentity = root.flow.identities[currentIndex]
        }
        Input {
            id: password; Layout.fillWidth: true; Layout.topMargin: 4
            placeholderText: root.demo ? "Password" : root.flow ? root.flow.inputPrompt || "Password" : ""
            echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
            enabled: root.responseRequired
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
            onAccepted: root.submit()
        }
        Label { Layout.fillWidth: true; visible: text !== ""; text: root.demo ? root.demoError : root.flow ? root.flow.supplementaryMessage : ""; color: root.demo ? Theme.warning : root.flow && root.flow.supplementaryIsError ? Theme.error : Theme.secondary; font.pixelSize: Theme.textSmall; maximumLineCount: 2; wrapMode: Text.Wrap }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.alignment: Qt.AlignRight; spacing: 8
            ActionButton { text: "Cancel"; onClicked: root.cancel() }
            ActionButton { text: "Authenticate"; accent: true; enabled: root.responseRequired && password.text.length > 0; onClicked: root.submit() }
        }
    }
}
