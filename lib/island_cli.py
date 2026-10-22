"""Launch, control, and diagnose Island without modifying desktop configuration."""
from __future__ import annotations
import argparse
import configparser
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(os.environ.get("ISLAND_ROOT", Path(__file__).resolve().parents[1]))
SHELL = ROOT / "src/shell.qml"
LOCKER = ROOT / "src/locker.qml"
DEFAULTS = {"monitor": "AOC Q27G4ZR", "notifications": False, "polkit": False,
            "pamService": "swaylock", "terminal": ["alacritty", "-e"],
            "backlightDevice": "", "reducedMotion": False}

class IslandError(Exception):
    pass

def configuration(path=None):
    path = Path(path or os.environ.get("ISLAND_CONFIG_FILE", Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "island/config.json"))
    config = dict(DEFAULTS)
    if path.exists():
        try:
            value = json.loads(path.read_text())
        except (OSError, ValueError) as exc:
            raise IslandError(f"Cannot read {path}: {exc}") from exc
        if not isinstance(value, dict):
            raise IslandError("Configuration must be a JSON object.")
        unknown = set(value) - set(DEFAULTS)
        if unknown:
            raise IslandError("Unknown configuration options: " + ", ".join(sorted(unknown)))
        config.update(value)
    for key, default in DEFAULTS.items():
        if not isinstance(config[key], type(default)):
            raise IslandError(f"Invalid type for {key}.")
    if not config["terminal"] or not all(isinstance(v, str) and v for v in config["terminal"]):
        raise IslandError("terminal must be a nonempty argument array.")
    if "/" in config["pamService"] or not config["pamService"]:
        raise IslandError("pamService must be a service name from /etc/pam.d.")
    if "/" in config["backlightDevice"]:
        raise IslandError("backlightDevice must be a device name, not a path.")
    return config

def quickshell():
    executable = os.environ.get("ISLAND_QUICKSHELL") or shutil.which("quickshell") or shutil.which("qs")
    if not executable:
        raise IslandError("Quickshell is missing. Use nix develop or nix run . -- run --preview.")
    return executable

def environment(config, mode="preview", **extra):
    env = dict(os.environ)
    env.update(ISLAND_CONFIG=json.dumps(config), ISLAND_MODE=mode,
               ISLAND_EXECUTABLE=os.environ.get("ISLAND_EXECUTABLE", str(ROOT / "bin/island")),
               QS_NO_RELOAD_POPUP="1")
    env.update(extra)
    return env

def ipc(target, function, *args, shell=SHELL, check=True):
    result = subprocess.run([quickshell(), "ipc", "-p", str(shell), "call", target, function,
                             *(str(a).lower() if isinstance(a, bool) else str(a) for a in args)],
                            capture_output=True, text=True, timeout=4)
    if check and result.returncode:
        raise IslandError(result.stderr.strip() or "Island is not running on this display.")
    return result

def notification_owner():
    if not shutil.which("gdbus"):
        return None
    result = subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.DBus",
                             "--object-path", "/org/freedesktop/DBus", "--method",
                             "org.freedesktop.DBus.NameHasOwner", "org.freedesktop.Notifications"],
                            capture_output=True, text=True, timeout=3)
    return "true" in result.stdout if result.returncode == 0 else None

def run_shell(args, config):
    mode = "live" if args.live else "preview"
    if not os.environ.get("WAYLAND_DISPLAY"):
        raise IslandError("No Wayland display is set. Run Island from a terminal in your Hyprland session.")
    if mode == "live" and config["notifications"] and notification_owner():
        raise IslandError("Another notification server owns this session. Disable its notification service before enabling Island notifications; no process was stopped.")
    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "island"
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    env = environment(config, mode, ISLAND_SHOWCASE="1" if args.showcase else "0", ISLAND_DEMO=args.demo or "")
    os.execvpe(quickshell(), [quickshell(), "-p", str(SHELL), "--no-duplicate"], env)

