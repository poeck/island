import QtQuick
import Quickshell.Bluetooth

QtObject {
    property string name: ""
    property string deviceName: name
    property string address: ""
    property string dbusPath: "/org/bluez/hci0/dev_" + address.replace(/:/g,"_")
    property string icon: ""
    property var adapter: null
    property bool connected: false
    property bool paired: false
    property bool bonded: paired
    property bool pairing: false
    property bool trusted: false
    property bool blocked: false
    property bool batteryAvailable: connected
    property real battery: 0.72
    property int state: connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected
}
