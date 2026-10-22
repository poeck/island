import QtQuick

BarButton {
    id: root
    property var service: null
    readonly property var sink: service ? service.sink : null
    readonly property bool available: sink && sink.ready && sink.audio
    readonly property bool muted: available && sink.audio.muted
    visible: !!service
    iconName: muted ? "muted" : "volume"
    Accessible.name: "Audio controls"
}
