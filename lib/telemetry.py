"""Read-only Linux telemetry. One resident sampler; no privileged helpers."""
from __future__ import annotations
import csv
import json
import math
import os
import platform
from pathlib import Path
import re
import shutil
import subprocess
import time


def read(path, default=""):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return default


def number(value, scale=1):
    try:
        value = float(value) * scale
        return value if math.isfinite(value) else None
    except (ValueError, TypeError):
        return None


def ratio(used, total):
    return max(0, min(100, used * 100 / total)) if total and used is not None else None


def cpu_times(text):
    # guest/guest_nice are already counted in user/nice; don't count them twice.
    values = [int(v) for v in text.splitlines()[0].split()[1:9]]
    return sum(values), sum(values[3:5])


def memory(text):
    values = {}
    for line in text.splitlines():
        key, _, value = line.partition(":")
        fields = value.split()
        if fields:
            values[key] = int(fields[0]) * 1024
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", values.get("MemFree", 0) + values.get("Buffers", 0) + values.get("Cached", 0) + values.get("SReclaimable", 0) - values.get("Shmem", 0))
    used = max(0, total - available)
    return {"total": total, "used": used, "usage": ratio(used, total),
            "swapTotal": values.get("SwapTotal", 0), "swapUsed": max(0, values.get("SwapTotal", 0) - values.get("SwapFree", 0))}


def temperatures(directory):
    result = []
    for sensor in sorted(Path(directory).glob("temp*_input")):
        value = number(read(sensor), .001)
        if value is not None and -20 < value < 150:
            result.append((read(sensor.with_name(sensor.name.replace("_input", "_label"))), value))
    return result


def nvidia_rows(text):
    result = []
    for row in csv.reader(text.splitlines(), skipinitialspace=True):
        if len(row) != 7:
            continue
        name, bus, usage, temp, used, total, power = row
        result.append({"id": bus.strip().lower(), "name": name.strip(), "vendor": "NVIDIA",
                       "usage": number(usage), "temperature": number(temp), "memoryUsed": number(used, 1024**2),
                       "memoryTotal": number(total, 1024**2), "power": number(power)})
    return result


def drm_clients(proc, devices):
    """Accessible clients only, deduplicated across shared/duplicated DRM fds."""
    result = {}
    for process in proc.glob("[0-9]*"):
        try:
            if process.stat().st_uid != os.getuid():
                continue
            for fd in (process / "fd").iterdir():
                try:
                    if not str(fd.readlink()).startswith("/dev/dri/"):
                        continue
                except OSError:
                    continue
                fields = dict(line.split(":", 1) for line in read(process / "fdinfo" / fd.name).splitlines() if ":" in line)
                fields = {key: value.strip() for key, value in fields.items()}
                device, client = fields.get("drm-pdev"), fields.get("drm-client-id")
                if device not in devices or client is None:
                    continue
                for key, value in fields.items():
                    if not key.startswith("drm-engine-") or key.startswith("drm-engine-capacity-"):
                        continue
                    engine = key.removeprefix("drm-engine-")
                    count = number(value.removesuffix(" ns"))
                    capacity = number(fields.get("drm-engine-capacity-" + engine, "1"))
                    if count is not None:
                        result[(device, client, engine)] = (count, max(1, capacity or 1))
        except OSError:
            continue
    return result


