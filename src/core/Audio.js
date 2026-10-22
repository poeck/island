// Presentation policy shared by the live adapter, demo and tests.
function deviceName(node) { return node ? node.description || node.nickname || node.name || "Audio device" : "No device connected"; }
function deviceKind(node) {
    if (!node) return "";
    var name = (node.name || "").toLowerCase();
    if (/bluez|bluetooth/.test(name)) return "Bluetooth";
    if (/hdmi|displayport/.test(name)) return "HDMI / DisplayPort";
    if (/easyeffects|filter|virtual/.test(name)) return "Effects / virtual device";
    if (/usb/.test(name)) return "USB audio";
    return "System audio";
}
function groups(nodes) {
    var result = [], byKey = {};
    for (var node of nodes) {
        if (!node.ready) continue;
        var p = node.properties || {};
        var title = p["application.name"] || node.description || node.nickname || node.name || "Application";
        var key = (node.isSink ? "input:" : "output:") + (p["application.id"] || p["application.process.binary"] || title);
        if (!byKey[key]) {
            byKey[key] = {key: key, title: title, recording: node.isSink, icon: p["application.icon-name"] || "", nodes: []};
            result.push(byKey[key]);
        }
        byKey[key].nodes.push(node);
    }
    return result.sort((a, b) => Number(a.recording) - Number(b.recording) || a.title.localeCompare(b.title));
}
function volume(nodes) {
    var ready = nodes.filter(node => node && node.ready && node.audio);
    return ready.length ? ready.reduce((sum, node) => sum + node.audio.volume, 0) / ready.length : 0;
}
function muted(nodes) {
    var ready = nodes.filter(node => node && node.ready && node.audio);
    return ready.length > 0 && ready.every(node => node.audio.muted);
}
function gain(value) { return Math.max(0, Math.min(1, value)); }
if (typeof module !== "undefined") module.exports = {deviceName, deviceKind, groups, volume, muted, gain};
