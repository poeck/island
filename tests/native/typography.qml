//@ pragma UseQApplication
import QtQuick
import Quickshell
import "core"
import "ui"
import "views"

// FontLoader-only regression: no system installation of Inter is needed.
ShellRoot {
    property bool strong: false
    FloatingWindow {
        visible: true; implicitWidth: 920; implicitHeight: 620; color: "black"
        Rectangle {
            id: canvas; anchors.fill: parent; color: "black"
            Label { x: 24; y: 20; text: "Shared text components"; font.weight: Theme.weightSemibold }
            Label { x: 464; y: 20; text: "Explicit Inter axis reference"; font.weight: Theme.weightSemibold }
            Repeater {
                id: samples
                model: [Theme.weightRegular, Theme.weightMedium, Theme.weightSemibold, Theme.weightBold]
                Item {
                    required property int modelData
                    required property int index
                    x: 24; y: 60 + index * 48; width: 856; height: 48
                    property alias sampleFont: sample.font
                    Label {
                        id: sample; width: 400; height: 48
                        text: "Calendar 012345"; font.pixelSize: 28
                        font.weight: parent.modelData; font.features: Theme.numeric
                    }
                    Text {
                        x: 440; width: 400; height: 48; color: Theme.text
                        text: sample.text; textFormat: Text.PlainText; elide: Text.ElideRight
                        font.family: Theme.font; font.pixelSize: 28; font.styleName: ""
                        font.weight: parent.modelData; font.features: Theme.numeric
                        font.variableAxes: ({wght: parent.modelData})
                        renderType: Text.QtRendering
                    }
                }
            }
            Label { id: dynamic; x: 24; y: 270; text: "Retargeted weight"; font.weight: strong ? Theme.weightSemibold : Theme.weightRegular }
            ActionButton { id: action; x: 24; y: 310; text: "Action button" }
            Segment { id: segment; x: 220; y: 310; width: 160; text: "Segment" }
            Input { id: input; x: 24; y: 356; text: "Input field" }
            TrayMenuItem { id: menuItem; x: 220; y: 356; width: 160; text: "Tray menu" }
            CalendarView { x: 450; y: 270; width: 440; height: 330 }
        }
    }
    function query(name, font) {
        const info = Qt.createQmlObject('import QtQuick; FontInfo {}', canvas);
        info.font = font;
        return {name: name, family: info.family, style: info.styleName, weight: font.weight, axis: font.variableAxes.wght};
    }
    Timer { interval: 100; running: true; onTriggered: strong = true }
    Timer {
        interval: 500; running: true
        onTriggered: {
            const report = {loaded: Theme.interFont.status === FontLoader.Ready, samples: []};
            for (let i = 0; i < samples.count; i++) report.samples.push(query("label", samples.itemAt(i).sampleFont));
            for (const entry of [["dynamic", dynamic], ["action", action], ["segment", segment], ["input", input], ["tray", menuItem]]) report.samples.push(query(entry[0], entry[1].font));
            console.log("TYPOGRAPHY_REPORT " + JSON.stringify(report));
            canvas.grabToImage(result => { result.saveToFile(Quickshell.env("ISLAND_TYPOGRAPHY_IMAGE")); Qt.quit(); });
        }
    }
}
