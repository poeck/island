# Island

A native Quickshell island for NixOS and Hyprland: a clock that morphs into media controls, an application launcher, notifications, OSDs, session actions, and authentication. True-black surfaces, a grayscale Linear-style interface with sparing indigo accents, rounded screen corners, and an interruptible, gently rebounding spring keep the interface close to the supplied references.

## First run

The flake pins **Quickshell 0.3.2 and Qt 6.11.2**. Start alongside your existing shell in preview mode:

```sh
nix develop path:.
island run --preview
```

In another terminal in the same development shell:

```sh
island launcher toggle
island demo media
island demo audio
island demo notification
island demo osd
island demo session
island demo auth
island demo lock
island demo compact
```

`demo hover` remains an alias for `demo media`.

Preview does not register notification or polkit services. Its session buttons are dry runs; the lock preview closes with Enter or Escape and never checks a password. Media, installed applications, ordinary audio, network and Bluetooth controls are real; launching an application still launches it, and changing sound devices, volume, network connections, or Bluetooth devices changes your session. `demo audio` instead uses simulated devices and applications, labeled PREVIEW, without changing your sound. `--showcase` adds a temporary illustrated background and sample media for visual inspection.

For the installed package:

```sh
nix build path:.
./result/bin/island run --preview
# Use ./result/bin/island for commands to this same instance.
```

`nix run path:. -- run --preview` and the pinned `nix-shell` entrypoint are also available. Keep the same source checkout or package for the process and its CLI commands: IPC explicitly addresses that configuration, never an unrelated Quickshell shell.

## Controls

| Command | Behavior |
| --- | --- |
| `run --preview` | Safe first run; also the default for `run` |
| `run --live` | Enable system integration and configured service ownership |
| `bar toggle` | Temporarily show/hide the bar over fullscreen |
| `launcher toggle` | Open/close installed-application search |
| `notifications toggle` | Session history, dismiss/clear, Do Not Disturb |
| `weather toggle` | Current conditions, saved city and daily/hourly forecasts |
| `calendar toggle` | Month calendar with live time and current date |
| `bluetooth toggle` | Bluetooth devices, pairing, adapter power and discovery |
| `network toggle` | Wi-Fi, Ethernet, IP details and saved VPN controls |
| `audio toggle` | Output/input devices and application volumes |
| `system toggle` | Usage, temperatures, battery and storage |
| `session toggle` | Lock, Suspend, Log Out, Reboot, Power Off |
| `dnd toggle` | Toggle suppression without opening history |
| `lock --wait` | **Real lock**, even when the island runs in preview; wait for compositor confirmation |
| `demo <state>` | Preview any reference state; requires preview mode |
| `dismiss` | Close an ordinary panel |
| `status` | Current state and animation diagnostics as JSON |
| `doctor` | Integration diagnostics as JSON |

Clicking the clock toggles the calendar notch. It shows a full Monday-first month, current local time with seconds, and the current weekday/date separately. Navigate months with the arrows or PgUp/PgDn, select dates with the mouse or arrow keys, and return to today with Today or Home. Selected dates show ISO week and day-of-year details. Seconds update only while the calendar is open. No accounts or events are required. Media controls remain available through `island media toggle` (`demo media` for sample media). Search supports Up/Down and Enter. The session menu supports arrow keys and Enter. Escape, a repeated shortcut, or an outside click closes ordinary panels on Hyprland. Authentication has its own Cancel action. Notifications wait while interactive panels are open; volume indicators become an inline strip. Suppressed notifications are retained in session history without a later popup burst.

The weather icon in the right-side control group opens the weather notch (`island weather toggle`). It shows current conditions, feels-like temperature, humidity, wind/gusts, sunrise/sunset, UV, pressure and precipitation, with seven daily forecasts or the next 24 hours. Change city searches cities/postcodes and remembers your selection; Vienna is the initial location. Forecast labels use the destination's timezone, including daylight-saving changes. Units are Celsius, km/h and mm.

