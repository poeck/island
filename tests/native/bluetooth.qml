//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "services"
import "ui"
import "views"
ShellRoot {
    id: root
    property bool open: true
    BluetoothService { id: service; demo: Quickshell.env("ISLAND_BLUETOOTH_NATIVE") !== "1"; expanded: root.open }
    TopBar { screen: Quickshell.screens[0]; selected: true; date: new Date(); bluetoothService: service; bluetoothOpen: root.open; onBluetoothToggle: root.open = !root.open }
    FloatingWindow {
        id: window; visible: true; title: "Island Bluetooth fixture"; implicitWidth: 1920; implicitHeight: 1080; color: "#355363"
        Rectangle {
            id: body; x: (window.width-width)/2; y: 28; width: Math.min(760,window.width-48); height: 540
            radius: 38; topLeftRadius: 0; topRightRadius: 0; color: "black"
            BluetoothView { anchors.fill: parent; service: service; active: root.open; onDismiss: root.open = false }
        }
        InverseCorner { x: body.x-width; y: body.y; width: 12; height: 12 }
        InverseCorner { x: body.x+body.width; y: body.y; width: 12; height: 12; mirrored: true }
    }
    IpcHandler {
        target: "bluetooth-test"
        function state(): string { return JSON.stringify({open:root.open,ready:service.ready,wanted:service.bridgeWanted,powered:service.powered,blocked:service.blocked,scanning:service.scanning,visible:service.adapter ? service.adapter.discoverable : false,adapters:service.adapters.length,devices:service.devices.map(d=>({name:d.name,address:d.address,connected:d.connected,paired:d.paired,trusted:d.trusted,battery:service.battery(d)})),prompt:service.prompt,busy:service.busy,error:service.error}); }
        function reveal(suffix: string): void {
            function find(item) { if(item.objectName === "bluetoothDeviceList") return item; for(const c of item.children||[]){const r=find(c);if(r)return r;}return null; }
            const list=find(window.contentItem), index=service.devices.findIndex(d=>d.address.endsWith(suffix));
            if(list && index>=0) list.positionViewAtIndex(index,ListView.Contain);
        }
        function geometry(name: string): string {
            function find(item) { if(item.objectName===name) { const p=item.mapToItem(null,0,0);return {x:p.x,y:p.y,width:item.width,height:item.height}; } for(const child of item.children||[]) {const r=find(child);if(r)return r;}return null; }
            return JSON.stringify(find(window.contentItem));
        }
        function scenario(value: string): void {
            if(value==="close")root.open=false;
            if(value==="open")root.open=true;
            if(!service.demo)return;
            if(["pin","passkey","display","confirm"].includes(value))service.backend.pairingKind=value;
            if(value==="remove")service.backend.adapters.values=[];
            if(value==="blocked")service.adapter.state=BluetoothAdapterState.Blocked;
        }
    }
}
