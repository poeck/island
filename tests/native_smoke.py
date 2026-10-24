#!/usr/bin/env python3
"""Disposable Wayland/DBus lab. Never connects to the user's compositor or executes power actions."""
import json
import contextlib
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/native'
OUT.mkdir(parents=True, exist_ok=True)
QS = os.environ.get('ISLAND_QUICKSHELL') or shutil.which('quickshell')
processes = []
logs = []
temporary = []

def spawn(args, env, name):
    log = open(OUT / (name + '.log'), 'w')
    logs.append(log)
    p = subprocess.Popen(args, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    processes.append(p)
    return p

def run(args, env, check=True):
    return subprocess.run(args, env=env, text=True, capture_output=True, check=check, timeout=10)

def eventually(fn, timeout=5):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            result = fn()
            if result: return result
        except (subprocess.CalledProcessError, ValueError, FileNotFoundError): pass
        time.sleep(.04)
    raise AssertionError('Timed out waiting for ' + str(fn))

def main():
    with contextlib.nullcontext(tempfile.mkdtemp(prefix='island-native-', dir='/tmp')) as directory:
        base = Path(directory); temporary.append(base)
        env = dict(os.environ)
        for key in ('WAYLAND_DISPLAY', 'DISPLAY', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE', 'DBUS_SESSION_BUS_ADDRESS', 'PIPEWIRE_RUNTIME_DIR', 'PIPEWIRE_REMOTE', 'PULSE_SERVER'):
            env.pop(key, None)
        for key, name in [('XDG_RUNTIME_DIR', 'runtime'), ('XDG_STATE_HOME', 'state'), ('XDG_CACHE_HOME', 'cache'), ('XDG_CONFIG_HOME', 'config')]:
            path = base / name; path.mkdir(mode=0o700); env[key] = str(path)
        settings=Path(env['XDG_CONFIG_HOME'])/'island';settings.mkdir()
        (settings/'config.json').write_text(json.dumps({'monitor':'HEADLESS-1'}))
        env.update(WLR_BACKENDS='headless', WLR_RENDERER=os.environ.get('ISLAND_TEST_RENDERER','pixman'), WLR_LIBINPUT_NO_DEVICES='1', QT_QPA_PLATFORM='wayland', QS_DISABLE_CRASH_HANDLER='1', ISLAND_WATCH='0', ISLAND_MODE='preview', QT_QPA_PLATFORMTHEME='', NO_AT_BRIDGE='1', ISLAND_EXECUTABLE=str(ROOT / 'bin/island'))
        env.update(PIPEWIRE_RUNTIME_DIR=env['XDG_RUNTIME_DIR'], PIPEWIRE_REMOTE='island-test')
        bus_config = base/'bus.conf'
        bus_config.write_text('<busconfig><type>session</type><listen>unix:tmpdir='+env['XDG_RUNTIME_DIR']+'</listen><policy context="default"><allow own="*"/><allow send_destination="*"/><allow receive_sender="*"/></policy></busconfig>')
        bus = subprocess.Popen(['dbus-daemon', '--config-file='+str(bus_config), '--nofork', '--print-address'], env=env, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, start_new_session=True)
        processes.append(bus); env['DBUS_SESSION_BUS_ADDRESS'] = bus.stdout.readline().strip()
        env['DBUS_SYSTEM_BUS_ADDRESS'] = env['DBUS_SESSION_BUS_ADDRESS']
        # A private PipeWire graph with synthetic devices only. Disable every
        # hardware monitor before starting the private session manager.
        pwconf=Path(env['XDG_CONFIG_HOME'])/'pipewire/pipewire.conf.d'
        pwconf.mkdir(parents=True)
        (pwconf/'90-island-test.conf').write_text('''context.properties = { core.name = island-test }
context.spa-libs = { audiotestsrc = audiotestsrc/libspa-audiotestsrc }
context.objects = [
{ factory = adapter args = { factory.name = support.null-audio-sink node.name = test_output_a node.description = "Test speakers" media.class = Audio/Sink audio.position = [ FL FR ] } }
{ factory = adapter args = { factory.name = support.null-audio-sink node.name = test_output_b node.description = "Test headphones" media.class = Audio/Sink audio.position = [ FL FR ] } }
{ factory = adapter args = { factory.name = audiotestsrc node.name = test_input_a node.description = "Test microphone" media.class = Audio/Source audio.channels = 2 audio.position = [ FL FR ] } }
{ factory = adapter args = { factory.name = audiotestsrc node.name = test_input_b node.description = "Test headset mic" media.class = Audio/Source audio.channels = 2 audio.position = [ FL FR ] } }
]''')
        wpconf=Path(env['XDG_CONFIG_HOME'])/'wireplumber/wireplumber.conf.d'
        wpconf.mkdir(parents=True)
        (wpconf/'90-island-test.conf').write_text('''wireplumber.profiles = { main = {
monitor.alsa = disabled
monitor.bluez = disabled
monitor.bluez-midi = disabled
monitor.v4l2 = disabled
monitor.libcamera = disabled
} }''')
        spawn(['pipewire'],env,'pipewire')
        eventually(lambda: (Path(env['XDG_RUNTIME_DIR'])/'island-test').exists())
        spawn(['wireplumber'],env,'wireplumber')
        config = base / 'sway.conf'
        config.write_text('output HEADLESS-1 mode 1920x1080 scale 1\noutput * bg #264153 solid_color\nseat seat0 fallback true\nxwayland disable\n')
        spawn(['sway', '-c', str(config)], env, 'compositor')
        socket = eventually(lambda: next((p for p in (base/'runtime').glob('wayland-*') if not p.name.endswith('.lock')), None))
        env['WAYLAND_DISPLAY'] = socket.name
        env['SWAYSOCK'] = str(eventually(lambda: next((base/'runtime').glob('sway-ipc.*.sock'), None)))
        # Fixtures are inside a temporary Quickshell configuration root, never shipped in the package.
        source = base/'source'; shutil.copytree(ROOT/'src', source)
        for fixture in (ROOT/'tests/native').glob('*.qml'): shutil.copy(fixture, source/fixture.name)
        def ipc(path, target, method, *args):
            return run([QS, 'ipc', '-p', str(path), 'call', target, method, *map(str,args)], env).stdout.strip()
        def shell(method, *args): return ipc(ROOT/'src/shell.qml', 'island', method, *args)
        def status(): return json.loads(shell('status'))
        def bar_point(name, scale=1):
            rect=status()['barLayout'][name]
            return round((rect['x']+rect['width']/2)*scale), round((rect['y']+rect['height']/2)*scale)
        def bar_click(name, scale=1): click(*bar_point(name,scale))
        def command(*args): return run(['swaymsg', *args], env)
        protocol=ROOT/'tests/native/wlr-virtual-pointer-unstable-v1.xml'
        run(['wayland-scanner','client-header',str(protocol),str(base/'pointer-protocol.h')],env)
        run(['wayland-scanner','private-code',str(protocol),str(base/'pointer-protocol.c')],env)
        flags=run(['pkg-config','--cflags','--libs','wayland-client'],env).stdout.split()
        run(['cc','-I'+str(base),str(ROOT/'tests/native/pointer.c'),str(base/'pointer-protocol.c'),'-o',str(base/'pointer'),*flags],env)
        pointer=subprocess.Popen([str(base/'pointer')],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,start_new_session=True)
        processes.append(pointer);assert pointer.stdout.readline().strip()=='ready'
        def pointer_command(value):
            pointer.stdin.write(value+'\n');pointer.stdin.flush();assert pointer.stdout.readline().strip()=='ok'
        def click(x,y,button='button'):
            pointer_command(f'move {x} {y}');time.sleep(.05)
            pointer_command(button+' 1');time.sleep(.025);pointer_command(button+' 0')
        def shot(name, output='HEADLESS-1'): run(['grim', '-o', output, str(OUT/(name+'.png'))], env)
        def pixels(name):
            # Headless outputs are fixed at 1920x1080 physical pixels at every scale.
            raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(OUT/(name+'.png')),'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','-'],env=env)
            assert len(raw)==1920*1080*3
            def pixel(x,y):
                offset=3*(round(y)*1920+round(x))
                return tuple(raw[offset:offset+3])
            return pixel
        def audio_checks():
            # Audio UI actions against a deterministic, replaceable graph.
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            audio_fixture=spawn([QS,'-p',str(source/'audio.qml')],env,'audio-fixture')
            def audio_call(method,*args): return ipc(source/'audio.qml','audio-test',method,*args)
            def audio_state(): return json.loads(audio_call('state'))
            eventually(lambda: audio_state()['ready'] and len(audio_state()['applications'])==3)
            command('[title="Island audio fixture"]','fullscreen','enable')
            time.sleep(.2);shot('audio-layout')
            click(760,242);eventually(lambda: audio_state()['output']=='bluez_output.headphones')
            click(1120,242);eventually(lambda: audio_state()['input']=='bluez_input.headphones')
            click(750,158)
            eventually(lambda: .3<audio_state()['outputs'][1]['volume']<.6)
            point=json.loads(audio_call('geometry','audioInputMute'))
            click(round(point['x']+point['width']/2),round(point['y']+point['height']/2));eventually(lambda: audio_state()['inputs'][1]['muted'])
            point=json.loads(audio_call('geometry','audioAppMute-Firefox'))
            click(round(point['x']+point['width']/2),round(point['y']+point['height']/2));eventually(lambda: audio_state()['applications'][0]['muted'])
            audio_call('volume','app',0,.37)
            eventually(lambda: abs(audio_state()['applications'][0]['volume']-.37)<.01)
            for scale in [1,1.25,1.6]:
                command('output','HEADLESS-1','scale',str(scale));time.sleep(.2)
                shot(f'{round(scale*100)}-audio-controls')
            audio_call('remove','output');eventually(lambda: audio_state()['output']!='bluez_output.headphones')
            audio_call('remove','input');eventually(lambda: audio_state()['input']!='bluez_input.headphones')
            audio_call('remove','app');eventually(lambda: audio_state()['applications']==[])
            time.sleep(.1);shot('audio-empty-apps')
            audio_fixture.terminate();audio_fixture.wait(timeout=5)
            # Exercise the actual Quickshell/PipeWire setters, not a command adapter.
            audio_fixture=spawn([QS,'-p',str(source/'audio.qml')],dict(env,ISLAND_AUDIO_NATIVE='1'),'audio-native')
            eventually(lambda: len(audio_state()['outputs'])==2 and len(audio_state()['inputs'])==2 and all(n['ready'] for n in audio_state()['outputs']+audio_state()['inputs']))
            audio_call('select','output',0);audio_call('select','input',0)
            eventually(lambda: audio_state()['output']=='test_output_a' and audio_state()['input']=='test_input_a')
            playback=spawn(['pw-cat','--playback','--raw','--rate','48000','--channels','2','--format','f32','--properties','{ application.name = "Island Test Player" }','/dev/zero'],env,'audio-playback')
            eventually(lambda: len(audio_state()['applications'])==1)
            audio_call('select','output',1);audio_call('select','input',1)
            eventually(lambda: audio_state()['output']=='test_output_b' and audio_state()['input']=='test_input_b')
            def playback_uses_selected_output():
                graph=json.loads(run(['pw-dump'],env).stdout)
                players={o['id'] for o in graph if o['type']=='PipeWire:Interface:Node' and o.get('info',{}).get('props',{}).get('application.name')=='Island Test Player'}
                target=audio_state()['outputs'][1]['id']
                return any(o['type']=='PipeWire:Interface:Link' and o['info']['output-node-id'] in players and o['info']['input-node-id']==target and o['info']['state']=='active' for o in graph)
            eventually(playback_uses_selected_output)
            time.sleep(.4)  # Default-device baseline intentionally suppresses initial OSD events.
            audio_call('volume','output',1,.42);audio_call('volume','input',1,.63)
            eventually(lambda: abs(audio_state()['outputs'][1]['volume']-.42)<.02 and abs(audio_state()['inputs'][1]['volume']-.63)<.02)
            audio_call('mute','input',1);eventually(lambda: audio_state()['inputs'][1]['muted'])
            audio_call('volume','app',0,.35);eventually(lambda: abs(audio_state()['applications'][0]['volume']-.35)<.02)
            audio_call('mute','app',0);eventually(lambda: audio_state()['applications'][0]['muted'])
            eventually(lambda: audio_state()['changes']>0)
            removed_id=audio_state()['outputs'][1]['id']
            run(['pw-cli','destroy',str(removed_id)],env)
            eventually(lambda: len(audio_state()['outputs'])==1 and audio_state()['output']=='test_output_a')
            playback.terminate();playback.wait(timeout=5)
            eventually(lambda: audio_state()['applications']==[])
            audio_fixture.terminate();audio_fixture.wait(timeout=5)
            command('output','HEADLESS-1','scale','1');time.sleep(.2)

        def network_checks():
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            fixture=spawn([QS,'-p',str(source/'network.qml')],env,'network-fixture')
            def call(method,*args): return ipc(source/'network.qml','network-test',method,*args)
            def state(): return json.loads(call('state'))
            def press(name):
                p=json.loads(call('geometry',name));assert p,name
                click(round(p['x']+p['width']/2),round(p['y']+p['height']/2))
            eventually(lambda: state()['available'] and len(state()['connected'])==2)
            command('[title="Island network fixture"]','fullscreen','enable');time.sleep(.2)
            press('networkWired-enp5s0');eventually(lambda: state()['connected']==['wlan0'])
            press('networkWired-enp5s0');eventually(lambda: len(state()['connected'])==2)
            press('networkWifi-Studio');eventually(lambda: state()['prompt']=='Studio')
            # Real password field + Enter dispatch; a rejected password permits retry.
            run(['wtype','-s','150','-d','10','wrong-password','-k','Return'],env)
            eventually(lambda: state()['prompt']=='Studio' and state()['error'])
            shot('network-password-retry')
            press('networkPassword')
            run(['wtype','-s','150','-d','10','island-demo','-k','Return'],env)

            eventually(lambda: any(n['name']=='Studio' and n['connected'] for n in state()['networks']))
            assert state()['prompt'] is None and not state()['busy']
            press('networkWifi-Guest Wi-Fi');eventually(lambda: any(n['name']=='Guest Wi-Fi' and n['connected'] for n in state()['networks']))
            press('networkWifi-Campus');eventually(lambda: 'certificates' in state()['error'])
            press('networkVpn-Work tunnel');eventually(lambda: state()['vpns'][0]['active'])
            press('networkVpn-Work tunnel');eventually(lambda: not state()['vpns'][0]['active'])
            press('networkWifiToggle');eventually(lambda: not state()['wifi'] and not state()['scan'])
            press('networkWifiToggle');eventually(lambda: state()['wifi'] and state()['scan'])
            press('networkWifi-FRITZ!Box 7583 LM');eventually(lambda: len(state()['connected'])==2)
            for scale in [1,1.25,1.6]:
                command('output','HEADLESS-1','scale',str(scale));time.sleep(.25)
                shot(f'{round(scale*100)}-network-controls')
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            press('networkWifi-Studio') # saved profile connects without asking again
            eventually(lambda: any(n['name']=='Studio' and n['connected'] for n in state()['networks']))
            call('scenario','unplug');eventually(lambda: 'enp5s0' not in state()['connected'])
            call('scenario','remove-wifi');eventually(lambda: not state()['networks'] and state()['prompt'] is None)
            shot('network-no-wifi')
            call('scenario','remove-all');eventually(lambda: not state()['connected'])
            call('scenario','unavailable');eventually(lambda: not state()['available'])
            shot('network-unavailable')
            call('scenario','native');eventually(lambda: not state()['available'])
            # Native plugin sees only the private DBus system bus; never host devices.
            time.sleep(.3)
            fixture.terminate();fixture.wait(timeout=5)
            data=(OUT/'network-fixture.log').read_text()
            assert not any(t in data for t in ['Binding loop','ReferenceError','TypeError','Unable to assign','Failed to load configuration']),data
        def bluetooth_checks():
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            state_file=base/'bluez.json'
            bluez=spawn([sys.executable,str(ROOT/'tests/native/bluez.py'),str(state_file)],env,'bluez-fixture')
            def bluez_state():return json.loads(state_file.read_text())
            eventually(lambda: bluez_state()['ready'])
            fixture=spawn([QS,'-p',str(source/'bluetooth.qml')],dict(env,ISLAND_BLUETOOTH_NATIVE='1'),'bluetooth-fixture')
            def call(method,*args):return ipc(source/'bluetooth.qml','bluetooth-test',method,*args)
            def state():return json.loads(call('state'))
            def device(suffix):return next(d for d in state()['devices'] if d['address'].endswith(suffix))
            def press(name):
                p=json.loads(call('geometry',name));assert p,name
                click(round(p['x']+p['width']/2),round(p['y']+p['height']/2))
            def action(suffix):
                call('reveal',suffix);time.sleep(.1);press('bluetoothAction-10:20:30:40:50:'+suffix)
            def select(suffix):
                call('reveal',suffix);time.sleep(.1);press('bluetoothSelect-10:20:30:40:50:'+suffix)
            eventually(lambda: state()['ready'] and len(state()['devices'])==8)
            command('[title="Island Bluetooth fixture"]','fullscreen','enable');time.sleep(.3)
            assert device('60')['battery']=='84%'
            action('60');eventually(lambda:not device('60')['connected'] and not state()['busy'])
            action('60');eventually(lambda:device('60')['connected'] and not state()['busy'])
            press('bluetoothScan');eventually(lambda:state()['scanning'] and not state()['busy'])
            press('bluetoothScan');eventually(lambda:not state()['scanning'] and not state()['busy'])
            press('bluetoothVisible');eventually(lambda:state()['visible'] and not state()['busy'])
            press('bluetoothVisible');eventually(lambda:not state()['visible'] and not state()['busy'])
            action('62');eventually(lambda:state()['prompt'] and state()['prompt']['kind']=='confirm')
            assert state()['prompt']['code']=='042816'
            shot('bluetooth-pair-confirm')
            press('bluetoothPairCancel');eventually(lambda:not state()['busy'] and state()['prompt'] is None)
            assert not device('62')['paired']
            action('62');eventually(lambda:state()['prompt'] is not None)
            press('bluetoothPairConfirm');eventually(lambda:device('62')['paired'] and device('62')['connected'] and not state()['busy'])
            assert not device('62')['trusted'], 'Pairing must not silently grant persistent trust'
            press('bluetoothTrust');eventually(lambda:device('62')['trusted'] and not state()['busy'])
            press('bluetoothForget');assert device('62')['paired']
            press('bluetoothForget');eventually(lambda:len(state()['devices'])==7 and not state()['busy'])
            action('63');eventually(lambda:state()['prompt'] and state()['prompt']['kind']=='pin')
            press('bluetoothPin')
            run(['wtype','-s','150','9999','-k','Return'],env)
            time.sleep(.15);shot('bluetooth-pin-attempt')
            eventually(lambda:not state()['busy'] and state()['error'])
            assert not device('63')['paired']
            action('63');eventually(lambda:state()['prompt'] and state()['prompt']['kind']=='pin')
            press('bluetoothPin')
            run(['wtype','-s','150','1234','-k','Return'],env)
            eventually(lambda:device('63')['paired'] and not state()['busy'])
            action('64');eventually(lambda:state()['prompt'] and state()['prompt']['kind']=='passkey')
            press('bluetoothPin')
            run(['wtype','-s','150','042816','-k','Return'],env)
            eventually(lambda:device('64')['paired'] and not state()['busy'])
            action('65');eventually(lambda:state()['prompt'] and state()['prompt']['kind']=='display')
            shot('bluetooth-keyboard-code')
            eventually(lambda:device('65')['paired'] and not state()['busy'])
            action('66');eventually(lambda:not state()['busy'] and 'Connection failed' in state()['error'])
            assert not device('66')['connected']
            # Pending authorization is canceled when the ordinary panel closes.
            action('67');eventually(lambda:state()['prompt'] and state()['prompt']['kind']=='authorize')
            before=bluez_state()['cancels'];call('scenario','close')
            eventually(lambda:not state()['ready'] and not state()['busy'])
            eventually(lambda:bluez_state()['cancels']>before)
            assert not device('67')['paired']
            call('scenario','open');eventually(lambda:state()['ready'])
            press('bluetoothPower');eventually(lambda:not state()['powered'] and not state()['busy'])
            press('bluetoothPower');eventually(lambda:state()['powered'] and not state()['busy'])
            action('60');eventually(lambda:device('60')['connected'] and not state()['busy'])
            select('60')
            for scale in [1,1.25,1.6]:
                command('output','HEADLESS-1','scale',str(scale));time.sleep(.25)
                shot(f'{round(scale*100)}-bluetooth-controls')
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            press('bluetoothScan');eventually(lambda:state()['scanning'] and not state()['busy'])
            stops=bluez_state()['scanStops'];call('scenario','close')
            eventually(lambda:bluez_state()['scanStops']>stops)
            eventually(lambda:bluez_state()['agents']==0)
            assert bluez_state()['defaultAgentCalls']==0
            assert bluez_state()['pin'] and bluez_state()['passkey']
            run(['gdbus','call','--system','--dest','org.bluez','--object-path','/org/island/test','--method','org.island.BluetoothTest.RemoveAdapter'],env)
            eventually(lambda:state()['adapters']==0)
            shot('bluetooth-no-adapter')
            fixture.terminate();fixture.wait(timeout=5);bluez.terminate();bluez.wait(timeout=5)
            data=(OUT/'bluetooth-fixture.log').read_text()
            assert not any(t in data for t in ['Binding loop','ReferenceError','TypeError','Unable to assign','Failed to load configuration']),data
        def weather_checks():
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            scenario=base/'weather-scenario';scenario.write_text('online')
            requests=base/'weather-requests'
            fixture=spawn([QS,'-p',str(source/'weather.qml')],dict(env,ISLAND_WEATHER_FIXTURE=str(ROOT/'tests/native/weather.py'),ISLAND_WEATHER_SCENARIO=str(scenario),ISLAND_WEATHER_REQUESTS=str(requests)),'weather-fixture')
            def call(method,*args):return ipc(source/'weather.qml','weather-test',method,*args)
            def state():return json.loads(call('state'))
            def press(name,scale=1):
                p=json.loads(call('geometry',name));assert p and p['visible'] and p['enabled'],p
                click(round((p['x']+p['width']/2)*scale),round((p['y']+p['height']/2)*scale))
            eventually(lambda:state()['loaded'] and not state()['loading'])
            command('[title="Island weather fixture"]','fullscreen','enable');time.sleep(.2)
            for scale in [1,1.25,1.6]:
                command('output','HEADLESS-1','scale',str(scale));time.sleep(.2)
                press('weatherDaily',scale);eventually(lambda:not state()['hourly']);time.sleep(.15)
                shot(f'{round(scale*100)}-weather-daily')
                press('weatherHourly',scale);eventually(lambda:state()['hourly']);time.sleep(.15)
                shot(f'{round(scale*100)}-weather-hourly')
                press('weatherLocation',scale);eventually(lambda:state()['choosing'])
                press('weatherCityInput',scale)
                run(['wtype','-s','150','Graz'],env)
                eventually(lambda:len(state()['results'])==1)
                shot(f'{round(scale*100)}-weather-city')
                press('weatherCity-0',scale)
                eventually(lambda:state()['city']=='Graz' and state()['loaded'] and not state()['choosing'] and not state()['loading'])
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            call('query','slow');eventually(lambda:requests.exists() and 'slow' in requests.read_text())
            call('query','Salzburg');eventually(lambda:state()['searched'] and state()['results'][0]['name']=='Salzburg')
            call('query','none');eventually(lambda:state()['searched'] and not state()['results'])
            call('query','');call('choose','Vienna');call('choose','Graz')
            eventually(lambda:state()['city']=='Graz' and state()['loaded'] and not state()['loading'])
            scenario.write_text('offline');press('weatherRefresh')
            eventually(lambda:bool(state()['error']) and not state()['loading'])
            assert state()['loaded'] and state()['stale']
            shot('weather-offline-cached')
            call('choose','Salzburg');eventually(lambda:not state()['loading'] and bool(state()['error']))
            assert not state()['loaded']
            shot('weather-offline-empty')
            before=requests.read_text();call('demo','true');eventually(lambda:state()['demo'] and state()['loaded'])
            assert not json.loads(call('geometry','weatherRefresh'))['enabled']
            time.sleep(.4);assert requests.read_text()==before
            shot('weather-demo')
            fixture.terminate();fixture.wait(timeout=5)
            data=(OUT/'weather-fixture.log').read_text()
            assert not any(t in data for t in ['Binding loop','ReferenceError','TypeError','Unable to assign','Failed to load configuration']),data
        def power_checks():
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            state_file=base/'power-profiles.json'
            provider=spawn([sys.executable,str(ROOT/'tests/native/power_profiles.py'),str(state_file)],env,'power-provider')
            def provider_state():return json.loads(state_file.read_text())
            eventually(lambda:provider_state()['ready'])
            fixture=spawn([QS,'-p',str(source/'power.qml')],env,'power-fixture')
            def call(method,*args):return ipc(source/'power.qml','power-test',method,*args)
            def state():return json.loads(call('state'))
            def control(method,value):return run(['gdbus','call','--system','--dest','org.island.PowerTestFixture','--object-path','/org/island/test','--method','org.island.PowerTest.'+method,value],env)
            def press(profile,scale=1):
                p=json.loads(call('geometry','powerProfile-'+profile));assert p and p['visible'] and p['enabled'],p
                click(round((p['x']+p['width']/2)*scale),round((p['y']+p['height']/2)*scale))
            eventually(lambda:state()['status']['available'])
            assert state()['status']['profile']=='balanced'
            command('[title="Island power fixture"]','fullscreen','enable');time.sleep(.2)
            for scale,profile in [(1,'power-saver'),(1.25,'balanced'),(1.6,'performance')]:
                command('output','HEADLESS-1','scale',str(scale));time.sleep(.2)
                press(profile,scale)
                eventually(lambda:not state()['busy'] and state()['status']['profile']==profile)
                shot(f'{round(scale*100)}-power-profiles')
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            control('Scenario','two')
            eventually(lambda:state()['status']['profiles']==['power-saver','balanced'])
            assert not json.loads(call('geometry','powerProfile-performance'))['visible']
            before=len(provider_state()['writes']);call('choose','performance');time.sleep(.1)
            assert len(provider_state()['writes'])==before
            control('Scenario','all');control('Scenario','inhibited')
            eventually(lambda:state()['status']['inhibited']=='lap-detected')
            assert not json.loads(call('geometry','powerProfile-performance'))['enabled']
            shot('power-performance-inhibited')
            control('Scenario','all');control('Scenario','degraded')
            eventually(lambda:'too hot' in state()['notice'])
            press('performance');eventually(lambda:state()['status']['profile']=='performance' and not state()['busy'])
            control('Scenario','all');control('Scenario','hold')
            eventually(lambda:len(state()['status']['holds'])==1)
            assert 'overrides' in state()['notice']
            press('balanced');eventually(lambda:state()['status']['profile']=='balanced' and not state()['busy'] and not state()['status']['holds'])
            control('Scenario','denied');press('power-saver')
            eventually(lambda:not state()['busy'] and 'denied' in state()['error'])
            assert state()['status']['profile']=='balanced'
            shot('power-permission-denied')
            control('Scenario','all');control('Scenario','external')
            eventually(lambda:state()['status']['profile']=='power-saver')
            # The same adapter follows a legacy provider and a service restart.
            control('Names','legacy')
            eventually(lambda:state()['status'].get('provider')=='net.hadess.PowerProfiles')
            press('performance');eventually(lambda:state()['status']['profile']=='performance' and not state()['busy'])
            assert provider_state()['writes'][-1]['provider']=='net.hadess.PowerProfiles'
            control('Names','none');eventually(lambda:not state()['status']['available'])
            shot('power-provider-missing')
            control('Names','both');eventually(lambda:state()['status']['available'] and state()['status'].get('provider')=='org.freedesktop.UPower.PowerProfiles')
            fixture.terminate();fixture.wait(timeout=5);provider.terminate();provider.wait(timeout=5)
            data=(OUT/'power-fixture.log').read_text()
            assert not any(t in data for t in ['Binding loop','ReferenceError','TypeError','Unable to assign','Failed to load configuration']),data
        def tray_checks():
            # Real StatusNotifierItem / DBusMenu integration on the private bus.
            tray_state_path=base/'tray-state.json'
            tray=spawn([sys.executable,str(ROOT/'tests/native/tray.py'),str(tray_state_path)],env,'tray')
            def tray_state(): return json.loads(tray_state_path.read_text())
            def tray_control(method,*args):
                return run(['gdbus','call','--session','--dest','org.island.TrayFixture','--object-path','/Control','--method','org.island.TrayFixture.'+method,*args],env)
            def tray_geometry(): return json.loads(shell('trayGeometry'))
            def item_rect(identity='island-fixture'):
                return next(item for item in tray_geometry()['items'] if item['id']==identity)
            def rect_point(rect): return round(rect['x']+rect['width']/2),round(rect['y']+rect['height']/2)
            def item_click(button='button',identity='island-fixture'): click(*rect_point(item_rect(identity)),button)
            def menu_row(label):
                def find(rows):
                    for row in rows:
                        if row['text']==label: return row
                        child=find(row['children'])
                        if child: return child
                return find(tray_geometry()['menu'])
            def menu_click(label): click(*rect_point(eventually(lambda:menu_row(label))))
            def open_tray():
                if not status()['trayOpen']:
                    time.sleep(.17)
                    bar_click('tray');eventually(lambda:status()['trayOpen'])
                    time.sleep(.15)
            eventually(lambda: tray_state()['ready'] and status()['trayCount']==1)
            time.sleep(.2);shot('tray-collapsed')
            assert not status()['trayOpen'] and tray_state()['activate']==0
            open_tray();shot('tray-grid-one')
            assert pixels('tray-grid-one')(*rect_point(item_rect()))[1]>150, 'Icons must appear inside the dropdown'
            item_click();eventually(lambda: tray_state()['activate']==1)
            item_click('middle');eventually(lambda: tray_state()['secondary']==1)
            pointer_command('axis 10');eventually(lambda: len(tray_state()['scroll'])>0)
            item_click('right');eventually(lambda: tray_state()['menuOpens']>0)
            time.sleep(.2);shot('tray-menu')
            menu_click('Open application');eventually(lambda: tray_state()['menuClicks']==1)
            # Register the virtual keyboard before Qt takes the popup grab.
            menu_keyboard=spawn(['wtype','-s','500','-k','Down','-k','Down','-k','Return'],env,'tray-keyboard')
            time.sleep(.1);open_tray();item_click('right');menu_keyboard.wait(timeout=3)
            eventually(lambda: tray_state()['menuClicks']>1)
            assert tray_state()['clickedIds']==[1,3], tray_state()
            open_tray();item_click('right');time.sleep(.15)
            shot('tray-menu-unchecked')
            menu_click('Unavailable action');time.sleep(.1)
            shot('tray-menu-disabled')
            assert tray_state()['clickedIds']==[1,3], 'Disabled menu actions must not dispatch'
            pointer_command('move %s %s' % rect_point(menu_row('More options')));time.sleep(.6);shot('tray-submenu')
            menu_click('Nested action')
            eventually(lambda: tray_state()['clickedIds']==[1,3,7])
            open_tray();item_click('right');time.sleep(.15)
            run(['wtype','-s','100','-k','Escape'],env);time.sleep(.1);shot('tray-menu-escape')
            assert not tray_geometry()['menu'], 'Escape must close the app menu'
            if status()['trayOpen']:
                run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda:not status()['trayOpen'])
            open_tray();bar_click('tray');eventually(lambda:not status()['trayOpen'])
            open_tray();click(1600,300);eventually(lambda:not status()['trayOpen'])
            open_tray();item_click('right');time.sleep(.15)
            click(1600,300);time.sleep(.1);shot('tray-menu-outside')
            assert not tray_geometry()['menu'], 'Outside clicks must close the app menu'
            # A second outside click closes any remaining grid after its child menu.
            if status()['trayOpen']: click(1600,300)
            eventually(lambda:not status()['trayOpen'])
            tray_control('AddMenuOnly');eventually(lambda: status()['trayCount']==2)
            open_tray();opens=tray_state()['menuOpens']
            item_click(identity='island-menu-only');eventually(lambda: tray_state()['menuOpens']>opens)
            assert tray_state()['activate']==1, 'Menu-only items must open their menu instead of activating'
            run(['wtype','-s','100','-k','Escape'],env)
            if status()['trayOpen']: run(['wtype','-s','100','-k','Escape'],env)
            tray_control('SetStatus','Passive');eventually(lambda: status()['trayCount']==1)
            tray_control('SetStatus','NeedsAttention');eventually(lambda: status()['trayCount']==2)
            shot('tray-attention-collapsed')
            tray_rect=status()['barLayout']['tray']
            assert max(pixels('tray-attention-collapsed')(round(tray_rect['x']+tray_rect['width']-4),6))>100, 'Collapsed tray must indicate attention'
            open_tray();shot('tray-attention')
            attention=item_rect()
            assert attention['attention']
            assert max(pixels('tray-attention')(round(attention['x']+attention['width']-4),round(attention['y']+attention['height']-3)))>100
            pointer_command('move %s %s' % rect_point(item_rect()));time.sleep(.85);shot('tray-tooltip')
            # Real item additions reflow the grid. Keyboard activation and menus
            # still work when icons are spread over multiple rows.
            tray_control('AddItems','10');eventually(lambda:status()['trayCount']==12)
            time.sleep(.2);shot('tray-grid-many')
            item_click()
            eventually(lambda:tray_state()['activate']==2)
            run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda:not status()['trayOpen'])
            opens=tray_state()['menuOpens']
            # As above, register the virtual keyboard before taking a popup grab.
            grid_keyboard=spawn(['wtype','-s','800','-k','Right','-k','Menu','-s','300'],env,'tray-grid-keyboard')
            time.sleep(.1);open_tray();grid_keyboard.wait(timeout=3);shot('tray-keyboard-result')
            eventually(lambda:tray_state()['menuOpens']>opens)
            run(['wtype','-s','100','-k','Escape'],env)
            if status()['trayOpen']: run(['wtype','-s','100','-k','Escape'],env)
            for scale in [1,1.25,1.6]:
                command('output','HEADLESS-1','scale',str(scale));time.sleep(.2)
                bar_click('tray',scale);eventually(lambda:status()['trayOpen'])
                time.sleep(.15);shot(f'tray-grid-{round(scale*100)}')
                run(['wtype','-s','100','-k','Escape'],env);eventually(lambda:not status()['trayOpen'])
            command('output','HEADLESS-1','scale','1');time.sleep(.2)
            open_tray()
            tray.terminate();tray.wait(timeout=5)
            eventually(lambda: status()['trayCount']==0 and not status()['trayOpen'])
            shot('tray-empty')
            for log in ['shell.log','shell-after-system.log']:
                if not (OUT/log).exists(): continue
                data=(OUT/log).read_text()
                assert not any(term in data for term in ['Binding loop','ReferenceError','TypeError','Unable to assign','Failed to load configuration']), data
        if os.environ.get('ISLAND_TEST_TRAY_ONLY'):
            preview=spawn([str(ROOT/'bin/island'),'run','--preview','--showcase'],env,'shell')
            eventually(lambda:status()['mode']=='compact')
            tray_checks()
            print('Grouped tray: activation, menus, keyboard, dismissal, attention, reflow, removal and 100/125/160% scaling passed',flush=True)
            return
        def clock_checks():
            # Exercise the production bar with both desktop palette variants.
            # A Controls.Label import used to shadow ui/Label.qml, making the
            # clock black on black with a light desktop palette.
            fixture=spawn([QS,'-p',str(source/'bar-clock.qml')],env,'bar-clock')
            def call(method,*args): return ipc(source/'bar-clock.qml','bar-clock-test',method,*args)
            def state(): return json.loads(call('status'))
            eventually(lambda:state()['ready'])
            for scale in [1,1.25,1.6]:
                command('output','HEADLESS-1','scale',str(scale));time.sleep(.2)
                for light in [True,False]:
                    call('palette',str(light).lower());time.sleep(.1)
                    current=state()
                    name=f'{round(scale*100)}-clock-{"light" if light else "dark"}'
                    shot(name)
                    assert current['color']==current['expectedColor'], current
                    assert current['family']==current['expectedFamily'], current
                    assert current['weight']==current['axis']==600, current
                    pixel=pixels(name)
                    bright=sum(max(pixel(x,y))>150 for x in range(round(960-30*scale),round(960+30*scale)) for y in range(round(4*scale),round(24*scale)))
                    assert bright>30*scale*scale, (name,'Clock glyphs must be visible on the black bar')
                call('minute',35);eventually(lambda:state()['text']=='12:35')
                call('shown','false');assert state()['offset']==-28
                call('shown','true');assert state()['offset']==0
                call('minute',34);eventually(lambda:state()['text']=='12:34')
            fixture.terminate();fixture.wait(timeout=5)
            command('output','HEADLESS-1','scale','1')
            data=(OUT/'bar-clock.log').read_text()
            assert not any(t in data for t in ['Binding loop','ReferenceError','TypeError','Unable to assign','Failed to load configuration']),data
        if os.environ.get('ISLAND_TEST_CLOCK_ONLY'):
            clock_checks()
            print('Bar clock: light/dark palettes, visible glyphs, minute updates and fullscreen restoration at 100/125/160% passed',flush=True)
            return
        if os.environ.get('ISLAND_TEST_WEATHER_ONLY'):
            weather_checks()
            print('Weather city search, race handling, cached/offline forecasts and scaled UI checks passed',flush=True)
            return
        if os.environ.get('ISLAND_TEST_POWER_ONLY'):
            power_checks()
            print('Power-profile selection, errors, provider changes and scaled UI checks passed',flush=True)
            return
        if os.environ.get('ISLAND_TEST_BLUETOOTH_ONLY'):
            bluetooth_checks()
            print('Native Bluetooth actions, application agent pairing and scaled UI checks passed',flush=True)
            return
        if os.environ.get('ISLAND_TEST_NETWORK_ONLY'):
            network_checks()
            print('Network interaction, password retry, hotplug and scaled UI checks passed',flush=True)
            return
        if os.environ.get('ISLAND_TEST_AUDIO_ONLY'):
            audio_checks()
            for name in ['audio-fixture','audio-native']:
                data=(OUT/(name+'.log')).read_text()
                assert not any(t in data for t in ['Binding loop','ReferenceError','TypeError','Unable to assign','Failed to load configuration']), data
            print('Audio controls and private PipeWire tests passed',flush=True)
            return
        clock_checks()
        preview = spawn([str(ROOT/'bin/island'), 'run', '--preview', '--showcase'], env, 'shell')
        eventually(lambda: status()['mode'] == 'compact')
        time.sleep(.5)
        # Focus-grab requests depend on panel/auth state, not an inherited
        # Hyprland IPC identity. This lab has no signature or Hyprland protocol;
        # compositor-confirmed arming remains separately observable in status.
        assert not status()['outsideClickRequested']
        for panel in ['calendar', 'media', 'system', 'audio', 'network', 'bluetooth', 'weather', 'launcher', 'notifications', 'session']:
            shell('demo',panel)
            eventually(lambda:status()['mode']==panel and status()['outsideClickRequested'])
            shell('demo','compact')
        shell('demo','calendar');shell('demo','auth')
        eventually(lambda:status()['mode']=='auth' and not status()['outsideClickRequested'])
        shell('demo','compact')
        # Simultaneous shape changes are bounded and stop driving frames when settled.
        timings=[]
        for mode in ['launcher', 'hover', 'session', 'auth', 'compact']:
            if mode == 'hover': shell('demo','compact')
            start=time.monotonic(); shell('demo',mode)
            eventually(lambda: not status()['animating'], 1)
            timings.append({'state':mode,'ipcRoundTripMs':round((time.monotonic()-start)*1000),'springMs':status()['settlingMs']})
        keyboard=spawn(['wtype','-s','700','-d','20','fire','-s','1000','-k','Escape','-s','1000','-k','Escape','-s','1000'],env,'keyboard')
        time.sleep(.6);shell('toggle','launcher')
        eventually(lambda: status()['query'] == 'fire')
        print('Typing during expansion:',status(),flush=True)
        assert status()['launcherFocused']
        eventually(lambda: status()['mode'] == 'compact')
        shell('toggle','launcher'); shell('demo','auth')
        eventually(lambda: status()['mode'] == 'launcher')
        assert status()['query'] == 'fire', 'Authentication must preserve search'
        keyboard.wait(timeout=4)
        shell('demo','compact')
        # Clock opens the complete calendar at every output scale. Media remains
        # separately testable through its preview command.
        for media_scale in [1,1.25,1.6]:
            command('output','HEADLESS-1','scale',str(media_scale));time.sleep(.25)
            layout=status()['barLayout']
            left=[key for key in ['cpu','memory','gpu','disk','battery'] if key in layout]
            assert sorted(left,key=lambda key:layout[key]['x'])==left
            assert layout['disk']['value'] is not None
            right=['weather','bluetooth','network','notifications','audio','power']
            assert sorted(right,key=lambda key:layout[key]['x'])==right
            assert all(layout[b]['x']-layout[a]['x']==30 for a,b in zip(right,right[1:]))
            assert layout[left[-1]]['x']+layout[left[-1]]['width'] < (1920/media_scale-96)/2
            clock_y=round(10*media_scale)
            pointer_command(f'move 960 {clock_y}');time.sleep(.3)
            assert status()['mode']=='compact', 'Hovering the clock must not open a panel'
            click(960,clock_y);eventually(lambda: status()['mode']=='calendar' and not status()['animating'])
            assert status()['calendar']['selected']==status()['calendar']['date']
            before=status()['calendar']['time']
            eventually(lambda: status()['calendar']['time'] != before,2)
            assert re.fullmatch(r'\d{2}:\d{2}:\d{2}',status()['calendar']['time'])
            shot(f'{round(media_scale*100)}-calendar')
            # Month navigation controls retain their natural logical geometry.
            click(round(960+290*media_scale),round(130*media_scale))
            eventually(lambda: status()['calendar']['month'] != status()['calendar']['date'][:7])
            click(round(960+240*media_scale),round(66*media_scale))
            eventually(lambda: status()['calendar']['month']==status()['calendar']['date'][:7])
            run(['wtype','-s','100','-k','Right'],env)
            eventually(lambda: status()['calendar']['selected'] != status()['calendar']['date'])
            shell('demo','auth');run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda: status()['mode']=='calendar')
            pointer_command('move 100 500');time.sleep(.2)
            assert status()['mode']=='calendar'
            click(960,clock_y);eventually(lambda: status()['mode']=='compact')
            assert not status()['calendar']['ticking']
            frozen=status()['calendar']['time'];time.sleep(1.1)
            assert status()['calendar']['time']==frozen
            click(960,clock_y);eventually(lambda: status()['mode']=='calendar')
            run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda: status()['mode']=='compact')
            shell('demo','media');eventually(lambda: status()['mode']=='media' and not status()['animating'])
            playing=status()['mediaPlaying']
            click(round(960-167*media_scale),round(145*media_scale))
            eventually(lambda: status()['mediaPlaying'] != playing)
            pointer_command('move 100 500');time.sleep(.2)
            assert status()['mode']=='media'
            shell('dismiss');eventually(lambda: status()['mode']=='compact')
            eventually(lambda: status()['system']['revision']>=2)
            pointer_command('move %s %s' % bar_point('cpu',media_scale));time.sleep(.2)
            assert status()['mode']=='compact', 'System readings must be click-only'
            pointer_command('move %s %s' % bar_point('cpu',media_scale))
            pointer_command('button 1')
            revision=status()['system']['revision']
            eventually(lambda: status()['system']['revision']>revision)
            pointer_command('button 0')
            eventually(lambda: status()['mode']=='system' and not status()['animating'])
            shot(f'{round(media_scale*100)}-system')
            revision=status()['system']['revision']
            eventually(lambda: status()['system']['revision']>revision)
            assert status()['system']['historyLength']<=31
            bar_click('memory',media_scale)
            eventually(lambda: status()['mode']=='compact')
            if status()['system']['gpu'] and status()['system']['gpu']['usage'] is not None:
                bar_click('gpu',media_scale)
                eventually(lambda: status()['mode']=='system')
                bar_click('gpu',media_scale)
                eventually(lambda: status()['mode']=='compact')
            bar_click('cpu',media_scale)
            eventually(lambda: status()['mode']=='system')
            shell('demo','auth');eventually(lambda: status()['mode']=='auth')
            run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda: status()['mode']=='system')
            run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda: status()['mode']=='compact')
            shell('demo','system')
            eventually(lambda:status()['mode']=='system' and status()['powerProfiles']['demo'] and not status()['animating'])
            assert status()['powerProfiles']['profiles']==['power-saver','balanced','performance']
            click(round(960+230*media_scale),round(148*media_scale))
            eventually(lambda:status()['powerProfiles']['profile']=='performance')
            shot(f'{round(media_scale*100)}-system-power-profiles')
            shell('demo','auth');run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda:status()['mode']=='system' and status()['powerProfiles']['demo'])
            assert status()['powerProfiles']['profile']=='performance'
            run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda:status()['mode']=='compact' and not status()['powerProfiles']['demo'])
        # The production audio notch uses a simulated graph only for demo audio.
            shell('demo','audio')
            eventually(lambda: status()['mode']=='audio' and status()['audio']['demo'] and not status()['animating'])
            assert status()['audio']['outputs']==3 and status()['audio']['inputs']==2
            shot(f'{round(media_scale*100)}-audio')
            shell('demo','auth')
            run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda: status()['mode']=='audio' and status()['audio']['demo'])
            run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda: status()['mode']=='compact' and not status()['audio']['demo'])
            shell('demo','network')
            eventually(lambda: status()['mode']=='network' and status()['network']['demo'] and not status()['animating'])
            assert status()['network']['devices']==2 and status()['network']['connected']==2
            shot(f'{round(media_scale*100)}-network')
            shell('demo','auth');run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda: status()['mode']=='network' and status()['network']['demo'])
            run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda: status()['mode']=='compact' and not status()['network']['demo'])
            bar_click('network',media_scale)
            eventually(lambda: status()['mode']=='network' and not status()['network']['demo'])
            bar_click('network',media_scale);eventually(lambda: status()['mode']=='compact')
            shell('demo','bluetooth')
            eventually(lambda:status()['mode']=='bluetooth' and status()['bluetooth']['demo'] and not status()['animating'])
            assert status()['bluetooth']['adapters']==1 and status()['bluetooth']['devices']==4
            shot(f'{round(media_scale*100)}-bluetooth')
            shell('demo','auth');run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda:status()['mode']=='bluetooth' and status()['bluetooth']['demo'])
            run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda:status()['mode']=='compact' and not status()['bluetooth']['demo'])
            bar_click('bluetooth',media_scale)
            eventually(lambda:status()['mode']=='bluetooth' and not status()['bluetooth']['demo'])
            bar_click('bluetooth',media_scale);eventually(lambda:status()['mode']=='compact')
            bar_click('notifications',media_scale)
            eventually(lambda:status()['mode']=='notifications')
            bar_click('notifications',media_scale)
            eventually(lambda:status()['mode']=='compact')
            shell('demo','weather')
            eventually(lambda:status()['mode']=='weather' and status()['weather']['demo'] and not status()['animating'])
            shot(f'{round(media_scale*100)}-weather-notch')
            frames=status()['animationFrames'];time.sleep(.3)
            assert status()['animationFrames']==frames, 'Weather must stop rendering geometry when settled'
            shell('demo','auth');run(['wtype','-s','100','-k','Escape'],env)
            eventually(lambda:status()['mode']=='weather' and status()['weather']['demo'])
            bar_click('weather',media_scale)
            eventually(lambda:status()['mode']=='compact' and not status()['weather']['demo'])
            bar_click('audio',media_scale)
            eventually(lambda: status()['mode']=='audio' and not status()['audio']['demo'])
            bar_click('audio',media_scale)
            eventually(lambda: status()['mode']=='compact')
            bar_click('power',media_scale)
            eventually(lambda:status()['mode']=='session')
            assert status()['lastAction']=='', 'Opening the session menu must not execute an action'
            bar_click('power',media_scale)
            eventually(lambda:status()['mode']=='compact')
            bar_click('disk',media_scale)
            eventually(lambda:status()['mode']=='system')
            bar_click('disk',media_scale)
            eventually(lambda:status()['mode']=='compact')
        command('output','HEADLESS-1','scale','1');time.sleep(.25)
        # Real presentation and UPower adapter with a replaceable laptop battery.
        preview.terminate();preview.wait(timeout=5)
        system_fixture=spawn([QS,'-p',str(source/'system.qml')],env,'system-fixture')
        def system_call(method,*args): return ipc(source/'system.qml','system-test',method,*args)
        def system_state(): return json.loads(system_call('state'))
        eventually(lambda: system_state()['history']==31)
        command('[title="Island system fixture"]','fullscreen','enable')
        for scale in [1,1.25,1.6]:
            command('output','HEADLESS-1','scale',str(scale));time.sleep(.2)
            shot(f'{round(scale*100)}-system-battery')
            battery_rect=system_state()['barLayout']['battery']
            click(round((battery_rect['x']+battery_rect['width']/2)*scale),round(14*scale))
        eventually(lambda: system_state()['clicks']==3)
        assert system_state()['barLayout']['disk']['value']==62
        assert system_state()['battery']['percentage']==72
        assert system_state()['battery']['health']==94
        system_call('battery','charging')
        eventually(lambda: system_state()['battery']['charging'])
        assert system_state()['battery']['seconds']==2400
        time.sleep(.1);shot('system-battery-charging')
        system_call('battery','peripheral')
        eventually(lambda: system_state()['battery'] is None)
        system_call('battery','none')
        system_call('gpu','false')
        eventually(lambda: system_state()['gpu'] is None)
        time.sleep(.1);shot('system-no-gpu-or-battery')
        system_fixture.terminate();system_fixture.wait(timeout=5)
        audio_checks()
        network_checks()
        weather_checks()
        bluetooth_checks()
        power_checks()
        preview=spawn([str(ROOT/'bin/island'),'run','--preview','--showcase'],env,'shell-after-system')
        eventually(lambda: status()['mode']=='compact')
        tray_checks()
        pointer_command('move 100 500')
        probe=spawn([QS,'-p',str(source/'probe.qml')], env,'input-probe')
        eventually(lambda: ipc(source/'probe.qml','probe','count') == '0')
        def workspace_rect(output):
            return next(w['rect'] for w in json.loads(command('-t','get_workspaces').stdout) if w['output'] == output)
        eventually(lambda: workspace_rect('HEADLESS-1')['y'] == 28)
        eventually(lambda: status()['mode'] == 'compact' and not status()['animating'])
        compact_rect=workspace_rect('HEADLESS-1')
        assert status()['geometry']['width'] == 96 and status()['geometry']['height'] == 0
        assert status()['geometry']['y'] == 28 and status()['geometry']['joinRadius'] == 0
        shell('toggle','launcher');time.sleep(.45)
        assert workspace_rect('HEADLESS-1') == compact_rect, 'Expansion must keep the same 28 px working-area reservation'
        shell('demo','compact');time.sleep(.4)
        shot('gutter-workspace')
        # A fullscreen fixture extends beneath the bar to check its empty input
        # outside the clock, then the notch's concave joins and bottom corners.
        command('[title="Island input probe"]','fullscreen','enable')
        time.sleep(.2); shot('input-probe'); click(100,400); eventually(lambda: ipc(source/'probe.qml','probe','count') == '1')
        click(550,10);eventually(lambda: ipc(source/'probe.qml','probe','count') == '2')
        click(922,2); time.sleep(.1)
        assert ipc(source/'probe.qml','probe','count') == '2', 'Centered clock intercepts clicks without blocking the rest of the bar'
        pointer_command('move 100 400')
        shell('demo','compact');time.sleep(.4)
        click(960,30);eventually(lambda: ipc(source/'probe.qml','probe','count') == '3')
        shell('toggle','session');eventually(lambda: not status()['animating'])
        join_geometry=status()['geometry']
        join_left=960-join_geometry['width']/2
        click(round(join_left-2),30);time.sleep(.1)
        assert ipc(source/'probe.qml','probe','count') == '3', 'Black inverse corner must intercept input'
        click(round(join_left-join_geometry['joinRadius']+2),round(28+join_geometry['joinRadius']-2));eventually(lambda: ipc(source/'probe.qml','probe','count') == '4')
        click(617,176);eventually(lambda: ipc(source/'probe.qml','probe','count') == '5')
        click(960,10); time.sleep(.1)
        assert ipc(source/'probe.qml','probe','count') == '5', 'Island intercepts its own surface'
        shell('locked','true');time.sleep(.2);click(960,10)
        eventually(lambda: ipc(source/'probe.qml','probe','count') == '6')
        shell('locked','false');command('[title="Island input probe"]','fullscreen','disable')
        command('seat','seat0','cursor','set','100','500')
        eventually(lambda: not status()['animating'])
        settled=status()['animationFrames'];time.sleep(.3);assert status()['animationFrames']==settled, 'No spring frames after settling'
        command('create_output');time.sleep(.2)
        command('[title="Island input probe"]','move','container','to','output','HEADLESS-2')
        eventually(lambda: workspace_rect('HEADLESS-2')['y'] == 0)
        command('output','HEADLESS-1','disable');eventually(lambda: status()['screen']=='HEADLESS-2')
        eventually(lambda: workspace_rect('HEADLESS-2')['y'] == 28)
        command('output','HEADLESS-1','enable');eventually(lambda: status()['screen']=='HEADLESS-1' and status()['windowScreen']=='HEADLESS-1' and status()['shown'])
        eventually(lambda: workspace_rect('HEADLESS-2')['y'] == 0)
        command('[title="Island input probe"]','move','container','to','output','HEADLESS-1')
        eventually(lambda: workspace_rect('HEADLESS-1')['y'] == 28)
        probe.terminate();probe.wait(timeout=5)
        command('output','HEADLESS-1','position','0','0');command('output','HEADLESS-2','position','1920','0')
        shot('secondary-corners','HEADLESS-2')
        secondary=pixels('secondary-corners')
        assert max(secondary(100,3))>30, 'Secondary outputs must not acquire the primary bar'
        assert max(secondary(0,1))<30 and max(secondary(0,29))>30, 'Secondary top corners stay at the screen edge'
        # Every reference view, at all requested scales.
        for scale in ([] if os.environ.get('ISLAND_TEST_FAST') else [1,1.25,1.6]):
            command('output','HEADLESS-1','scale',str(scale));time.sleep(.3)
            for mode in ['compact','hover','system','audio','network','bluetooth','weather','calendar','launcher','notification','notifications','osd','session','auth','lock']:
                shell('demo','compact');shell('demo',mode);time.sleep(.55)
                name=f'{round(scale*100)}-{mode}';shot(name)
                if mode!='lock':
                    pixel=pixels(name)
                    assert max(pixel(100,3))<30, (name,'Full-width primary bar missing')
                    assert max(pixel(0,28*scale+1))<30 and max(pixel(50,28*scale+1))>30, (name,'Primary top corners must begin below the bar')
                    assert max(pixel(0,1079))<30, (name,'Bottom corners must stay at the screen edge')
                    geometry=status()['geometry']
                    if mode=='compact':
                        assert max(pixel(960,32*scale))>30, 'Compact state must retract fully into the bar'
                    else:
                        left=960-geometry['width']*scale/2
                        join=geometry['joinRadius']*scale
                        assert max(pixel(left-2*scale,30*scale))<30, (name,'Inverse shoulder must join the bar')
                        assert max(pixel(left-join+2*scale,28*scale+join-2*scale))>30, (name,'Inverse shoulder must have a transparent cutout')
        shell('demo','compact');command('output','HEADLESS-1','scale','1');time.sleep(.3)
        # Capture all morphs, reversals, notification bursts and repeated volume updates.
        if not os.environ.get('ISLAND_TEST_FAST'):
            recorder=spawn(['wf-recorder','-y','-D','--no-dmabuf','-o','HEADLESS-1','-r','60','-f',str(OUT/'transitions.mp4')],env,'recording')
            time.sleep(.3)
            for mode in ['hover','compact','hover','compact','system','audio','network','bluetooth','weather','calendar','launcher','session','auth','compact','notification']:
                shell('demo',mode);time.sleep(.18 if mode in ['hover','compact'] else .65)
            for value in [20,40,60,80,55]: shell('osd','volume',value,'false');time.sleep(.12)
            time.sleep(1.8);recorder.send_signal(signal.SIGINT);recorder.wait(timeout=10)
        shell('demo','lock');time.sleep(.6);print('Preview captures:',status()['captures'],flush=True);shell('demo','compact')
        # Exercise the production chrome component over a real fullscreen client.
        # Its native bar surface stays mapped while its contents and top corners move.
        preview.terminate();preview.wait(timeout=5)
        chrome=spawn([QS,'-p',str(source/'chrome.qml')],env,'fullscreen-chrome')
        def chrome_call(method,*args): return ipc(source/'chrome.qml','chrome',method,*args)
        def chrome_status(): return json.loads(chrome_call('status'))
        eventually(lambda: chrome_status()['offset']==0)
        command('[title="Island fullscreen chrome probe"]','fullscreen','enable')
        command('[title="Island fullscreen chrome probe"]','move','container','to','output','HEADLESS-1')
        fullscreen_tray_state=base/'fullscreen-tray-state.json'
        fullscreen_tray=spawn([sys.executable,str(ROOT/'tests/native/tray.py'),str(fullscreen_tray_state)],env,'fullscreen-tray')
        eventually(lambda: fullscreen_tray_state.exists() and chrome_status()['trayCount']==1)
        fullscreen_recordings=[]
        for scale in ([1] if os.environ.get('ISLAND_TEST_FAST') else [1,1.25,1.6]):
            command('output','HEADLESS-1','scale',str(scale));time.sleep(.2)
            icon_x=round(1920-20*scale)
            icon_y=round(14*scale)
            # The virtual pointer spans both outputs; normalize the primary
            # output's physical icon position to the whole desktop.
            outputs=[o for o in json.loads(command('-t','get_outputs').stdout) if o['active']]
            primary=next(o for o in outputs if o['name']=='HEADLESS-1')
            left=min(o['rect']['x'] for o in outputs)
            top=min(o['rect']['y'] for o in outputs)
            desktop_width=max(o['rect']['x']+o['rect']['width'] for o in outputs)-left
            desktop_height=max(o['rect']['y']+o['rect']['height'] for o in outputs)-top
            pointer_x=round((primary['rect']['x']+icon_x/scale-left)*1920/desktop_width)
            pointer_y=round((primary['rect']['y']+icon_y/scale-top)*1080/desktop_height)
            opens=json.loads(fullscreen_tray_state.read_text())['menuOpens']
            click(pointer_x,pointer_y)
            eventually(lambda:chrome_status()['trayOpen'])
            time.sleep(.15)
            cell_x=round((primary['rect']['x']+(1920-28*scale)/scale-left)*1920/desktop_width)
            cell_y=round((primary['rect']['y']+56-top)*1080/desktop_height)
            click(cell_x,cell_y,'right')
            eventually(lambda: json.loads(fullscreen_tray_state.read_text())['menuOpens']>opens)
            pointer_command('move 100 400');time.sleep(.15)
            shot(f'tray-menu-{round(scale*100)}')
            fullscreen_recording=None
            if not os.environ.get('ISLAND_TEST_FAST'):
                recording=OUT/f'fullscreen-{round(scale*100)}.mp4'
                fullscreen_recordings.append(recording)
                fullscreen_recording=spawn(['wf-recorder','-y','-D','--no-dmabuf','-o','HEADLESS-1','-r','60','-f',str(recording)],env,f'fullscreen-recording-{round(scale*100)}')
                time.sleep(.25)
            transition=json.loads(chrome_call('fullscreen','true'))
            assert transition['before']==transition['after'], 'Fullscreen must retarget without changing current position'
            time.sleep(.04)
            assert -28 < chrome_status()['offset'] < 0, 'The bar and corners must slide through intermediate positions'
            eventually(lambda: not chrome_status()['animating'])
            assert not chrome_status()['trayOpen'], 'The tray grid must close when the bar slides away'
            assert chrome_status()['offset']==-28, 'Only the bar must leave the screen; top corners stop at the edge'
            shot(f'fullscreen-{round(scale*100)}-hidden')
            hidden=pixels(f'fullscreen-{round(scale*100)}-hidden')
            assert max(hidden(100,3))>30 and max(hidden(0,1))<30, 'Fullscreen hides the bar but keeps the top corners'
            assert max(hidden(0,12*scale+1))>30, 'Fullscreen top corners must be fully visible at their original size'
            assert max(hidden(0,1079))<30, 'Fullscreen must preserve the bottom corners'
            assert hidden(icon_x,icon_y)[0]<100, 'The tray must slide away with the bar'
            if scale==1:
                assert hidden(1850,110)[1]>75, 'Tray menus must close when the bar slides away'
            frames=chrome_status()['frames'];time.sleep(.12)
            assert chrome_status()['frames']==frames, 'Fullscreen chrome must stop animating after settling'
            chrome_call('fullscreen','false');time.sleep(.04)
            reversal=json.loads(chrome_call('fullscreen','true'))
            assert -28 < reversal['before'] < 0 and reversal['before']==reversal['after'], 'A rapid reversal must preserve the current position'
            chrome_call('fullscreen','false')
            eventually(lambda: not chrome_status()['animating'])
            shot(f'fullscreen-{round(scale*100)}-restored')
            restored=pixels(f'fullscreen-{round(scale*100)}-restored')
            assert chrome_status()['offset']==0 and max(restored(100,3))<30
            assert max(restored(0,28*scale+1))<30, 'The top corners must return below the bar'
            assert max(max(restored(x,y)) for x in range(round(1920-31*scale),round(1920-15*scale)) for y in range(round(8*scale),round(20*scale)))>75, 'Tray chevron must return with the bar'
            if fullscreen_recording:
                fullscreen_recording.send_signal(signal.SIGINT);fullscreen_recording.wait(timeout=10)
        chrome_call('reduced','true');chrome_call('fullscreen','true')
        assert chrome_status()['offset']==-28 and not chrome_status()['animating']
        chrome_call('fullscreen','false')
        assert chrome_status()['offset']==0 and not chrome_status()['animating']
        if fullscreen_recordings:
            playlist=base/'fullscreen-videos.txt'
            playlist.write_text(''.join("file '"+str(path)+"'\n" for path in fullscreen_recordings))
            run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(playlist),'-c','copy',str(OUT/'fullscreen.mp4')],env)
        fullscreen_tray.terminate();fullscreen_tray.wait(timeout=5)
        chrome.terminate();chrome.wait(timeout=5)
        command('output','HEADLESS-1','scale','1')
        preview=spawn([str(ROOT/'bin/island'),'run','--preview','--showcase'],env,'shell-restored')
        eventually(lambda: status()['mode']=='compact')
        # Native notification protocol runs on a private session bus.
        notifenv=dict(env,ISLAND_MODE='live',ISLAND_CONFIG=json.dumps({'notifications':True}))
        notif=spawn([QS,'-p',str(source/'notifications.qml')],notifenv,'notifications')
        def notices(method,*args): return ipc(source/'notifications.qml','test',method,*args)
        def ns(): return json.loads(notices('state'))
        eventually(lambda: ns()['records'] == [])
        def notify(replace=0, body='Body', timeout=1500, hints='{}'):
            result=run(['gdbus','call','--session','--dest','org.freedesktop.Notifications','--object-path','/org/freedesktop/Notifications','--method','org.freedesktop.Notifications.Notify','Fixture',str(replace),'','Title',body,'[]',hints,str(timeout)],env)
            return int(re.search(r'uint32 (\d+)',result.stdout).group(1))
        n=notify();eventually(lambda: ns()['popup'] is not None)
        notify(n,'Replacement');assert len(ns()['records']) == 1
        assert ns()['records'][0]['body']=='Replacement'
        eventually(lambda: ns()['popup'] is None,3)
        assert len(ns()['history'])==1 and not ns()['history'][0]['live']
        notices('clear');notices('block','true');notify(timeout=200)
        time.sleep(.5);notices('block','false');assert ns()['popup'] is None
        notices('dnd','true');notify();notices('dnd','false');assert ns()['popup'] is None
        notices('clear');notify(timeout=200,hints="{'transient': <true>}")
        eventually(lambda: ns()['records']==[],2)
        notices('clear');notices('suppress','true');notify();notices('suppress','false');assert ns()['popup'] is None
        notif.terminate();notif.wait(timeout=5)
        # Native desktop entry execution, terminal wrapping, working directory, and recency.
        data=base/'data'; entries=data/'applications'; entries.mkdir(parents=True)
        cwd=base/'working'; cwd.mkdir()
        launched=base/'launched.json'; terminal=base/'terminal.json'
        program=base/'launch.py'; program.write_text('import os,sys,json;from pathlib import Path;Path('+repr(str(launched))+').write_text(json.dumps({"cwd":os.getcwd(),"args":sys.argv[1:]}))')
        wrapper=base/'terminal.py'; wrapper.write_text('import sys,subprocess,json;from pathlib import Path;Path('+repr(str(terminal))+').write_text(json.dumps(sys.argv[1:]));subprocess.run(sys.argv[1:],check=True)')
        (entries/'island-fixture.desktop').write_text('[Desktop Entry]\nType=Application\nName=Island Launch Fixture\nExec='+sys.executable+' '+str(program)+' "two words" %U\nTerminal=true\nPath='+str(cwd)+'\nOnlyShowIn=Hyprland;\n')
        appenv=dict(env,XDG_DATA_HOME=str(data),XDG_CURRENT_DESKTOP='Hyprland',ISLAND_CONFIG=json.dumps({'terminal':[sys.executable,str(wrapper)]}))
        apps=spawn([QS,'-p',str(source/'apps.qml')],appenv,'apps')
        eventually(lambda: ipc(source/'apps.qml','apps','ready')=='true')
        assert ipc(source/'apps.qml','apps','launch')=='true'
        eventually(lambda: launched.exists() and terminal.exists())
        assert json.loads(launched.read_text())=={'cwd':str(cwd),'args':['two words']}
        assert json.loads(ipc(source/'apps.qml','apps','state'))['history']
        apps.terminate();apps.wait(timeout=5)
        auth=spawn([QS,'-p',str(source/'auth.qml')],env,'auth')
        auth.wait(timeout=5)
        assert 'AUTH_TEST_PASS' in (OUT/'auth.log').read_text(), (OUT/'auth.log').read_text()
        shell('demo','compact');time.sleep(.3)
        # The production locker: protocol acquisition, capture, hotplug, and SIGKILL fail closed.
        locker=spawn([QS,'-p',str(ROOT/'src/locker.qml')],dict(env,ISLAND_MODE='live'), 'locker')
        def lockstatus(): return json.loads(ipc(ROOT/'src/locker.qml','lock','status'))
        secure=eventually(lambda: lockstatus() if lockstatus()['secure'] else None)
        time.sleep(.4);shot('secure-lock')
        command('create_output');eventually(lambda: len(lockstatus()['outputs'])==3)
        time.sleep(.3);shot('secure-hotplug','HEADLESS-3')
        # A second lock client must fail without releasing the first client's lock.
        replacement=spawn([QS,'-p',str(source/'locker.qml')],dict(env,ISLAND_MODE='live'),'lock-refused')
        replacement.wait(timeout=6)
        assert 'refused the session lock' in (OUT/'lock-refused.log').read_text()
        locker.kill();locker.wait(timeout=5);time.sleep(.3);shot('locker-crash')
        abandoned_probe=spawn([QS,'-p',str(source/'probe.qml')],env,'abandoned-probe')
        eventually(lambda: ipc(source/'probe.qml','probe','count') == '0')
        click(100,400);time.sleep(.2)
        assert ipc(source/'probe.qml','probe','count') == '0', 'A crashed locker must leave normal apps inaccessible'
        report={'morphSettlingMs':timings,'lockSecure':secure,'renderer':env['WLR_RENDERER'],'checks':['immediate typing','search restoration','native tray icons/actions/menu/scroll/status/removal/fullscreen','clock calendar, seconds lifetime, navigation, date selection, auth restoration, bar toggles and Escape at 100/125/160%', 'simulated network password retries, Wi-Fi radio, LAN reconnect/unplug, VPN toggles, adapter removal; private system bus','fixed 28 px primary-bar reservation during expansion and monitor handover','concave shoulder / rounded bottom input region and click through','full-width bar and shifted primary corners; secondary corners unchanged','monitor disconnect/fallback/reconnection','fullscreen bar/corner slide, reversal, reduced motion and idle frames','100/125/160% screenshots','native notification replacement/expiry/queue/DND/transient','native launcher terminal/working-directory/recency','PAM failure/retry/conversation adapter','lock acquisition/hotplug/crash/refusal'],'limitations':['Isolated Sway protocol lab; physical Hyprland evidence is recorded separately in artifacts/aoc-motion.json','No real user password or real shutdown/reboot was submitted']}
        (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report,indent=2),flush=True)
        for name in ['shell','shell-after-system','system-fixture','audio-fixture','audio-native','shell-restored','fullscreen-chrome','notifications','locker','apps']:
            data=(OUT/(name+'.log')).read_text()
            errors=[line for line in data.splitlines() if any(term in line for term in ['Binding loop','ReferenceError','TypeError','Unable to assign','Failed to load configuration'])]
            assert not errors,(name,errors)

if __name__=='__main__':
    try: main()
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                try: os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=3)
                except (ProcessLookupError,subprocess.TimeoutExpired):
                    try:os.killpg(process.pid,signal.SIGKILL)
                    except ProcessLookupError:pass
        for log in logs:log.close()
        for path in temporary: shutil.rmtree(path,ignore_errors=True)