class Sampler:
    def __init__(self, proc=Path("/proc"), sys=Path("/sys"), home=None, runner=subprocess.run):
        self.proc, self.sys, self.home, self.runner = Path(proc), Path(sys), Path(home or Path.home()), runner
        self.previous_cpu, self.previous_net, self.previous_time = None, {}, None
        self.nvidia = shutil.which("nvidia-smi")
        self.nvidia_retry = 0
        self.previous_drm, self.drm_time, self.drm_supported = {}, None, set()
        info = read(self.proc / "cpuinfo")
        names = re.findall(r"^(?:model name|Hardware|Processor)\s*:\s*(.+)$", info, re.M)
        self.cpu_name = names[0] if names else "Processor"
        self.threads = len(re.findall(r"^processor\s*:", info, re.M)) or os.cpu_count() or 1
        try:
            self.os_name = platform.freedesktop_os_release().get("PRETTY_NAME", "Linux")
        except OSError:
            self.os_name = "Linux"

    def gpu_stats(self, now):
        result, nvidia_devices = [], []
        for card in sorted((self.sys / "class/drm").glob("card[0-9]*")):
            if not re.fullmatch(r"card\d+", card.name):
                continue
            device = card / "device"
            vendor = read(device / "vendor")
            if vendor == "0x10de":
                nvidia_devices.append(device)
                continue
            if not vendor:
                continue
            sensors = [value for hw in (device / "hwmon").glob("hwmon*") for _, value in temperatures(hw)]
            result.append({"id": device.resolve().name, "name": read(device / "product_name") or {"0x1002": "AMD Radeon", "0x8086": "Intel Graphics"}.get(vendor, "Graphics"),
                           "vendor": vendor, "usage": number(read(device / "gpu_busy_percent")),
                           "temperature": max(sensors) if sensors else None,
                           "memoryUsed": number(read(device / "mem_info_vram_used")),
                           "memoryTotal": number(read(device / "mem_info_vram_total")), "power": None})
        # Do not wake a runtime-suspended discrete GPU on a hybrid laptop.
        awake = [d for d in nvidia_devices if read(d / "power/runtime_status") != "suspended"]
        if self.nvidia and awake and now >= self.nvidia_retry:
            try:
                output = self.runner([self.nvidia, "--id=" + ",".join(d.resolve().name for d in awake), "--query-gpu=name,pci.bus_id,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw", "--format=csv,noheader,nounits"],
                                     capture_output=True, text=True, timeout=1.2, check=False)
                if output.returncode == 0:
                    result.extend(nvidia_rows(output.stdout))
                else:
                    self.nvidia_retry = now + 30
            except (OSError, subprocess.TimeoutExpired):
                self.nvidia_retry = now + 30
        if nvidia_devices and not any(g["vendor"] == "NVIDIA" for g in result):
            result.append({"id": "nvidia", "name": "NVIDIA Graphics", "vendor": "NVIDIA", "usage": None,
                           "temperature": None, "memoryUsed": None, "memoryTotal": None, "power": None,
                           "sleeping": not awake})
        # i915/xe usually lack gpu_busy_percent. Use standard DRM fdinfo counters
        # for this user's readable clients; no perf permissions or root required.
        devices = {gpu["id"] for gpu in result if gpu["vendor"] == "0x8086" and gpu["usage"] is None}
        if devices:
            clients = drm_clients(self.proc, devices)
            elapsed = now - self.drm_time if self.drm_time is not None else 0
            engines = {}
            for key, (count, capacity) in clients.items():
                self.drm_supported.add(key[0])
                previous = self.previous_drm.get(key)
                if previous is not None and elapsed > 0:
                    count = max(count, previous[0])
                    engine = (key[0], key[2])
                    engines[engine] = engines.get(engine, 0) + (count - previous[0]) / (elapsed * 1e9 * capacity) * 100
                    clients[key] = (count, capacity)
            for gpu in result:
                if gpu["id"] in self.drm_supported and self.drm_time is not None:
                    gpu["usage"] = min(100, max([v for (device, _), v in engines.items() if device == gpu["id"]], default=0))
                    gpu["usageScope"] = "session"
            self.previous_drm, self.drm_time = clients, now
        return result

    def sample(self, now=None):
        now = time.monotonic() if now is None else now
        try:
            current = cpu_times(read(self.proc / "stat"))
            before = self.previous_cpu
            usage = ratio(current[0] - before[0] - (current[1] - before[1]), current[0] - before[0]) if before and current[0] > before[0] and current[1] >= before[1] else None
            self.previous_cpu = current
        except (ValueError, IndexError):
            usage = None
            self.previous_cpu = None
        cpu_temp = []
        for hw in (self.sys / "class/hwmon").glob("hwmon*"):
            if read(hw / "name") in ("coretemp", "k10temp", "zenpower", "cpu_thermal", "cpu_thermal_zone"):
                cpu_temp += [v for _, v in temperatures(hw)]
        if not cpu_temp:
            for zone in (self.sys / "class/thermal").glob("thermal_zone*"):
                if re.search(r"cpu|x86_pkg|soc_thermal", read(zone / "type"), re.I):
                    value = number(read(zone / "temp"), .001)
                    if value is not None and -20 < value < 150:
                        cpu_temp.append(value)
        nets = {}
        for line in read(self.proc / "net/dev").splitlines()[2:]:
            name, _, data = line.partition(":")
            name = name.strip(); values = data.split()
            if len(values) >= 9 and name != "lo" and not re.match(r"veth|docker|br-|virbr", name):
                nets[name] = (int(values[0]), int(values[8]))
        physical = {name: value for name, value in nets.items() if (self.sys / "class/net" / name / "device").exists()}
        if physical:
            nets = physical  # Avoid counting VPN traffic again on its transport.
        elapsed = now - self.previous_time if self.previous_time is not None else 0
        rates = [((max(0, rx - self.previous_net[name][0]) / elapsed), (max(0, tx - self.previous_net[name][1]) / elapsed))
                 for name, (rx, tx) in nets.items() if elapsed > 0 and name in self.previous_net]
        self.previous_time, self.previous_net = now, nets
        disks = []
        seen = set()
        for path in (Path("/"), self.home):
            try:
                device = path.stat().st_dev
                if device in seen:
                    continue
                seen.add(device)
                fs = os.statvfs(path)
                total = fs.f_blocks * fs.f_frsize
                used = (fs.f_blocks - fs.f_bfree) * fs.f_frsize
                disks.append({"path": "/" if path == Path("/") else "Home", "total": total, "used": used,
                              "available": fs.f_bavail * fs.f_frsize, "usage": ratio(used, total)})
            except OSError:
                continue
        return {"cpu": {"name": self.cpu_name, "threads": self.threads, "usage": usage,
                        "temperature": max(cpu_temp) if cpu_temp else None,
                        "load": [float(v) for v in read(self.proc / "loadavg").split()[:3]]},
                "memory": memory(read(self.proc / "meminfo")), "gpus": self.gpu_stats(now), "disks": disks,
                "network": {"download": sum(r[0] for r in rates) if rates else None,
                            "upload": sum(r[1] for r in rates) if rates else None, "interfaces": sorted(nets)},
                "uptime": number(read(self.proc / "uptime").split(" ")[0]), "os": self.os_name,
                "kernel": read(self.proc / "sys/kernel/osrelease")}


def watch():
    sampler = Sampler()
    while True:
        started = time.monotonic()
        print(json.dumps(sampler.sample(started), allow_nan=False), flush=True)
        time.sleep(max(.1, 2 - (time.monotonic() - started)))
