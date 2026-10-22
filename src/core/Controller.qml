import QtQuick
import "State.js" as Policy

Item {
    id: root
    property var model: Policy.initial()
    readonly property string mode: Policy.mode(model)
    readonly property bool interactive: model.auth || model.panel !== ""
    readonly property bool blocksPopups: Policy.blocksPopups(model)
    property var osd: ({ kind: "volume", value: 0, muted: false })
    function dispatch(event) { model = Policy.reduce(model, event); }
    function toggle(panel) { dispatch({type: "toggle", panel: panel}); }
    function open(panel) { dispatch({type: "open", panel: panel}); }
    function dismiss() { dispatch({type: "dismiss"}); }
    function showOsd(kind, value, muted) {
        if (model.locked) return;
        osd = { kind: kind, value: Math.max(0, Math.min(150, value)), muted: muted };
        dispatch({type: "osd", value: true});
        osdTimeout.restart();
    }
    Timer { id: osdTimeout; interval: 1500; onTriggered: root.dispatch({type: "osd", value: false}) }
}
