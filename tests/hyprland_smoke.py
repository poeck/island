#!/usr/bin/env python3
"""Real focus-grab regression in nested Hyprland; never injects host input."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/hyprland'
OUT.mkdir(parents=True, exist_ok=True)
processes, logs = [], []


def spawn(args, env, name):
    log = open(OUT / (name + '.log'), 'w'); logs.append(log)
    p = subprocess.Popen(args, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    processes.append(p)
    return p


def run(args, env):
    return subprocess.run(args, env=env, capture_output=True, text=True, check=True, timeout=10).stdout.strip()


def eventually(check, timeout=8):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            value = check()
            if value: return value
        except (ValueError, FileNotFoundError, subprocess.CalledProcessError): pass
        time.sleep(.04)
    raise AssertionError('Timed out waiting for ' + str(check))


def main(base, parent_display):
    env = dict(os.environ)
    for key in ['HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY',
                'DBUS_SESSION_BUS_ADDRESS', 'DBUS_SYSTEM_BUS_ADDRESS', 'SWAYSOCK', 'PULSE_SERVER', 'PIPEWIRE_REMOTE']:
        env.pop(key, None)
    for key, name in [('XDG_RUNTIME_DIR','r'), ('XDG_CONFIG_HOME','config'), ('XDG_CACHE_HOME','cache'),
                      ('XDG_STATE_HOME','state'), ('XDG_DATA_HOME','data')]:
        path = base / name; path.mkdir(mode=0o700); env[key] = str(path)
    env.update(WAYLAND_DISPLAY=parent_display, AQ_DRM_DEVICES='/dev/null', HYPRLAND_NO_SD_VARS='1',
               HYPRLAND_NO_SD_NOTIFY='1', HYPRLAND_NO_SD_TARGET='1', QT_QPA_PLATFORM='wayland',
               QT_QPA_PLATFORMTHEME='', QS_DISABLE_CRASH_HANDLER='1', ISLAND_WATCH='0',
               ISLAND_MODE='preview', ISLAND_EXECUTABLE=str(ROOT/'bin/island'),
               ISLAND_CONFIG='{"monitor":"TEST"}', PIPEWIRE_REMOTE='island-no-test-device',
               PULSE_SERVER='unix:/nonexistent-island-test', NO_AT_BRIDGE='1')
    bus_config=base/'bus.conf'
    bus_config.write_text('<busconfig><type>session</type><listen>unix:tmpdir='+env['XDG_RUNTIME_DIR']+'</listen>'
                          '<policy context="default"><allow own="*"/><allow send_destination="*"/>'
                          '<allow receive_sender="*"/></policy></busconfig>')
    bus=subprocess.Popen(['dbus-daemon','--config-file='+str(bus_config),'--nofork','--print-address'], env=env,
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, start_new_session=True)
    processes.append(bus); env['DBUS_SESSION_BUS_ADDRESS']=bus.stdout.readline().strip()
    env['DBUS_SYSTEM_BUS_ADDRESS']=env['DBUS_SESSION_BUS_ADDRESS']
    config=base/'hyprland.conf'
    config.write_text('''monitor = ,1920x1080@60,0x0,1
animations { enabled = false }
misc {
 disable_hyprland_logo = true
 disable_splash_rendering = true
}
debug { disable_logs = false }
''')
    spawn(['Hyprland','-c',str(config)],env,'compositor')
    socket=eventually(lambda:next((p for p in (base/'r').glob('wayland-*') if not p.name.endswith('.lock')),None),15)
    env['WAYLAND_DISPLAY']=socket.name
    ipc_socket=eventually(lambda:next((base/'r/hypr').glob('*/.socket.sock'),None))
    control_env=dict(env,HYPRLAND_INSTANCE_SIGNATURE=ipc_socket.parent.name)
    def control(*args): return run(['hyprctl',*args],control_env)
    # The parent compositor may resize the nested window to fit its tiling layout.
    # All pointer coordinates below are mapped to the actual nested output size.
    eventually(lambda:any(m['width']>0 for m in json.loads(control('-j','monitors'))))
    qs=env.get('ISLAND_QUICKSHELL') or shutil.which('quickshell')
    def ipc(path,target,method,*args): return run([qs,'ipc','-p',str(path),'call',target,method,*map(str,args)],env)
    def shell(method,*args): return ipc(ROOT/'src/shell.qml','island',method,*args)
    def status(): return json.loads(shell('status'))
    source=base/'source'; shutil.copytree(ROOT/'src',source)
    shutil.copy(ROOT/'tests/native/probe.qml',source/'probe.qml')
    spawn([qs,'-p',str(source/'probe.qml')],env,'probe')
    eventually(lambda:ipc(source/'probe.qml','probe','count')=='0')
    control('dispatch','fullscreen','0')
    spawn([str(ROOT/'bin/island'),'run','--preview','--showcase'],env,'shell')
    eventually(lambda:status()['mode']=='compact')
    protocol=ROOT/'tests/native/wlr-virtual-pointer-unstable-v1.xml'
    run(['wayland-scanner','client-header',str(protocol),str(base/'pointer-protocol.h')],env)
    run(['wayland-scanner','private-code',str(protocol),str(base/'pointer-protocol.c')],env)
    flags=run(['pkg-config','--cflags','--libs','wayland-client'],env).split()
    run(['cc','-I'+str(base),str(ROOT/'tests/native/pointer.c'),str(base/'pointer-protocol.c'),'-o',str(base/'pointer'),*flags],env)
    pointer=subprocess.Popen([str(base/'pointer')],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,start_new_session=True)
    processes.append(pointer); assert pointer.stdout.readline().strip()=='ready'
    def point(command):
        pointer.stdin.write(command+'\n');pointer.stdin.flush()
        assert pointer.stdout.readline().strip()=='ok'
    def move(x,y):
        monitors=json.loads(control('-j','monitors'))
        left=min(m['x'] for m in monitors); top=min(m['y'] for m in monitors)
        right=max(m['x']+m['width'] for m in monitors); bottom=max(m['y']+m['height'] for m in monitors)
        point('move %d %d' % (round((x-left)/(right-left)*1920),round((y-top)/(bottom-top)*1080)))
    def center(): return json.loads(control('-j','monitors'))[0]['width']/2
    def bottom(): return json.loads(control('-j','monitors'))[0]['height']-4
    def click(x,y,button='button'):
        move(x,y);time.sleep(.04)
        point(button+' 1');time.sleep(.04);point(button+' 0')
    panels=['calendar','media','system','audio','network','bluetooth','weather','launcher','notifications','session']
    for panel in panels:
        shell('demo',panel)
        eventually(lambda:status()['mode']==panel and status()['outsideClickArmed'] and not status()['animating'])
        move(50,bottom());time.sleep(.12)
        assert status()['mode']==panel, 'Moving outside must not dismiss '+panel
        click(center(),30);time.sleep(.08)
        assert status()['mode']==panel, 'Inside click must not dismiss '+panel
        click(50,bottom())
        eventually(lambda:status()['mode']=='compact' and not status()['outsideClickArmed'])
        print('Outside dismissal passed:',panel,flush=True)
    click(center(),14);eventually(lambda:status()['mode']=='calendar' and status()['outsideClickArmed'])
    click(center(),14);eventually(lambda:status()['mode']=='compact')
    click(center(),14);eventually(lambda:status()['outsideClickArmed'])
    click(50,bottom(),'right');eventually(lambda:status()['mode']=='compact')
    # Keyboard input must continue after exclusive layer focus is released.
    keyboard=spawn(['wtype','-s','600','-d','30','fire','-s','1000'],env,'keyboard')
    time.sleep(.1);shell('demo','launcher')
    eventually(lambda:status()['query']=='fire' and status()['outsideClickArmed'])
    keyboard.wait(timeout=5)
    click(50,bottom());eventually(lambda:status()['mode']=='compact')
    # Authentication is deliberately not an outside-dismissable ordinary panel.
    shell('demo','calendar');eventually(lambda:status()['outsideClickArmed'])
    shell('demo','auth');eventually(lambda:status()['mode']=='auth' and not status()['outsideClickArmed'])
    click(50,bottom());time.sleep(.15)
    assert status()['mode']=='auth'
    run(['wtype','-s','150','-k','Escape'],env)
    eventually(lambda:status()['mode']=='calendar' and status()['outsideClickArmed'])
    click(50,bottom());eventually(lambda:status()['mode']=='compact')
    count=int(ipc(source/'probe.qml','probe','count'))
    click(50,bottom())
    eventually(lambda:int(ipc(source/'probe.qml','probe','count'))==count+1)
    # Bar controls remain in the grab once keyboard focus is handed over.
    for key, mode in [('cpu','system'),('power','session')]:
        rect=status()['barLayout'][key]
        click(rect['x']+rect['width']/2,14)
        eventually(lambda:status()['mode']==mode and status()['outsideClickArmed'] and not status()['animating'])
        click(rect['x']+rect['width']/2,14)
        eventually(lambda:status()['mode']=='compact')
    # A click on a different output must dismiss the same desktop-wide grab.
    first=json.loads(control('-j','monitors'))[0]
    control('output','create','wayland')
    second=eventually(lambda:next((m for m in json.loads(control('-j','monitors')) if m['name']!=first['name'] and m['width']>0),None))
    control('keyword','monitor',second['name']+',preferred,'+str(first['width'])+'x0,1')
    time.sleep(.3)
    shell('demo','calendar')
    eventually(lambda:status()['mode']=='calendar' and status()['outsideClickArmed'] and not status()['animating'])
    second=next(m for m in json.loads(control('-j','monitors')) if m['name']!=status()['screen'])
    click(second['x']+second['width']/2,second['y']+second['height']-4)
    eventually(lambda:status()['mode']=='compact')
    log=(OUT/'shell.log').read_text()
    assert not any(term in log for term in ['Binding loop','ReferenceError','TypeError','Unable to assign','Failed to load configuration']),log
    report={'compositor':'nested Hyprland','signatureInherited':False,'panels':panels,
            'checks':['outside left/right click','inside click','movement','clock/resource/power toggles','auth restoration',
                      'desktop input after dismissal','launcher typing with popup focus','outside click on second output']}
    (OUT/'outside-click.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--parent-display',required=True,help='Absolute Wayland socket for the nested renderer; simulated input stays in the nested compositor')
    args=parser.parse_args()
    if not Path(args.parent_display).is_absolute(): parser.error('--parent-display must be an absolute socket path')
    with tempfile.TemporaryDirectory(prefix='iqh-',dir='/tmp') as directory:
        try: main(Path(directory),args.parent_display)
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    try: os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=3)
                    except (ProcessLookupError,subprocess.TimeoutExpired):
                        try: os.killpg(process.pid,signal.SIGKILL)
                        except ProcessLookupError: pass
            for log in logs: log.close()