def lock(config, wait=True):
    if not Path("/etc/pam.d", config["pamService"]).is_file():
        raise IslandError(f"PAM service {config['pamService']} is not installed; lock was not started.")
    if not os.environ.get("WAYLAND_DISPLAY"):
        raise IslandError("A Wayland session is required to lock.")
    env = environment(config, "live", QS_DISABLE_FILE_WATCHER="1", QS_DISABLE_CRASH_HANDLER="1")
    result = subprocess.run([quickshell(), "-p", str(LOCKER), "--no-duplicate", "--daemonize"], env=env, timeout=8)
    if result.returncode:
        raise IslandError("The locker failed to start. Suspend was not requested.")
    if not wait:
        return
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        response = ipc("lock", "status", shell=LOCKER, check=False)
        if response.returncode == 0:
            try:
                status = json.loads(response.stdout)
                if status.get("secure"):
                    return
                if status.get("error"):
                    raise IslandError(status["error"])
            except ValueError:
                pass
        time.sleep(0.05)
    raise IslandError("The compositor did not confirm a secure lock. Suspend was not requested. An existing locker may already own the session.")

def session_action(action, config, runner=subprocess.run, locker=lock):
    # The UI and this process boundary both enforce preview's dry-run behavior.
    if os.environ.get("ISLAND_MODE") != "live":
        return {"dryRun": True, "action": action}
    if action in ("lock", "suspend"):
        locker(config, wait=True)
        if action == "lock":
            return {"action": action}
    commands = {"suspend": ["systemctl", "suspend"], "reboot": ["systemctl", "reboot"],
                "poweroff": ["systemctl", "poweroff"], "logout": ["hyprctl", "dispatch", "exit"]}
    if action not in commands:
        raise IslandError("Unknown session action.")
    result = runner(commands[action], check=False)
    if result.returncode:
        raise IslandError(f"{action} failed (exit {result.returncode}).")
    return {"action": action}

def read_backlight(base=Path("/sys/class/backlight"), device=""):
    devices = [base / device] if device else sorted(base.glob("*"))
    for path in devices:
        try:
            maximum = int((path / "max_brightness").read_text())
            actual = path / "actual_brightness"
            current = int((actual if actual.exists() else path / "brightness").read_text())
            if maximum > 0:
                return path.name, round(current * 100 / maximum)
        except (OSError, ValueError):
            continue
    return None

def watch_backlight(config):
    previous = read_backlight(device=config["backlightDevice"])
    # sysfs does not reliably emit inotify events; one resident process polls values,
    # without spawning brightnessctl or redrawing QML while unchanged.
    while True:
        time.sleep(0.25 if previous else 2)
        current = read_backlight(device=config["backlightDevice"])
        if current and previous and current[0] == previous[0] and current[1] != previous[1]:
            print(json.dumps({"changed": True, "value": current[1]}), flush=True)
        previous = current

def visible_applications(env=None):
    """Supplement Quickshell's desktop entries with XDG visibility/TryExec rules."""
    env = os.environ if env is None else env
    roots = [env.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))]
    roots += env.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    desktops = set(env.get("XDG_CURRENT_DESKTOP", "Hyprland").split(":"))
    seen, visible = set(), []
    for root in roots:
        base = Path(root) / "applications"
        for path in sorted(base.rglob("*.desktop")) if base.is_dir() else []:
            identity = str(path.relative_to(base)).replace("/", "-")
            if identity in seen:
                continue
            seen.add(identity)
            try:
                parser = configparser.ConfigParser(interpolation=None, strict=False)
                parser.read(path, encoding="utf-8")
                entry = parser["Desktop Entry"]
                if entry.get("Type", "Application") != "Application" or any(entry.get(k, "false").lower() == "true" for k in ("Hidden", "NoDisplay")):
                    continue
                only = set(filter(None, entry.get("OnlyShowIn", "").split(";")))
                excluded = set(filter(None, entry.get("NotShowIn", "").split(";")))
                if (only and not desktops.intersection(only)) or desktops.intersection(excluded):
                    continue
                executable = entry.get("TryExec", "")
                if executable and not shutil.which(executable, path=env.get("PATH")):
                    continue
                visible.append(identity)
            except (OSError, ValueError, KeyError, configparser.Error):
                continue
    return visible