Weather uses Open-Meteo without an API key. City search sends your search text to its geocoding service; forecasts send the selected coordinates, with no IP-location lookup. Requests start only when you open weather or search, and refresh every 15 minutes while open. Refresh bypasses the cache; unavailable connections retain any saved forecast and show its timestamp. `island demo weather` uses simulated conditions with no requests or changes to your saved city. Data attribution appears in the view. The free API is intended for personal/noncommercial use; commercial distributions should review Open-Meteo's terms.

The bell button on the right toggles notification history, including its existing Clear and Do Not Disturb controls.

The bar keeps resources on the left and the clock centered. Its tightly spaced right-side controls are ordered: tray dropdown, weather, Bluetooth, network, notifications, volume, and power. The power icon toggles the session menu; selecting an action remains a separate click.

The system tray works in preview and live mode using native StatusNotifier items. Click the chevron at the start of the right-side control group to reveal a compact icon grid; click it again, press Escape, or click outside to close. Arrow keys navigate the grid, Enter activates an item, and the Menu key or Shift+F10 opens its context menu. Inside the grid, left-click activates an app, right-click opens its menu, middle-click invokes its secondary action, and scrolling is forwarded to the app. Menu-only items open their menu on left-click. Menus match Island's rounded dark surfaces and grey highlights, including submenus, checkmarks, and keyboard navigation; Escape or an outside click closes them. Passive items are hidden; items needing attention receive an indigo dot on both the icon and the collapsed chevron. The chevron disappears when the tray is empty. Icons and tooltips follow the bar, and menus close when it slides away.

The left side shows CPU, RAM, supported GPU usage, and used disk space on the system filesystem (`/`), in that order, with stable-width percentages. A laptop battery adds its charge level; desktops and peripheral batteries do not. Click any reading to toggle the system notch, or use `island system toggle` (`island demo system` in preview). It shows 60 seconds of usage history, CPU/GPU temperatures, RAM/swap/VRAM, network rates, uptime, load averages, OS/kernel, and storage usage. Laptop details add charging estimates, power draw, and battery health when available. Escape, the close button, or clicking a reading again dismisses it.

The system notch also offers a compact Power Profile selector when a compatible power-profile daemon is running. It lists only supported Power Saver, Balanced and Performance modes, confirms the actual system selection, follows changes made by other apps, and explains thermal limits, inhibition or permission failures. Application profile requests are shown before a deliberate switch overrides them. It works on desktops and laptops independently of battery presence. The control is hidden when no provider is available; enable power-profiles-daemon (or a compatible provider) in the host system configuration to use it. Island does not enable a daemon or change profiles on startup.

Normal system controls are live in preview. `island demo system` instead simulates the power-profile selector, labeled PREVIEW, while the hardware readings stay live. Close the notch to return to real status.

The speaker icon in the right-side controls opens the audio notch (`island audio toggle`). Select an output or microphone directly from the two device lists. Each has independent volume and mute controls; the current device name remains visible and its row scrolls into view. The application mixer groups streams from the same app, with separate playback and microphone controls, adjusting or muting all matching streams together. Devices and apps disappear as they disconnect or stop using audio. Gain sliders cover 0–100% and preserve mute state. Selecting a device sets the PipeWire preference; WirePlumber applies it and manages active-stream routing. Virtual effects devices are listed alongside hardware. When EasyEffects is installed, the Effects button opens its existing effects/preset editor. There is no separate DSP or preset database in Island.

Audio uses the native PipeWire service in preview and live mode without claiming notification or authentication services. Preview suppresses global audio OSD monitoring to coexist with another shell. Use `island demo audio` to inspect and interact with sample speakers, headphones, microphones, and application volumes safely; Escape returns the bar to real audio status. No microphone monitoring stream is opened by the controls.

