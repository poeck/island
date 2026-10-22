//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "ui"
import "views"

ShellRoot {
    id: root
    property int changes: 0
    AudioService {
        id: service
        demo: Quickshell.env("ISLAND_AUDIO_NATIVE") !== "1"
        expanded: true; osdEnabled: true
        onChanged: root.changes++
    }
    TopBar {
        screen: Quickshell.screens[0]; selected: true
        date: new Date(2026, 9, 21, 12, 34)
        audioService: service; audioOpen: true
    }
    FloatingWindow {
        id: window
        visible: true; title: "Island audio fixture"
        implicitWidth: 1920; implicitHeight: 1080; color: "#355363"
        Rectangle {
            id: body
            x: (window.width - width) / 2; y: 28
            width: Math.min(760, window.width - 48); height: 520
            radius: 38; topLeftRadius: 0; topRightRadius: 0; color: "black"
            AudioView { anchors.fill: parent; service: service; active: true; demo: service.demo }
        }
        InverseCorner { x: body.x - width; y: body.y; width: 12; height: 12 }
        InverseCorner { x: body.x + body.width; y: body.y; width: 12; height: 12; mirrored: true }
    }
    IpcHandler {
        target: "audio-test"
        function state(): string {
            return JSON.stringify({ready: service.ready, output: service.sink ? service.sink.name : null,
                input: service.source ? service.source.name : null,
                outputs: service.outputs.map(n => ({id: n.id, name: n.name, ready: n.ready, volume: n.ready ? n.audio.volume : null, muted: n.ready ? n.audio.muted : null})),
                inputs: service.inputs.map(n => ({id: n.id, name: n.name, ready: n.ready, volume: n.ready ? n.audio.volume : null, muted: n.ready ? n.audio.muted : null})),
                applications: service.applications.map(a => ({name: a.title, count: a.nodes.length, volume: service.volume(a.nodes), muted: service.muted(a.nodes)})),
                changes: root.changes});
        }
        function geometry(name: string): string {
            function find(item) {
                if (item.objectName === name) {
                    const point = item.mapToItem(null, 0, 0);
                    return {x: point.x, y: point.y, width: item.width, height: item.height};
                }
                for (const child of item.children || []) { const result = find(child); if (result) return result; }
                return null;
            }
            return JSON.stringify(find(window.contentItem));
        }
        function select(kind: string, index: int): void {
            if (kind === "output") service.selectOutput(service.outputs[index]);
            else service.selectInput(service.inputs[index]);
        }
        function volume(kind: string, index: int, value: real): void {
            const nodes = kind === "app" ? service.applications[index].nodes : [kind === "output" ? service.outputs[index] : service.inputs[index]];
            service.setVolume(nodes, value);
        }
        function mute(kind: string, index: int): void {
            const nodes = kind === "app" ? service.applications[index].nodes : [kind === "output" ? service.outputs[index] : service.inputs[index]];
            service.toggleMute(nodes);
        }
        function remove(kind: string): void {
            if (!service.demo) return;
            const old = kind === "output" ? service.sink : service.source;
            service.backend.nodes.values = service.backend.nodes.values.filter(n => kind === "app" ? !n.isStream : n !== old);
            if (kind === "output") service.backend.defaultAudioSink = service.outputs[0] || null;
            if (kind === "input") service.backend.defaultAudioSource = service.inputs[0] || null;
        }
    }
}
