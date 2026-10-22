#!/usr/bin/env python3
"""Regenerate src/assets/icons from the free Hugeicons stroke-rounded set.

Usage:
  npm pack @iconify-json/hugeicons && tar xzf iconify-json-hugeicons-*.tgz
  python3 -I scripts/vendor-icons.py package/icons.json

Icon.qml colourises white artwork, so currentColor is baked to white.
"""
import json
import pathlib
import sys

# Island name -> Hugeicons name. Keep Island names stable; QML refers to them.
ICONS = {
    "app": "dashboard-square-01",
    "balance": "balance-scale",
    "battery": "battery-full",
    "battery-charging": "battery-charging-01",
    "bell": "notification-01",
    "bluetooth": "bluetooth",
    "brightness": "sun-03",
    "check": "tick-02",
    "chevron-left": "arrow-left-01",
    "chevron-right": "arrow-right-01",
    "circle": "circle",
    "close": "cancel-01",
    "cpu": "cpu",
    "effects": "sliders-horizontal",
    "ethernet": "computer-ethernet",
    "gpu": "gpu",
    "headphones": "headphones",
    "keyboard": "keyboard",
    "leaf": "leaf-01",
    "lock": "square-lock-02",
    "logout": "logout-03",
    "memory": "ram-memory",
    "mic": "mic-01",
    "mic-muted": "mic-off-01",
    "moon": "moon-02",
    "mouse": "mouse-01",
    "music": "music-note-01",
    "muted": "volume-mute-02",
    "network": "globe-02",
    "network-off": "wifi-disconnected-02",
    "next": "next",
    "pause": "pause",
    "performance": "dashboard-speed-01",
    "phone": "smart-phone-01",
    "play": "play",
    "power": "power",
    "previous": "previous",
    "reboot": "reload",
    "refresh": "refresh",
    "search": "search-01",
    "settings": "settings-02",
    "shield": "shield-key",
    "storage": "hard-drive",
    "user": "user",
    "volume": "volume-high",
    "weather-cloud": "cloud",
    "weather-fog": "cloud-fog",
    "weather-moon": "moon-02",
    "weather-partly": "sun-cloud-02",
    "weather-rain": "cloud-angled-rain",
    "weather-snow": "cloud-snow",
    "weather-storm": "cloud-angled-zap",
    "weather-sun": "sun-03",
    "wifi": "wifi-01",
}


def main():
    data = json.loads(pathlib.Path(sys.argv[1]).read_text())
    out = pathlib.Path(__file__).resolve().parent.parent / "src" / "assets" / "icons"
    size = data.get("width", 24), data.get("height", 24)
    missing = [source for source in ICONS.values() if source not in data["icons"]]
    if missing:
        sys.exit("missing Hugeicons: " + ", ".join(missing))
    for old in out.glob("*.svg"):
        old.unlink()
    for name, source in sorted(ICONS.items()):
        icon = data["icons"][source]
        width, height = icon.get("width", size[0]), icon.get("height", size[1])
        body = icon["body"].replace("currentColor", "white")
        (out / f"{name}.svg").write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>\n'
        )
    print(f"wrote {len(ICONS)} icons to {out}")


if __name__ == "__main__":
    main()