The network icon in the right-side controls opens the network notch (`island network toggle`). It uses NetworkManager for both Wi-Fi and LAN: select a wireless network to connect, enter a WPA/WPA2/WPA3 personal password when requested, or reconnect a saved network. Select a connected row to disconnect. The Wi-Fi switch respects hardware radio blocking. Wired adapters show cable state, link speed, IP addresses, router and DNS. Available saved VPN and WireGuard profiles can be connected or disconnected individually. Advanced enterprise credentials, certificates, new VPN setup and hidden-network configuration stay in your network editor; an advanced-settings button appears when `nm-connection-editor` is installed. NetworkManager and its VPN plugins must be enabled by the host system. No public-IP service is contacted.

Use `island demo network` for simulated Wi-Fi, Ethernet and VPN controls; Studio accepts the sample password `island-demo`. Passwords go directly to the native networking service, are cleared from the form after submission or dismissal, and never cross a shell command or Island IPC endpoint. Real network changes remain subject to NetworkManager permissions and the system secret agent.

The Bluetooth icon opens the Bluetooth notch (`island bluetooth toggle`). Connected and saved devices appear first, with type icons and reported batteries. Select a row for device details, or use its Pair / Connect / Disconnect button directly. Pairing supports numeric comparison, PIN/passkey entry, and codes to type on keyboards. Trust controls automatic reconnection; pairing does not silently grant trust. Forget requires a second deliberate click. Multiple adapters can be selected in the header. Scan runs for up to 20 seconds and stops on dismissal; discoverability is explicitly enabled for two minutes. Hardware-blocked and missing adapters have clear empty states.

Bluetooth controls are live in preview; use `island demo bluetooth` for simulated devices. The host must have BlueZ enabled (NixOS `hardware.bluetooth.enable = true;`). Island registers an application-scoped agent only when pairing is requested, never requests default-agent ownership, and does not interfere with other managers' scan sessions. Incoming pairings initiated on another device remain with the system's default agent. PINs/passkeys use private process pipes and are cleared from inputs after submission or dismissal; no credential files or public credential IPC are created.

System readings work in both preview and live mode and update every two seconds. NVIDIA uses the installed driver's `nvidia-smi`; AMD uses kernel sysfs counters; Intel uses readable DRM client counters for the current user's session. Unsupported usage readings are omitted from the bar, and missing sensors are identified in the details. A sleeping NVIDIA GPU is not queried. Network rates aggregate physical interfaces when available, avoiding duplicate VPN traffic. Storage includes `/` and Home when they are on different devices. Battery data comes from UPower.

## Integration settings

Copy [`examples/config.json`](examples/config.json) to `~/.config/island/config.json`, or use `island --config /path/to/config.json run --preview`.

```json
{
  "monitor": "AOC Q27G4ZR",
  "notifications": false,
  "polkit": false,
  "pamService": "swaylock",
  "terminal": ["alacritty", "-e"],
  "backlightDevice": "",
  "reducedMotion": false
}
```

The monitor selector matches an output name, model, or Hyprland description, case-insensitively. Island treats that output as its primary monitor, falls back to an available output, and returns when the preferred monitor reconnects. A full-width black bar reserves 28 logical pixels on that monitor, with a centered clock and a system tray aligned to the right. Its top screen corners begin below the bar; its bottom corners and all four corners on other monitors keep their usual placement. Click the clock to reveal the island, attached below the bar with concave shoulder joins and rounded bottom corners. Expanded views overlay applications without increasing the reservation. Fullscreen applications release the bar's reservation and hide the idle bar: it slides fully offscreen while both primary top corners move up to the screen edge, then returns on exit. Notifications, explicit panels, authentication, and OSDs remain available and restore the bar while shown. Notifications still respect Do Not Disturb and wait behind interactive panels, authentication, and OSDs.

An empty backlight device selects an available `/sys/class/backlight` device. No backlight or microphone means no placeholder UI. Brightness changes are observed, not applied. External-monitor DDC is not included. The terminal setting is an argument array, with any required execution flag, never a shell command string. Appearance constants live in `src/core/Theme.qml`; reduced motion changes geometry immediately and retains gentle fades.

