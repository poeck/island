//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "core"
import "services"
import "ui"
import "views"

ShellRoot {
    id: root
    property int clicks: 0
    QtObject {
        id: power
        property bool ready: true
        property bool isPresent: true
        property bool isLaptopBattery: true
        property real percentage: .72
        property int state: UPowerDeviceState.Discharging
        property real timeToEmpty: 7380
        property real timeToFull: 2400
        property real changeRate: -8.5
        property bool healthSupported: true
        property real healthPercentage: .94
    }
    SystemService { id: service; polling: false; powerDevice: power }
    property var data: ({cpu: {name: "Test processor · 12 cores", threads: 24, usage: 24, temperature: 48, load: [1.2, .8, .6]},
        memory: {usage: 52, used: 16.6 * 1024**3, total: 32 * 1024**3, swapTotal: 8 * 1024**3, swapUsed: .5 * 1024**3},
        gpus: [{id: "test-gpu", name: "Test graphics", usage: 36, temperature: 52, memoryUsed: 3 * 1024**3, memoryTotal: 8 * 1024**3, power: 42}],
        network: {download: 12.6 * 1024**2, upload: 420 * 1024, interfaces: ["wlan0"]},
        disks: [{path: "/", total: 1024**4, used: .62 * 1024**4, usage: 62}], uptime: 23456, os: "NixOS", kernel: "Linux"})
    Component.onCompleted: {
        for (let i = 0; i < 45; i++) {
            data.cpu.usage = 24 + 10 * Math.sin(i / 3);
            data.gpus[0].usage = 36 + 12 * Math.sin(i / 4);
            service.accept(JSON.parse(JSON.stringify(data)));
        }
    }
    TopBar {
        id: bar
        screen: Quickshell.screens[0]; selected: true
        date: new Date(2026, 9, 21, 12, 34)
        systemService: service; systemOpen: true
        onSystemToggle: root.clicks++
    }
    FloatingWindow {
        id: window
        visible: true; title: "Island system fixture"
        implicitWidth: 1920; implicitHeight: 1080; color: "#355363"
        Rectangle {
            id: body
            x: (window.width - width) / 2; y: 28
            width: Math.min(760, window.width - 48); height: Math.min(window.height - 52, view.preferredHeight)
            radius: 38; topLeftRadius: 0; topRightRadius: 0; color: "black"
            SystemView { id: view; anchors.fill: parent; service: service; active: true }
        }
        InverseCorner { x: body.x - width; y: body.y; width: 12; height: 12 }
        InverseCorner { x: body.x + body.width; y: body.y; width: 12; height: 12; mirrored: true }
    }
    IpcHandler {
        target: "system-test"
        function state(): string { return JSON.stringify({barLayout: bar.barLayout, battery: service.battery, gpu: service.gpu, clicks: root.clicks, history: service.samples.length}); }
        function battery(kind: string): void {
            power.isPresent = kind !== "none";
            power.isLaptopBattery = kind !== "peripheral";
            power.state = kind === "charging" ? UPowerDeviceState.Charging : UPowerDeviceState.Discharging;
        }
        function gpu(present: bool): void { data.gpus = []; service.accept(data); }
    }
}
