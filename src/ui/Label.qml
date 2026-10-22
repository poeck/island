import QtQuick
import "../core"

Text {
    id: label
    color: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.textBody
    font.styleName: ""
    font.weight: Theme.weightRegular
    onFontChanged: Theme.syncFontWeight(label)
    textFormat: Text.PlainText
    elide: Text.ElideRight
    renderType: Text.QtRendering
}
