// Pure policy: shared by QML and Node's test runner. No services or timers here.
function initial() {
    return { panel: "", auth: false, locked: false,
             fullscreen: false, osd: false, notification: false };
}
function reduce(previous, event) {
    var s = Object.assign({}, previous);
    switch (event.type) {
    case "toggle":
        if (!s.locked && !s.auth) s.panel = s.panel === event.panel ? "" : event.panel;
        break;
    case "open":
        if (!s.locked && !s.auth) s.panel = event.panel;
        break;
    case "dismiss":
        if (!s.auth) s.panel = "";
        break;
    case "auth": s.auth = event.value; break;
    case "lock":
        s.locked = event.value;
        if (s.locked) { s.panel = ""; s.osd = false; s.notification = false; }
        break;
    case "fullscreen":
        s.fullscreen = event.value;
        if (s.fullscreen && ["media", "system", "audio", "network", "calendar", "bluetooth", "weather"].includes(s.panel)) s.panel = "";
        break;
    case "osd": s.osd = event.value; break;
    case "notification": s.notification = event.value; break;
    }
    return s;
}
function mode(s) {
    if (s.locked) return "hidden";
    if (s.auth) return "auth";
    if (s.panel) return s.panel;
    if (s.osd) return "osd";
    if (s.fullscreen) return "hidden";
    if (s.notification) return "notification";
    return "compact";
}
function blocksPopups(s) { return s.locked || s.auth || !!s.panel || s.fullscreen || s.osd; }
if (typeof module !== "undefined") module.exports = { initial: initial, reduce: reduce, mode: mode, blocksPopups: blocksPopups };
