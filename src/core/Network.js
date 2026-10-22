// Pure display policy. Native objects remain intact so updates preserve identity.
function sorted(networks) {
    return networks.filter(n => n.name).slice().sort((a,b) => Number(!!b.connected) - Number(!!a.connected) || Number(!!b.known) - Number(!!a.known) || b.signalStrength - a.signalStrength || a.name.localeCompare(b.name));
}
function signal(value) { return Math.round(Math.max(0, Math.min(1, value || 0)) * 100); }
function speed(mbps) { return mbps >= 1000 ? (mbps / 1000).toLocaleString() + ' Gbps' : mbps > 0 ? mbps + ' Mbps' : ''; }
if (typeof module !== 'undefined') module.exports = {sorted, signal, speed};
