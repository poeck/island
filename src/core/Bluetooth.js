function name(device) { return device.name || device.deviceName || device.address || 'Unknown device'; }
function sorted(devices) { return devices.slice().sort((a,b) => Number(!!b.connected)-Number(!!a.connected) || Number(!!b.paired)-Number(!!a.paired) || name(a).localeCompare(name(b))); }
function icon(device) {
    const value = device.icon || '';
    if (/headset|headphone|audio/.test(value)) return 'headphones';
    if (/keyboard/.test(value)) return 'keyboard';
    if (/mouse/.test(value)) return 'mouse';
    if (/phone/.test(value)) return 'phone';
    return 'bluetooth';
}
function battery(device) { return device.batteryAvailable ? Math.round(Math.max(0,Math.min(1,device.battery))*100) + '%' : ''; }
function status(device) { return device.pairing ? 'Pairing…' : device.connected ? 'Connected' : device.blocked ? 'Blocked' : device.paired ? 'Saved device' : 'Not paired'; }
if (typeof module !== 'undefined') module.exports = {name,sorted,icon,battery,status};
