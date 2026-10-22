import QtQuick

BarButton {
    property var service: null
    visible: !!service
    iconName: service ? service.icon : "network-off"
    Accessible.name: service ? "Network controls: " + service.connectivity : "Network controls"
}
