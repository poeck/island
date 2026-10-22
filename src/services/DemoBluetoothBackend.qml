import QtQuick
import Quickshell.Bluetooth

Item {
    id: root
    component ObjectList: QtObject { property var values: [] }
    signal message(var value)
    property ObjectList adapters: ObjectList { values: [radio] }
    property var defaultAdapter: adapters.values[0] || null
    property var operation: null
    property var target: null
    property string pairingKind: "confirm"
    property int token: 0
    QtObject {
        id: radio
        property string name: "Island desktop"
        property string adapterId: "hci0"
        property string dbusPath: "/org/bluez/hci0"
        property bool enabled: true
        property bool discoverable: false
        property bool discovering: false
        property int state: enabled ? BluetoothAdapterState.Enabled : BluetoothAdapterState.Disabled
        property ObjectList devices: ObjectList { values: [headphones, keyboard, phone, mouse] }
        onEnabledChanged: if (!enabled) { discovering = false; discoverable = false; for (const d of devices.values) d.connected = false; }
    }
    DemoBluetoothDevice { id: headphones; name: "Studio headphones"; icon: "audio-headphones"; address: "10:20:30:40:50:60"; adapter: radio; connected: true; paired: true; trusted: true; battery: 0.84 }
    DemoBluetoothDevice { id: keyboard; name: "Mechanical keyboard"; icon: "input-keyboard"; address: "10:20:30:40:50:61"; adapter: radio; paired: true; battery: 0.65 }
    DemoBluetoothDevice { id: phone; name: "Pixel phone"; icon: "phone"; address: "10:20:30:40:50:62"; adapter: radio; batteryAvailable: false }
    DemoBluetoothDevice { id: mouse; name: "Travel mouse"; icon: "input-mouse"; address: "10:20:30:40:50:63"; adapter: radio; batteryAvailable: false }
    function request(value) {
        operation = value;
        target = radio.devices.values.find(d => d.dbusPath === value.path) || radio;
        if (value.action === "pair") {
            target.pairing = true;
            message({event:"prompt",kind:pairingKind,device:target.dbusPath,token:++token,code:"042816",entered:0});
            return;
        }
        completion.restart();
    }
    function reply(value) {
        if (value.token !== token || !operation) return;
        if (value.value === null) { cancel(); return; }
        if (pairingKind === "pin" && value.value !== "1234" || pairingKind === "passkey" && value.value !== "042816") {
            const id = operation.id; target.pairing = false; operation = null;
            message({event:"done",id:id,ok:false,error:"Pairing failed. Check the PIN or passkey and retry."}); return;
        }
        completion.restart();
    }
    function cancel() {
        completion.stop();
        if (operation) { const id = operation.id; if (target && target !== radio) target.pairing = false; operation = null; message({event:"done",id:id,ok:false,error:"Pairing canceled."}); }
        radio.discovering = false; scanTimer.stop(); visibilityTimer.stop(); radio.discoverable = false;
        message({event:"scan",paths:[]}); message({event:"prompt-clear"});
    }
    Timer {
        id: completion; interval: 220
        onTriggered: {
            const op = root.operation, d = root.target;
            if (!op) return;
            if (op.action === "power") radio.enabled = op.value;
            else if (op.action === "visible") { radio.discoverable = op.value; if (op.value) visibilityTimer.restart(); else visibilityTimer.stop(); }
            else if (op.action === "scan") { radio.discovering = true; scanTimer.restart(); }
            else if (op.action === "stop-scan") { radio.discovering = false; scanTimer.stop(); }
            else if (op.action === "connect") d.connected = true;
            else if (op.action === "disconnect") d.connected = false;
            else if (op.action === "pair") { d.pairing = false; d.paired = true; d.connected = true; }
            else if (op.action === "trust") d.trusted = op.value;
            else if (op.action === "forget") radio.devices.values = radio.devices.values.filter(n => n !== d);
            root.operation = null;
            root.message({event:"scan",paths:radio.discovering ? [radio.dbusPath] : []});
            root.message({event:"done",id:op.id,ok:true});
        }
    }
    Timer { id: scanTimer; interval: 20000; onTriggered: { radio.discovering = false; root.message({event:"scan",paths:[]}); } }
    Timer { id: visibilityTimer; interval: 120000; onTriggered: radio.discoverable = false }
}
