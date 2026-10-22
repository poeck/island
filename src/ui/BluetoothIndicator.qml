import QtQuick

BarButton {
    id: root
    property var service: null
    visible: !!service
    iconName: "bluetooth"
    lit: !!service && service.connected.length > 0
    dim: service && service.powered ? 1 : 0.5
    Accessible.name: service ? "Bluetooth controls: " + service.status : "Bluetooth controls"
}
