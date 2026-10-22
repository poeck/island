import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower
import Quickshell.Networking
import "../core"
import "../ui"

FocusScope {
    id: root
    required property date date
    property bool preview: false
    property bool busy: false
    property bool responseVisible: false
    property string prompt: "Password"
    property string message: ""
    property bool error: false
    signal response(string value)
    signal previewDismiss()
    focus: true
    onBusyChanged: { password.clear(); if (!busy) Qt.callLater(() => password.forceActiveFocus()); }
    function clear() { password.clear(); }
    function submit() {
        if (preview) { password.clear(); previewDismiss(); return; }
        if (!busy && password.text.length) { const value = password.text; password.clear(); response(value); }
    }
    // A rejected password nudges the field sideways, like a head shake.
    onErrorChanged: if (error && !Settings.reducedMotion) shake.restart()
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeOffset; property: "x"; to: -8; duration: 50; easing.type: Easing.OutCubic }
        NumberAnimation { target: shakeOffset; property: "x"; to: 6; duration: 70; easing.type: Easing.InOutCubic }
        NumberAnimation { target: shakeOffset; property: "x"; to: -3; duration: 60; easing.type: Easing.InOutCubic }
        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 60; easing.type: Easing.OutCubic }
    }
    Keys.onEscapePressed: { password.clear(); if (preview) previewDismiss(); }
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
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(16, Math.min(parent.height * 0.76, parent.height - implicitHeight - 24))
        width: Math.min(320, parent.width - 60); spacing: 12
        Rectangle {
            Layout.alignment: Qt.AlignHCenter; implicitWidth: 52; implicitHeight: 52; radius: 26
            color: Qt.alpha("white", 0.1); border.color: Qt.alpha("white", 0.18); border.width: 1
            Icon { anchors.centerIn: parent; name: "user"; width: 24; height: 24; color: "white" }
        }
        Label { Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 4; text: Settings.user; font.pixelSize: Theme.textTitle; font.weight: Theme.weightSemibold; color: "white" }
        TextField {
            id: password
            Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 240; Layout.preferredHeight: 36
            font.family: Theme.font; font.pixelSize: Theme.textBody; color: "white"; placeholderTextColor: Qt.alpha("white", 0.55)
            font.styleName: ""; font.weight: Theme.weightRegular
            onFontChanged: Theme.syncFontWeight(password)
            selectionColor: Qt.alpha(Theme.accent, 0.6); selectedTextColor: "white"
            horizontalAlignment: TextInput.AlignHCenter
            placeholderText: root.busy ? "Authenticating…" : root.prompt
            echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
            enabled: !root.busy; focus: true
            leftPadding: 14; rightPadding: 14
            background: Rectangle {
                radius: 10; color: Qt.alpha("white", password.activeFocus ? 0.14 : 0.1)
                border.width: 1; border.color: root.error ? Theme.error : password.activeFocus ? Qt.alpha(Theme.accent, 0.9) : Qt.alpha("white", 0.16)
                Behavior on border.color { ColorAnimation { duration: Theme.hoverDuration } }
            }
            transform: Translate { id: shakeOffset }
            onAccepted: root.submit()
            Component.onCompleted: forceActiveFocus()
        }
        Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.preview ? "Preview · Enter or Esc to close" : root.message; font.pixelSize: Theme.textSmall; color: root.error ? Theme.error : Qt.alpha("white", 0.65); wrapMode: Text.Wrap; maximumLineCount: 2 }
    }
    CornerCutouts { anchors.fill: parent }
}
