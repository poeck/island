//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "ui"

ShellRoot {
    id: root
    property date now: new Date(2026, 9, 24, 12, 34)
    ScreenChrome {
        id: chrome
        targetScreen: Quickshell.screens.find(s => s.name === "HEADLESS-1") || null
        date: root.now
        reducedMotion: true
    }
    function clockLabel(item) {
        if (item.text === Qt.formatTime(root.now, "HH:mm")) return item;
        for (const child of item.children || []) {
            const found = clockLabel(child);
            if (found) return found;
        }
        return null;
    }
    IpcHandler {
        target: "bar-clock-test"
        function palette(light: bool): void {
            for (const bar of chrome.barWindows) {
                bar.contentItem.palette.windowText = light ? "#000000" : "#ffffff";
                bar.contentItem.palette.text = light ? "#000000" : "#ffffff";
            }
        }
        function minute(value: int): void { root.now = new Date(2026, 9, 24, 12, value); }
        function shown(value: bool): void { chrome.shown = value; }
        function status(): string {
            const bar = chrome.barWindows[0];
            const label = bar ? root.clockLabel(bar.contentItem) : null;
            return JSON.stringify({ready: !!label, offset: chrome.slideOffset,
                text: label ? label.text : "", color: label ? label.color.toString() : "",
                family: label ? label.font.family : "", weight: label ? label.font.weight : 0,
                axis: label ? label.font.variableAxes.wght : 0,
                expectedFamily: Theme.font, expectedColor: Theme.text.toString()});
        }
    }
}
