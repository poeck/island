pragma Singleton
import QtQuick
import Quickshell

QtObject {
    // Neutral surfaces on true black. Elevation comes from a faint lift plus a
    // slightly lighter hairline; colour is reserved for state.
    readonly property color background: "#000000"
    readonly property color surface: "#0a0a0a"
    readonly property color raised: "#131313"
    readonly property color selection: "#1a1a1a"
    readonly property color pressed: "#222222"
    readonly property color border: "#1c1c1c"
    readonly property color borderStrong: "#2a2a2a"
    readonly property color track: "#262626"
    readonly property color text: "#ededed"
    readonly property color secondary: "#8f8f8f"
    readonly property color muted: "#5c5c5c"
    readonly property color disabled: "#3d3d3d"
    // Tailwind indigo-500 for filled active states and focus; never small text.
    readonly property color accent: "#6366f1"
    readonly property color accentHover: "#7073f3"
    readonly property color accentInk: "#ffffff"
    readonly property color focus: "#6366f1"
    readonly property color error: "#f87171"
    readonly property color warning: "#fbbf24"

    readonly property string font: interFont.status === FontLoader.Ready ? interFont.name : "Inter"
    readonly property FontLoader interFont: FontLoader { source: Quickshell.env("ISLAND_FONT") || Qt.resolvedUrl("../assets/InterVariable.ttf") }
    // FontLoader registers the variable face, but its named weight instances
    // are not necessarily installed in fontconfig. In that environment Qt can
    // report weight 600 while rendering Regular. Select the actual axis too.
    // QML notifies the entire font value when any subproperty changes. A
    // binding from variableAxes back to font.weight would therefore loop.
    // Update only when needed, preserving other axes and weight bindings.
    function syncFontWeight(item: var): void {
        if (item.font.variableAxes.wght !== item.font.weight)
            item.font.variableAxes = Object.assign({}, item.font.variableAxes, {wght: item.font.weight});
    }
    readonly property int weightRegular: Font.Normal
    readonly property int weightMedium: Font.Medium
    readonly property int weightSemibold: Font.DemiBold
    readonly property int weightBold: Font.Bold
    // One type scale; display sizes beyond it are set where a hero number lives.
    readonly property int textCaption: 11
    readonly property int textSmall: 12
    readonly property int textBody: 13
    readonly property int textTitle: 15
    readonly property int textHeading: 20
    readonly property int textDisplay: 28
    readonly property var numeric: ({tnum: 1})

    readonly property int radiusSmall: 6
    readonly property int radiusControl: 8
    readonly property int radiusCard: 12

    readonly property int barHeight: 28
    readonly property int clockWidth: 96
    readonly property int compactClockSize: 13
    readonly property int notchJoinRadius: cornerRadius
    readonly property int cornerRadius: 12
    readonly property int trayIconSize: 16
    readonly property int trayCellSize: 36
    readonly property int traySpacing: 4
    readonly property int barEdgeMargin: 8
    readonly property int barControlSpacing: 0
    readonly property int trayMenuRadius: 10
    readonly property int trayMenuPadding: 6
    readonly property int trayMenuRowHeight: 34
    readonly property int contentMargin: 20
    readonly property int hoverDuration: 100
    readonly property int fadeInDuration: 200
    readonly property int fadeOutDuration: 90
    readonly property var dimensions: ({
        weather: [780, 540, 38], compact: [96, 0, 0], media: [720, 156, 38], system: [760, 468, 38], audio: [760, 520, 38], bluetooth: [760, 540, 38], network: [760, 540, 38], calendar: [688, 420, 38],
        launcher: [640, 472, 38], notification: [560, 88, 34],
        notifications: [640, 480, 38], osd: [340, 52, 26],
        session: [640, 132, 38], auth: [600, 268, 38]
    })
}
