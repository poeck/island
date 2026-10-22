//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "services"
import "ui"
import "views"

ShellRoot {
    NetworkService { id: service; demo: true; expanded: true }
    TopBar { screen: Quickshell.screens[0]; selected: true; date: new Date(); networkService: service; networkOpen: true }
    FloatingWindow {
        id: window; visible: true; title: "Island network fixture"
        implicitWidth: 1920; implicitHeight: 1080; color: "#355363"
        Rectangle {
            id: body; x: (window.width - width) / 2; y: 28
            width: Math.min(760,window.width-48); height: 540
            radius: 38; topLeftRadius: 0; topRightRadius: 0; color: "black"
            NetworkView { anchors.fill: parent; service: service; active: true }
        }
        InverseCorner { x: body.x-width; y: body.y; width: 12; height: 12 }
        InverseCorner { x: body.x+body.width; y: body.y; width: 12; height: 12; mirrored: true }
    }
    IpcHandler {
        target: "network-test"
        function state(): string { return JSON.stringify({wifi: service.wifiEnabled, scan: service.wifiDevices.length ? service.wifiDevices[0].scannerEnabled : false, connected: service.activeDevices.map(d=>d.name), networks: service.wifiNetworks.map(n=>({name:n.name,connected:n.connected})), prompt: service.passwordNetwork ? service.passwordNetwork.name : null, busy: service.busy, error: service.error, vpns: service.vpns, available: service.available}); }
        function geometry(name: string): string {
            function find(item) { if (item.objectName === name) { const p=item.mapToItem(null,0,0); return {x:p.x,y:p.y,width:item.width,height:item.height}; } for (const child of item.children || []) { const r=find(child); if(r)return r; } return null; }
            return JSON.stringify(find(window.contentItem));
        }
        function password(value: string): void { service.submitPassword(value); }
        function scenario(value: string): void {
            if (value === "unplug") service.wiredDevices[0].hasLink = false;
            if (value === "hardware") service.backend.wifiHardwareEnabled = false;
            if (value === "remove-wifi") service.backend.devices.values = service.wiredDevices;
            if (value === "remove-all") service.backend.devices.values = [];
            if (value === "unavailable") service.backend.backend = NetworkBackendType.None;
            if (value === "native") { service.demo = false; }
        }
    }
}
