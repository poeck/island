# Verification

Run `nix flake check path:.` for state policy, search, spring timing, CLI configuration and action dispatch, and strict QML linting. The QML checks use the pinned native imports. Four upstream tooling-metadata exceptions are documented next to their declarations; all other warnings fail the check.

Run `nix develop path:. --command python3 tests/native_smoke.py` for the isolated Wayland/DBus tests. Set `ISLAND_TEST_RENDERER=gles2` before that command to exercise GPU-backed captures; the default Pixman path exercises the opaque fallback. Generated evidence is in `artifacts/native/`, including `report.json`, screenshots at 100%, 125%, and 160%, and `transitions.mp4`. The input fixtures keep virtual devices connected, like physical devices, rather than repeatedly destroying the compositor's keyboard/pointer seat capabilities.

The native suite checks:

- Input while expanding, Escape, and restoration after a polkit preview.
- Click-only clock activation, pause-button dispatch, pointer movement persistence, clock toggling, and Escape dismissal.
- Clock/island interception, concave shoulder and rounded bottom click-through, and the empty input region while hidden.
- Fixed 28 px primary-bar reservation during expansion and monitor handover, plus screen-corner placement.
- A shared upward slide of the bar and primary top corners over a fullscreen client, rapid reversals, reduced motion, and no idle animation frames. `fullscreen.mp4` records this at all three scales.
- Bar resources stay on the left and the clock centered; tightly spaced right controls follow the requested order at 100/125/160%. Disk shows used root-filesystem space, and the power icon toggles the session view without executing an action.
- Ordinary panels request outside-click focus grabs without a Hyprland IPC environment variable; authentication excludes the grab. The Sway lab checks request policy. `tests/hyprland_smoke.py` reproduces the exclusive-layer conflict on real nested Hyprland and verifies outside dismissal, inside clicks, movement, keyboard input, bar toggles, authentication restoration and multiple outputs.
- Native StatusNotifier registration/removal, collapsed chevron, dropdown grid/reflow at 100/125/160% scaling, grid keyboard navigation, icons, primary/secondary/scroll dispatch, styled right-click menus, action dispatch, live checkbox updates, disabled entries, cascading submenus, keyboard navigation, Escape/outside-click dismissal, menu-only items, passive/attention states, tooltips, and fullscreen tray movement.
- System bar clicks and repeat toggles at 100%, 125%, and 160%, live updates, bounded history, authentication restoration, and system-notch screenshots. An injected UPower device verifies laptop battery visibility, charging estimates, health conversion, peripheral filtering, and removal; GPU removal is also exercised.
- Telemetry fixtures verify CPU counter deltas/resets, available-memory accounting, disappearing sensors and network interfaces, AMD/NVIDIA parsing, driver timeout backoff, suspended GPU handling, and deduplicated Intel DRM counters. Tests use no privileged GPU access.
- Audio screenshots at 100%, 125%, and 160%, pointer device selection, volume sliders, device/application mute, per-app volume, device/app removal, empty states, bar toggles, and authentication restoration. Policy tests cover application stream grouping, gain/mute aggregation, and device labels.
- Native audio tests start a private PipeWire daemon and WirePlumber session with hardware monitors disabled, two synthetic outputs/inputs, and silent synthetic playback. They verify actual default-device setters, active playback routing, output/input gain, microphone mute, application gain/mute, OSD notifications, and default fallback after removal. The host audio session is never targeted. Run just these checks with `ISLAND_TEST_AUDIO_ONLY=1 ISLAND_TEST_RENDERER=gles2 nix develop path:. --command python3 tests/native_smoke.py`.
- Native notification replacement, timeout, queued expiry, DND, and transient history behavior.
- Mocked PAM failure, start refusal, retry, multiple prompts, errors, and success-only unlock.
- Production lock acquisition, frozen-capture availability, new-output coverage, acquisition refusal, and inaccessible application input after a locker crash.
- Every reference view at all three requested scales, plus a transition recording.

## Recorded results

The package build, strict QML checks, policy/CLI tests, and complete GPU-backed native suite passed on 2026-10-21. The native suite also verified monitor removal, fallback, preferred-output return, terminal argument wrapping, working directories, and persistent launch recency. Its screenshots check that the island is actually rendered on the selected output after handover.

A separate preview pass ran on the **AOC Q27G4ZR (DP-2), 2560 × 1440, 125% scale, 240.001 Hz**. Measured spring settling was **290–322 ms** across hover, launcher, session, history, authentication, compact, and OSD states. That measurement predates the rebounding island spring (32 rad/s, ζ 0.72); the headless lab now reports 273–393 ms, and the physical pass should be repeated. The frame driver stopped after settling. All three physical outputs supplied frozen captures before the 100 ms deadline. See `artifacts/aoc-motion.json`. Hyprland-specific panel focus was checked there; the 32 ms grab-arm delay lets keyboard interactivity commit before the focus grab.

## Remaining live checks

Actual PipeWire device changes, a real polkit challenge, and successful PAM authentication with your account require live-service handover/user credentials. No real user password, shutdown, reboot, or suspend was used during testing. Before enabling ownership and idle locking, complete the relevant live checks below; the preview and timing checks can also be repeated for your own visual assessment:

