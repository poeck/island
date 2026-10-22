function select(screens, monitors, selector) {
    const wanted = selector.toLowerCase();
    return screens.find(s => {
        const monitor = monitors.find(m => m.name === s.name);
        return (s.name + " " + s.model + " " + (monitor ? monitor.description : "")).toLowerCase().includes(wanted);
    }) || screens[0] || null;
}
if (typeof module !== "undefined") module.exports = {select: select};
