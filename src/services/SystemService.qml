import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../core"

Item {
    id: root
    property bool polling: true
    property alias powerProfiles: profiles
    PowerProfileService { id: profiles; active: root.polling }
    onPollingChanged: sampler.running = polling
    property var snapshot: ({cpu: {}, memory: {}, gpus: [], network: {}, disks: []})
    property var samples: []
    property int revision: 0
    readonly property var gpu: {
        const devices = snapshot.gpus || [];
        return devices.reduce((best, item) => !best || (item.usage ?? -1) > (best.usage ?? -1) ? item : best, null);
    }
    property var powerDevice: UPower.displayDevice
    readonly property var battery: powerDevice && powerDevice.ready && powerDevice.isLaptopBattery && powerDevice.isPresent ? ({
        percentage: powerDevice.percentage * 100,
        charging: powerDevice.state === UPowerDeviceState.Charging,
        state: powerDevice.state === UPowerDeviceState.FullyCharged ? "Fully charged" : powerDevice.state === UPowerDeviceState.Discharging ? "On battery" : powerDevice.state === UPowerDeviceState.Empty ? "Empty" : "Connected",
        seconds: powerDevice.state === UPowerDeviceState.Charging ? powerDevice.timeToFull : powerDevice.timeToEmpty,
        watts: Math.abs(powerDevice.changeRate), health: powerDevice.healthSupported ? powerDevice.healthPercentage * 100 : null
    }) : null
    function accept(value) {
        snapshot = value;
        const selected = gpu;
        samples = samples.concat([{cpu: value.cpu.usage, memory: value.memory.usage,
            gpu: selected ? selected.usage : null, gpuId: selected ? selected.id : "",
            download: value.network.download, upload: value.network.upload}]).slice(-31);
        revision++;
    }
    function history(key) {
        return samples.map(sample => key === "gpu" && gpu && sample.gpuId !== gpu.id ? null : sample[key]);
    }
    Process {
        id: sampler
        command: [Settings.executable, "internal", "watch-system"]
        running: root.polling
        stdout: SplitParser {
            onRead: data => {
                try { root.accept(JSON.parse(data)); }
                catch (e) { console.warn("Island: invalid system sample", e); }
            }
        }
        onRunningChanged: if (!running && root.polling) retry.restart()
    }
    // Bound retries if an adapter fails; never spin a crashed helper.
    Timer { id: retry; interval: 5000; onTriggered: if (root.polling) sampler.running = true }
}