1. Run preview on the AOC. Check its full-width 28 px black bar, centered clock, and top screen corners beginning below the bar. Expand each notch and check its concave joins and rounded bottom corners. Expanded states must not move application windows; other outputs must retain their original four corners and must not acquire a bar or reservation.
2. Toggle the clock repeatedly. Move down to the pause button, click it, move further down, and move away without clicking: media must stay open. Close it with the clock, Escape, or an outside click. Open the launcher and type immediately. Switch directly between launcher, history, and session menu. Check stable text, continuous motion, and outside-click dismissal.
3. Inspect `island status` after settling: `animating` must be false. Confirm idle GPU use and the absence of binding-loop warnings.
4. Toggle fullscreen repeatedly. The bar and primary top corners must slide upward together until the bar is fully hidden and the corners are fully visible at the screen edge, then slide back on exit; bottom corners must stay fixed. Test monitor removal/fallback and preferred-monitor reconnection.
5. Enable notification ownership independently. Exercise actions, replacement, DND, and bursts while the launcher is open. Enable polkit separately and check identity selection, wrong-password retry, and cancellation.
6. Test the real locker, password failure and success, and newly connected outputs. Confirm opaque fallback when capture is unavailable, then integrate the supplied hypridle example.
7. Change output volume/mute, microphone mute, and built-in brightness. Confirm coalescing, inline OSDs, and disappearance 1.5 seconds after the final change.

The automated suite never performs real shutdown/reboot or submits the user's password. Its fixture sources are not installed in the package.

Network UI checks use `ISLAND_TEST_NETWORK_ONLY=1 ISLAND_TEST_RENDERER=gles2 nix develop path:. --command python3 tests/native_smoke.py`. The native lab redirects the system bus as well as the session bus to its private bus. Simulated Wi-Fi/LAN/VPN objects exercise password rejection/retry through the real masked input field, saved/open/enterprise networks, Wi-Fi switching and scan lifetime, VPN toggles, cable unplug, adapter removal and backend unavailability. It never changes a host network connection. Hardware Wi-Fi association, host authorization/secret-agent integration and real VPN endpoints still require on-device testing. Calendar checks cover click activation, live seconds, stopped hidden clock, month/Today navigation, keyboard date selection, auth restoration and 100/125/160% captures. Pure date tests cover leap years, ISO week boundaries and DST civil days; metadata tests cover escaped network names and IPv6, absent NetworkManager and validated UUID-only VPN dispatch.

Bluetooth can be checked independently with `ISLAND_TEST_BLUETOOTH_ONLY=1 ISLAND_TEST_RENDERER=gles2 nix develop path:. --command python3 tests/native_smoke.py`. The private system bus hosts `tests/native/bluez.py`, exposing the actual BlueZ ObjectManager/Adapter1/Device1/Battery1/AgentManager1 protocol. The real Quickshell Bluetooth plugin and real private-stdio pairing bridge run against it. Checks cover discovery and cleanup, power/visibility, native batteries, connect/disconnect, numeric confirmation and rejection, wrong PIN/retry, numeric passkey input, keyboard-code display, trust, two-click forget, connection errors, cancellation on dismissal, agent unregistering, no default-agent takeover, adapter removal, and captures at 100/125/160%. The main shell additionally checks bar toggles, auth restoration, state priority and morphing with simulated devices. No host Bluetooth adapter or paired device is mutated. Physical pairing still needs testing with the user's actual peripherals and host BlueZ permissions.

Power profiles have an isolated check: `ISLAND_TEST_POWER_ONLY=1 ISLAND_TEST_RENDERER=gles2 nix develop path:. --command python3 tests/native_smoke.py`. The fake modern/legacy power-profile providers expose real DBus properties on the private system bus. Tests select all modes using actual buttons at 100/125/160%, omit unsupported performance, disable inhibited performance, show thermal degradation and application holds, reject denied writes without changing the highlighted mode, follow external switches, fall back to the legacy API, and recover when service names disappear/reappear. Unit checks validate daemon capabilities, typed hold parsing and rejected/no-op writes. All profile mutations use the private test provider; host capability checks are read-only.

Weather can be checked independently with `ISLAND_TEST_WEATHER_ONLY=1 ISLAND_TEST_RENDERER=gles2 nix develop path:. --command python3 tests/native_smoke.py`. An offline subprocess double exercises the actual request pipeline and city-picker UI, daily/hourly switching, empty searches, stale-result rejection, rapid city changes, cached and empty offline states, and demo isolation. Captures cover 100/125/160%. Python tests cover real request construction, cache expiry/refresh, city persistence, sparse/invalid API payloads, and destination timezone/DST conversion. No public service is contacted by the automated suite.

### Native Hyprland outside-click regression

From an existing Hyprland session, run:

```sh
nix develop --command python3 tests/hyprland_smoke.py --parent-display "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
```

The test opens a temporary nested Hyprland window using the parent compositor only for rendering. Its service bus, runtime directories, outputs and virtual input devices are private; no pointer/keyboard events or session actions are sent to the host desktop. The shell deliberately receives no Hyprland IPC signature. Results are written to `artifacts/hyprland/outside-click.json`.

Font rendering has a separate regression: build with `nix build path:.`, then run `nix develop path:. --command python3 tests/typography_smoke.py --package result`. It renders the packaged font offscreen with an isolated fontconfig containing no system fonts and without the development font override. Actual regular/medium/semibold/bold glyphs are compared with explicit-axis references at 100/125/160%; the check also covers controls, dynamic weight changes, and binding-loop diagnostics. `FontInfo.weight` alone cannot detect this failure. Evidence is saved in `artifacts/typography/`.