def doctor(config):
    qs = os.environ.get("ISLAND_QUICKSHELL") or shutil.which("quickshell") or shutil.which("qs")
    checks = {"quickshell": qs, "waylandDisplay": os.environ.get("WAYLAND_DISPLAY"),
              "hyprland": bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")),
              "pamService": str(Path("/etc/pam.d", config["pamService"])),
              "pamAvailable": Path("/etc/pam.d", config["pamService"]).is_file(),
              "notificationServerPresent": notification_owner(),
              "notificationsEnabled": config["notifications"], "polkitEnabled": config["polkit"],
              "backlight": read_backlight(device=config["backlightDevice"]), "monitorMatch": config["monitor"]}
    print(json.dumps(checks, indent=2))
    return 0 if qs and checks["waylandDisplay"] else 1

def main(argv=None):
    parser = argparse.ArgumentParser(description="Island — a morphing Quickshell island")
    parser.add_argument("--config", help="Integration configuration JSON")
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("run")
    modes = run.add_mutually_exclusive_group()
    modes.add_argument("--preview", action="store_true", help="Safe side-by-side preview (default)")
    modes.add_argument("--live", action="store_true", help="Enable configured desktop services")
    run.add_argument("--showcase", action="store_true", help="Temporary illustrated background and sample media")
    run.add_argument("--demo", choices=["compact", "media", "hover", "system", "audio", "network", "bluetooth", "weather", "calendar", "launcher", "notification", "notifications", "osd", "session", "auth", "lock"])
    for name in ("launcher", "notifications", "session", "system", "audio", "network", "bluetooth", "weather", "calendar", "media", "dnd"):
        item = sub.add_parser(name); item.add_argument("operation", choices=["toggle"])
    sub.add_parser("dismiss")
    sub.add_parser("status")
    sub.add_parser("doctor")
    locker = sub.add_parser("lock"); locker.add_argument("--wait", action="store_true", help="Wait for compositor-confirmed coverage (also the default)")
    demo = sub.add_parser("demo"); demo.add_argument("state", choices=["compact", "media", "hover", "system", "audio", "network", "bluetooth", "weather", "calendar", "launcher", "notification", "notifications", "osd", "session", "auth", "lock"])
    internal = sub.add_parser("internal", help=argparse.SUPPRESS)
    internal.add_argument("operation", choices=["watch-backlight", "watch-system", "watch-power-profiles", "network-snapshot", "vpn-action", "bluetooth-bridge", "weather-request", "session-action", "locked", "app-visibility"])
    internal.add_argument("value", nargs="?")
    args = parser.parse_args(argv)
    try:
        config = configuration(args.config)
        # Child adapters inherit the exact configuration of the running shell.
        if args.command == "internal" and os.environ.get("ISLAND_CONFIG"):
            config = json.loads(os.environ["ISLAND_CONFIG"])
        if args.command == "run": run_shell(args, config)
        elif args.command == "doctor": return doctor(config)
        elif args.command == "lock": lock(config)
        elif args.command == "internal":
            if args.operation == "watch-backlight": watch_backlight(config)
            elif args.operation == "watch-power-profiles":
                from power_profiles import main as power_main
                power_main()
            elif args.operation == "weather-request":
                from weather import main as weather_main
                weather_main(args.value or "{}")
            elif args.operation == "bluetooth-bridge":
                from bluetooth_bridge import main as bridge_main
                bridge_main()
            elif args.operation == "network-snapshot":
                from network import snapshot
                print(json.dumps(snapshot()))
            elif args.operation == "vpn-action":
                from network import vpn_action
                print(json.dumps(vpn_action(args.value or "")))
            elif args.operation == "watch-system":
                from telemetry import watch
                watch()
            elif args.operation == "app-visibility": print(json.dumps(visible_applications()))
            elif args.operation == "session-action": print(json.dumps(session_action(args.value, config)))
            elif args.operation == "locked": ipc("island", "locked", args.value == "true", check=False)
        elif args.command == "demo":
            result = ipc("island", "demo", args.state).stdout.strip()
            if result != "ok": raise IslandError(result)
        elif args.command in ("launcher", "notifications", "session", "system", "audio", "network", "bluetooth", "weather", "calendar", "media"): ipc("island", "toggle", args.command)
        elif args.command == "dnd": print(ipc("island", "dnd").stdout.strip())
        elif args.command == "status": print(ipc("island", "status").stdout.strip())
        else: ipc("island", "dismiss")
        return 0
    except (IslandError, OSError, subprocess.TimeoutExpired, ValueError) as exc:
        print(f"island: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130

if __name__ == "__main__":
    raise SystemExit(main())
