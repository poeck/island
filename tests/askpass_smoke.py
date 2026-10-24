#!/usr/bin/env python3
"""Real shell/askpass input on private headless Wayland and DBus, without sudo."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/askpass'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    processes, logs = [], []
    with tempfile.TemporaryDirectory(prefix='island-askpass-', dir='/tmp') as directory:
        base = Path(directory)
        env = dict(os.environ)
        for key in ('WAYLAND_DISPLAY', 'DISPLAY', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE',
                    'DBUS_SESSION_BUS_ADDRESS', 'PIPEWIRE_RUNTIME_DIR', 'PIPEWIRE_REMOTE', 'PULSE_SERVER'):
            env.pop(key, None)
        for key in ('XDG_RUNTIME_DIR', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'XDG_CONFIG_HOME'):
            path = base / key
            path.mkdir(mode=0o700)
            env[key] = str(path)
        env.update(WLR_BACKENDS='headless', WLR_RENDERER='pixman', WLR_LIBINPUT_NO_DEVICES='1',
                   QT_QPA_PLATFORM='wayland', QT_QPA_PLATFORMTHEME='', QS_DISABLE_CRASH_HANDLER='1',
                   ISLAND_WATCH='0', ISLAND_MODE='live', ISLAND_EXECUTABLE=str(ROOT / 'bin/island'),
                   ISLAND_CONFIG='{"askpass":true,"monitor":"HEADLESS-1"}',
                   SUDO_ASKPASS_ACTION='Validate sudo credentials', SUDO_ASKPASS_TARGET='root',
                   SUDO_ASKPASS_DIRECTORY='/fixture', PIPEWIRE_REMOTE='island-test')
        env['PIPEWIRE_RUNTIME_DIR'] = env['XDG_RUNTIME_DIR']

        def spawn(command, name, **kwargs):
            log = open(OUT / (name + '.log'), 'w')
            logs.append(log)
            if kwargs.get('stdout') == subprocess.DEVNULL:
                kwargs['stdout'] = log
            process = subprocess.Popen(command, env=env, stderr=log, **kwargs)
            processes.append(process)
            return process

        def run(command):
            return subprocess.run(command, env=env, capture_output=True, text=True, timeout=8, check=True)

        def eventually(check):
            deadline = time.monotonic() + 6
            while time.monotonic() < deadline:
                try:
                    if value := check():
                        return value
                except (subprocess.CalledProcessError, ValueError, FileNotFoundError):
                    pass
                time.sleep(.04)
            raise AssertionError('Timed out waiting for ' + str(check))

        quickshell = os.environ.get('ISLAND_QUICKSHELL') or shutil.which('quickshell')

        def ipc(method, *args):
            return run([quickshell, 'ipc', '-p', str(ROOT / 'src/shell.qml'), 'call', 'island', method, *args]).stdout

        def status():
            return json.loads(ipc('status'))

        def helper(name):
            return spawn([str(ROOT / 'bin/island-askpass'), '[sudo] password for fixture:'], name, stdout=subprocess.PIPE)

        def keys(*args):
            run(['wtype', '-s', '100', *args])

        try:
            bus = spawn(['dbus-daemon', '--session', '--nofork', '--print-address'], 'dbus', stdout=subprocess.PIPE, text=True)
            env['DBUS_SESSION_BUS_ADDRESS'] = bus.stdout.readline().strip()
            env['DBUS_SYSTEM_BUS_ADDRESS'] = env['DBUS_SESSION_BUS_ADDRESS']
            config = base / 'sway.conf'
            config.write_text('output HEADLESS-1 mode 1280x800\nseat seat0 fallback true\n')
            sway = spawn(['sway', '-c', str(config)], 'sway', stdout=subprocess.DEVNULL)
            eventually(lambda: list(Path(env['XDG_RUNTIME_DIR']).glob('wayland-*')))
            env['WAYLAND_DISPLAY'] = next(p.name for p in Path(env['XDG_RUNTIME_DIR']).glob('wayland-*') if not p.name.endswith('.lock'))
            shell = spawn([quickshell, '-p', str(ROOT / 'src/shell.qml')], 'shell', stdout=subprocess.DEVNULL)
            eventually(lambda: status()['askpass'])
            ipc('toggle', 'launcher')
            eventually(lambda: status()['launcherFocused'])
            keys('fixture-query')
            eventually(lambda: status()['query'] == 'fixture-query')

            first = helper('success')
            eventually(lambda: status()['mode'] == 'auth')
            assert not status()['outsideClickRequested']
            time.sleep(.4)
            run(['grim', '-o', 'HEADLESS-1', str(OUT / 'sudo-auth.png')])
            keys('synthetic-fixture', '-k', 'Return')
            stdout, _ = first.communicate(timeout=5)
            assert first.returncode == 0 and stdout == b'synthetic-fixture\n'
            eventually(lambda: status()['mode'] == 'launcher' and status()['query'] == 'fixture-query')

            # Enter must not resubmit a previous password; Escape cancels instead.
            second = helper('cancel')
            eventually(lambda: status()['mode'] == 'auth')
            keys('-k', 'Return')
            assert second.poll() is None
            keys('-k', 'Escape')
            assert second.communicate(timeout=5)[0] == b'' and second.returncode == 1
            eventually(lambda: status()['mode'] == 'launcher')

            third = helper('disconnect')
            eventually(lambda: status()['mode'] == 'auth')
            third.terminate()
            third.wait(timeout=5)
            eventually(lambda: status()['mode'] == 'launcher')

            # Simulate the shell's lock state; never create a real session lock.
            ipc('locked', 'true')
            fourth = helper('locked')
            time.sleep(.3)
            assert fourth.poll() is None and status()['mode'] == 'hidden'
            ipc('locked', 'false')
            eventually(lambda: status()['mode'] == 'auth')
            keys('-k', 'Escape')
            assert fourth.communicate(timeout=5)[0] == b''

            # Shutdown fails pending helpers instead of leaving them waiting.
            fifth = helper('shutdown')
            eventually(lambda: status()['mode'] == 'auth')
            shell.terminate()
            shell.wait(timeout=5)
            assert fifth.communicate(timeout=5)[0] == b'' and fifth.returncode == 1
            text = (OUT / 'shell.log').read_text()
            assert 'synthetic-fixture' not in text
            for error in ('ReferenceError', 'TypeError', 'Binding loop', 'is not defined', 'Cannot assign'):
                assert error not in text, text
            print('ASKPASS_SMOKE_PASS: submit, cancel, fresh input, disconnect, lock deferral, launcher restoration, shutdown; no real sudo/password')
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            for log in logs:
                log.close()


if __name__ == '__main__':
    main()
