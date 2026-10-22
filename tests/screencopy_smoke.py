#!/usr/bin/env python3
"""Exercise native capture, the resume null-screen regression and locker hotplug.

Run in nix develop. All compositor, bus and lock state belongs to a private lab;
no host input, authentication or power operations are performed.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/screencopy'


def eventually(check, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            value = check()
            if value:
                return value
        except (subprocess.CalledProcessError, ValueError):
            pass
        time.sleep(.05)
    raise AssertionError('Timed out waiting for ' + str(check))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    processes, logs = [], []
    with tempfile.TemporaryDirectory(prefix='island-screencopy-') as directory:
        base = Path(directory)
        env = dict(os.environ)
        for key in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE',
                    'DBUS_SESSION_BUS_ADDRESS', 'DBUS_SYSTEM_BUS_ADDRESS', 'SWAYSOCK', 'LD_PRELOAD'):
            env.pop(key, None)
        for key in ('XDG_RUNTIME_DIR', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_DATA_HOME'):
            path = base / key
            path.mkdir(mode=0o700)
            env[key] = str(path)
        env.update(WLR_BACKENDS='headless', WLR_RENDERER='gles2', WLR_LIBINPUT_NO_DEVICES='1',
                   LIBGL_ALWAYS_SOFTWARE='1', QT_QPA_PLATFORM='wayland', QT_QPA_PLATFORMTHEME='',
                   QS_DISABLE_CRASH_HANDLER='1', ISLAND_WATCH='0', ISLAND_MODE='live',
                   ISLAND_CONFIG='{}', ISLAND_EXECUTABLE=str(ROOT/'bin/island'), NO_AT_BRIDGE='1')
        qs = env.get('ISLAND_QUICKSHELL') or shutil.which('quickshell')

        def run(args, childenv=None):
            return subprocess.run(args, env=childenv or env, capture_output=True, text=True, check=True, timeout=10).stdout.strip()

        def spawn(args, name, childenv=None):
            log = open(OUT/(name+'.log'), 'w')
            logs.append(log)
            process = subprocess.Popen(args, env=childenv or env, stdout=log, stderr=log, start_new_session=True)
            processes.append(process)
            return process

        try:
            # The helper invokes only the native ShellScreen invalidation slot.
            helper = base/'screen-probe.cpp'
            shutil.copy(ROOT/'tests/native/screen-probe.cpp', helper)
            moc = Path(run(['pkg-config', '--variable=libexecdir', 'Qt6Core']))/'moc'
            run([str(moc), str(helper), '-o', str(base/'screen-probe.moc')])
            flags = run(['pkg-config', '--cflags', '--libs', 'Qt6Qml']).split()
            library = base/'screen-probe.so'
            run(['c++', '-shared', '-fPIC', str(helper), '-o', str(library), *flags])
            busconf = base/'bus.conf'
            busconf.write_text('<busconfig><type>session</type><listen>unix:tmpdir='+env['XDG_RUNTIME_DIR']+
                               '</listen><policy context="default"><allow own="*"/><allow send_destination="*"/>'
                               '<allow receive_sender="*"/></policy></busconfig>')
            bus = subprocess.Popen(['dbus-daemon', '--config-file='+str(busconf), '--nofork', '--print-address'],
                                   env=env, stdout=subprocess.PIPE, text=True, start_new_session=True)
            processes.append(bus)
            env['DBUS_SESSION_BUS_ADDRESS'] = bus.stdout.readline().strip()
            env['DBUS_SYSTEM_BUS_ADDRESS'] = env['DBUS_SESSION_BUS_ADDRESS']
            config = base/'sway.conf'
            config.write_text('output HEADLESS-1 mode 1280x720\noutput * bg #264153 solid_color\nseat seat0 fallback true\nxwayland disable\n')
            spawn(['sway', '-c', str(config)], 'compositor')
            runtime = Path(env['XDG_RUNTIME_DIR'])
            sock = eventually(lambda: next((p for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')), None))
            env['WAYLAND_DISPLAY'] = sock.name
            env['SWAYSOCK'] = str(eventually(lambda: next(runtime.glob('sway-ipc.*.sock'), None)))
            probe = run([qs, '-p', str(ROOT/'tests/native/screencopy.qml')], dict(env, LD_PRELOAD=str(library)))
            (OUT/'probe.log').write_text(probe+'\n')
            assert 'VALID_CAPTURE' in probe and 'DANGLING_CAPTURE_DECLINED' in probe, probe

            # Use the unmodified production locker with normal buffers/screens.
            locker = spawn([qs, '-p', str(ROOT/'src/locker.qml')], 'locker')

            def status():
                return json.loads(run([qs, 'ipc', '-p', str(ROOT/'src/locker.qml'), 'call', 'lock', 'status']))

            first = eventually(lambda: status() if status()['secure'] else None)
            assert first['captured'], first
            run(['swaymsg', 'create_output'])
            eventually(lambda: len(status()['outputs']) == 2 and status()['secure'])
            for _ in range(3):
                run(['swaymsg', 'output', 'HEADLESS-2', 'disable'])
                eventually(lambda: len(status()['outputs']) == 1 and status()['secure'])
                run(['swaymsg', 'output', 'HEADLESS-2', 'enable'])
                eventually(lambda: len(status()['outputs']) == 2 and status()['secure'])
            assert locker.poll() is None
            report = {'validCapture': True, 'danglingCaptureDeclined': True, 'lockSecure': True,
                      'lockCaptured': first['captured'], 'lockedMonitorCycles': 3,
                      'limitations': ['Private headless Sway lab; real suspend/resume still needs on-device validation.']}
            (OUT/'report.json').write_text(json.dumps(report, indent=2)+'\n')
            print(json.dumps(report, indent=2))
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=3)
            for log in logs:
                log.close()


if __name__ == '__main__':
    main()
