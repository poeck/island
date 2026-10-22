import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    property int clicks: 0
    FloatingWindow {
        visible: true
        title: "Island input probe"
        color: "#355363"; implicitWidth: 1000; implicitHeight: 700
        MouseArea { anchors.fill: parent; onClicked: ++clicks }
    }
    IpcHandler { target: "probe"; function count(): int { return clicks; } }
}
