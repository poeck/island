import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import Quickshell.Services.UPower
import Quickshell.Networking
import "../core"
import "../ui"

FocusScope {
    id: root
    required property date date
    property bool preview: false
    // Preview the security key sequence (PIN, then touch). Never evaluated.
    property bool previewKey: false
    // starting | prompt | touch | verifying | failed (see LockAuthController)
    property string stage: "prompt"
    property bool responseVisible: false
    property string prompt: "Password"
    property string message: ""
    property bool error: false
    // Label of the explicitly configured alternative method, if any.
    property string alternative: ""
    signal response(string value)
    signal retry()
    signal useAlternative()
    signal previewDismiss()
    focus: true

    property bool previewWithKey: previewKey
    property bool previewTouching: false
    readonly property string shownStage: preview ? (previewTouching ? "touch" : "prompt") : stage
    readonly property string shownPrompt: preview ? (previewWithKey ? "Security key PIN" : "Password") : prompt
    readonly property string shownAlternative: preview ? (previewKey ? (previewWithKey ? "Use password instead" : "Use security key instead") : "") : alternative
    readonly property string shownMessage: !preview ? message
        : previewTouching ? "Preview · Enter or Esc to close"
        : previewWithKey ? "Preview · Enter continues to the touch step" : "Preview · Enter or Esc to close"

    function clear() { password.clear(); }
    function settle() {
        password.clear();
        if (shownStage === "prompt") Qt.callLater(() => { if (root.shownStage === "prompt") password.forceActiveFocus(); });
        else root.forceActiveFocus();
    }
    onShownStageChanged: settle()
    onShownPromptChanged: password.clear()
    function submit() {
        if (shownStage === "failed") { retry(); return; }
        if (preview) {
            password.clear();
            if (previewWithKey && !previewTouching) previewTouching = true;
            else previewDismiss();
            return;
        }
        if (shownStage === "prompt" && password.text.length) { const value = password.text; password.clear(); response(value); }
    }
    function alternate() {
        password.clear();
        if (preview) { previewWithKey = !previewWithKey; previewTouching = false; settle(); return; }
        useAlternative();
    }
    // A rejected attempt nudges the active control sideways, like a head shake.
    onErrorChanged: if (error && !Settings.reducedMotion) shake.restart()
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeOffset; property: "x"; to: -8; duration: 50; easing.type: Easing.OutCubic }
        NumberAnimation { target: shakeOffset; property: "x"; to: 6; duration: 70; easing.type: Easing.InOutCubic }
        NumberAnimation { target: shakeOffset; property: "x"; to: -3; duration: 60; easing.type: Easing.InOutCubic }
        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 60; easing.type: Easing.OutCubic }
    }
    Keys.onEscapePressed: { password.clear(); if (preview) previewDismiss(); }
    Keys.onReturnPressed: submit()
    Keys.onEnterPressed: submit()
    // Neutral scrim over the blurred desktop; white type at reduced alpha.
    Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.background, 0.35) }
    Row {
        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 24; spacing: 14
        Row {
            visible: UPower.displayDevice && UPower.displayDevice.isPresent; spacing: 6
            Label { anchors.verticalCenter: parent.verticalCenter; text: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) + "%" : ""; font.pixelSize: Theme.textSmall; font.weight: Theme.weightMedium; font.features: Theme.numeric; color: Qt.alpha("white", 0.8) }
            Icon { name: "battery"; width: 18; height: 18; color: Qt.alpha("white", 0.8) }
        }
        Icon { name: "wifi"; width: 18; height: 18; color: Qt.alpha("white", 0.8); visible: Networking.devices.values.some(d => d.connected) }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.12; spacing: 0
        Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(root.date, "dddd, d MMMM"); font.pixelSize: Theme.textHeading; font.weight: Theme.weightMedium; color: Qt.alpha("white", 0.78) }
        Label {
            readonly property real size: Math.min(156, root.width * 0.15)
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.date, "HH:mm")
            font.pixelSize: size; font.weight: Theme.weightSemibold; font.letterSpacing: -size * 0.045; font.features: Theme.numeric
            color: Qt.alpha("white", 0.94)
        }
    }
    ColumnLayout {
        id: column
        // Anchor the identity block; messages and the alternative grow below
        // it, so state changes never move the field under the user's eyes.
        readonly property real restingHeight: 52 + 12 + 24 + 4 + 12 + 40
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(16, Math.min(parent.height * 0.7, parent.height - restingHeight - 96))
        width: Math.min(320, parent.width - 60); spacing: 12
        Rectangle {
            Layout.alignment: Qt.AlignHCenter; implicitWidth: 52; implicitHeight: 52; radius: 26
            color: Qt.alpha("white", 0.1); border.color: Qt.alpha("white", 0.18); border.width: 1
            Icon { anchors.centerIn: parent; name: "user"; width: 24; height: 24; color: "white" }
        }
        Label { Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 4; text: Settings.user; font.pixelSize: Theme.textTitle; font.weight: Theme.weightSemibold; color: "white" }
        // One fixed slot holds the current step; steps cross-fade in place.
        Item {
            id: stageSlot
            Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 248; Layout.preferredHeight: 40
            transform: Translate { id: shakeOffset }
            // Basic keeps the label visible while focused: the field may ask for
            // a PIN or a password, so what it wants must stay readable.
            Basic.TextField {
                id: password
                readonly property bool shown: ["prompt", "verifying", "starting"].includes(root.shownStage)
                anchors.fill: parent
                opacity: shown ? 1 : 0; visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Settings.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
                font.family: Theme.font; font.pixelSize: Theme.textBody; color: "white"; placeholderTextColor: Qt.alpha("white", 0.55)
                font.styleName: ""; font.weight: Theme.weightRegular
                onFontChanged: Theme.syncFontWeight(password)
                selectionColor: Qt.alpha(Theme.accent, 0.6); selectedTextColor: "white"
                placeholderText: root.shownStage === "verifying" ? "Checking…" : root.shownPrompt
                echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                enabled: root.shownStage === "prompt"; focus: true
                leftPadding: 14; rightPadding: 14
                background: Rectangle {
                    radius: 12; color: Qt.alpha("white", password.activeFocus ? 0.14 : 0.1)
                    border.width: 1; border.color: root.error ? Theme.error : password.activeFocus ? Qt.alpha(Theme.accent, 0.9) : Qt.alpha("white", 0.16)
                    Behavior on border.color { ColorAnimation { duration: Theme.hoverDuration } }
                }
                onAccepted: root.submit()
                Component.onCompleted: if (root.shownStage === "prompt") forceActiveFocus()
            }
            // The field becomes a pill that waits for the key's touch.
            Rectangle {
                anchors.fill: parent; radius: 12
                opacity: root.shownStage === "touch" ? 1 : 0; visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Settings.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
                color: Qt.alpha("white", 0.1); border.width: 1; border.color: Qt.alpha(Theme.accent, 0.55)
                SecurityKeyHint {
                    anchors.centerIn: parent
                    waiting: root.shownStage === "touch"; foreground: "white"; glyphSize: 26
                }
            }
            AbstractButton {
                id: retryButton
                anchors.fill: parent
                opacity: root.shownStage === "failed" ? 1 : 0; visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Settings.reducedMotion ? 0 : 140 } }
                hoverEnabled: true; focusPolicy: Qt.StrongFocus
                Keys.onReturnPressed: root.retry()
                Keys.onEnterPressed: root.retry()
                onClicked: root.retry()
                background: Rectangle {
                    radius: 12; color: Qt.alpha("white", retryButton.down ? 0.16 : retryButton.hovered ? 0.13 : 0.1)
                    border.width: 1; border.color: retryButton.visualFocus ? Qt.alpha(Theme.accent, 0.9) : Qt.alpha("white", 0.16)
                    Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
                }
                contentItem: Item {
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "refresh"; width: 15; height: 15; color: "white" }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: "Try again"; color: "white"; font.weight: Theme.weightMedium }
                    }
                }
            }
        }
        Label {
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            visible: text !== ""; text: root.shownMessage
            font.pixelSize: Theme.textSmall; color: root.error && !root.preview ? Theme.error : Qt.alpha("white", 0.65)
            wrapMode: Text.Wrap; maximumLineCount: 2
        }
        AbstractButton {
            id: alternativeButton
            Layout.alignment: Qt.AlignHCenter
            visible: text !== ""; text: root.shownAlternative
            focusPolicy: Qt.StrongFocus; hoverEnabled: true
            leftPadding: 10; rightPadding: 10; topPadding: 5; bottomPadding: 5
            Keys.onReturnPressed: root.alternate()
            Keys.onEnterPressed: root.alternate()
            onClicked: root.alternate()
            contentItem: Label {
                text: alternativeButton.text; font.pixelSize: Theme.textSmall; font.weight: Theme.weightMedium
                color: Qt.alpha("white", alternativeButton.hovered || alternativeButton.visualFocus ? 0.95 : 0.62)
                Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
            }
            background: Rectangle {
                radius: Theme.radiusControl
                color: Qt.alpha("white", alternativeButton.down ? 0.12 : alternativeButton.hovered ? 0.07 : 0)
                border.width: alternativeButton.visualFocus ? 1 : 0; border.color: Qt.alpha(Theme.accent, 0.9)
            }
        }
    }
    CornerCutouts { anchors.fill: parent }
}