`island bar toggle` reveals the bar over a fullscreen application without opening a panel or moving application windows. Run it again to end the manual reveal; an active notification, OSD, authentication dialog, or panel can still keep the bar visible. Leaving fullscreen or locking clears the reveal, and the command has no effect outside fullscreen. Bind it to Super+Space using the Lua example below; use the same Island executable/package as the running shell.

```lua
hl.bind("SUPER + Space", hl.dsp.exec_cmd("island bar toggle"))
```

## Live services and lock screen

1. Inspect all preview states and run `island doctor`.
2. Stop the preview process. Disable the overlapping notification and/or polkit agent in your existing shell using its normal configuration. Island never stops another shell.
3. Independently enable `notifications` and `polkit` in Island's configuration, then run `island run --live`. A notification ownership conflict is reported before launch; polkit registration failures are reported by the native agent.
4. Test `island lock --wait` from your session before adding it to idle/suspend automation.

The existing `/etc/pam.d/swaylock` service is used by default. If your NixOS configuration does not supply it, add `security.pam.services.swaylock = {};` through your normal NixOS configuration workflow. Never use the lock **preview** as a security mechanism.

The real locker is an independent Quickshell process with file watching and crash recovery disabled. It uses `ext-session-lock-v1`, covers hotplugged outputs, and reports success only after compositor confirmation. Desktop captures stay in RAM and have a 100 ms preparation deadline; missing captures use an opaque background. Only successful PAM authentication releases the lock. There is no unlock IPC command. Suspend first waits for secure lock acquisition. A locker crash leaves the compositor locked; recovery is compositor/session specific.

Live session-menu actions execute immediately after deliberate activation, including logout, reboot, and power off. Preview actions remain dry runs at both the UI and process boundaries.

## Home Manager and shortcuts

```nix
# Add this flake as inputs.island in your configuration.
imports = [ inputs.island.homeManagerModules.default ];
services.island = {
  enable = true;
  preview = true;
  settings.monitor = "AOC Q27G4ZR";
};
```

The module installs the package, writes the integration settings, and adds a graphical-session user service. Switch `preview = false` only after testing and coordinating service ownership. Your graphical session must export `WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE` into the systemd user environment.

[`examples/hyprland.lua`](examples/hyprland.lua) provides opt-in bindings for current Hyprland. [`examples/hypridle.conf`](examples/hypridle.conf) shows lock/suspend coordination. These files are examples; installation does not modify your active configuration or launch a second idle daemon.

## Development and verification

```sh
nix flake check path:.
nix develop path:. --command python3 tests/native_smoke.py
```

The native suite starts a disposable headless Sway compositor and private DBus session. It never connects to your active compositor, submits your password, or executes shutdown/reboot. It writes scale screenshots, transition recordings, logs, and a report into `artifacts/native/`. Sway is used as a protocol test host, not as a supported product target.

Preview watches QML files; live mode and the real locker do not. Set `ISLAND_WATCH=0` to disable preview reloads during recordings. See [architecture](docs/architecture.md) and [validation](docs/validation.md) for implementation details and the physical-monitor acceptance checklist.

No persistent notification database, quick settings, launcher extensions, calendar accounts, graphical theme editor, or support for other compositors is included in v1. Launch recency and the selected weather city persist under `$XDG_STATE_HOME/island`; weather forecasts are cached under `$XDG_CACHE_HOME/island`.

## Assets and dependencies

The package includes the pinned Inter font and its [SIL Open Font License](src/assets/Inter-OFL.txt). Line icons are from [Hugeicons Free](src/assets/Hugeicons-MIT.txt) (MIT), regenerated with `scripts/vendor-icons.py`. The illustrated showcase background and sample album artwork are project assets. Test-only virtual-pointer protocol definitions retain their upstream license header. Runtime services come from Quickshell; no web runtime is used.
