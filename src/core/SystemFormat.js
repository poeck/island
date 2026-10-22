function percent(value) { return value === null || value === undefined ? "—" : Math.round(value) + "%"; }
function bytes(value, digits) {
    if (value === null || value === undefined) return "—";
    var units = ["B", "KiB", "MiB", "GiB", "TiB"];
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++; }
    return value.toFixed(unit === 0 ? 0 : digits === undefined ? 1 : digits) + " " + units[unit];
}
function duration(seconds) {
    if (seconds === null || seconds === undefined) return "—";
    var minutes = Math.floor(seconds / 60), hours = Math.floor(minutes / 60), days = Math.floor(hours / 24);
    return (days ? days + "d " : "") + (hours ? hours % 24 + "h " : "") + minutes % 60 + "m";
}
function temperature(value) { return value === null || value === undefined ? "Sensor unavailable" : Math.round(value) + "°C"; }
if (typeof module !== "undefined") module.exports = {percent: percent, bytes: bytes, duration: duration, temperature: temperature};
