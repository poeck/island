//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "ui"

ShellRoot {
    id: root
    property bool fullscreen: false
    property bool reducedMotion: false
    FloatingWindow {
        visible: true
        title: "Island fullscreen chrome probe"
        color: "#355363"
        implicitWidth: 1920; implicitHeight: 1080
    }
    ScreenChrome {
        id: chrome
        targetScreen: Quickshell.screens.find(s => s.name === "HEADLESS-1") || Quickshell.screens[0] || null
        date: new Date(2026, 9, 21, 12, 34)
        shown: !root.fullscreen
        reserve: !root.fullscreen
        reducedMotion: root.reducedMotion
    }
    IpcHandler {
        target: "chrome"
        function fullscreen(value: bool): string {
            const before = chrome.slideOffset;
            root.fullscreen = value;
            return JSON.stringify({before: before, after: chrome.slideOffset});
        }
        function reduced(value: bool): void { root.reducedMotion = value; }
        function status(): string {
            return JSON.stringify({offset: chrome.slideOffset, animating: chrome.animating, frames: chrome.animationFrames, trayCount: chrome.trayCount, trayOpen: chrome.trayOpen});
        }
    }
}
