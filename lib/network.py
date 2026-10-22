"""Read-only NetworkManager metadata and bounded saved-VPN activation.

Wi-Fi secrets stay in Quickshell's native DBus path; this adapter never sees them.
"""
import json
import os
import re
import subprocess


def fields(line):
    result, field, escaped = [], '', False
    for char in line:
        if escaped:
            field += char
            escaped = False
        elif char == '\\':
            escaped = True
        elif char == ':':
            result.append(field)
            field = ''
        else:
            field += char
    result.append(field + ('\\' if escaped else ''))
    return result


def nmcli(*args):
    return subprocess.run(['nmcli', '--colors', 'no', '--terse', '--escape', 'yes', *args],
                          env=dict(os.environ, LC_ALL='C'), capture_output=True, text=True, timeout=8)


def snapshot(runner=nmcli):
    try:
        devices = runner('--fields', 'GENERAL.DEVICE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS', 'device', 'show')
        profiles = runner('--fields', 'UUID,NAME,TYPE,ACTIVE', 'connection', 'show')
        if devices.returncode or profiles.returncode:
            return {'available': False, 'devices': {}, 'vpns': [], 'error': 'NetworkManager is unavailable.'}
        details, current = {}, None
        for line in devices.stdout.splitlines():
            key, _, raw = line.partition(':')
            value = ':'.join(fields(raw))
            key = re.sub(r'\[\d+\]$', '', key)
            if key == 'GENERAL.DEVICE':
                current = {'ipv4': [], 'ipv6': [], 'dns': [], 'gateway': ''}
                details[value] = current
            elif current is not None and value and value != '--':
                target = {'IP4.ADDRESS': 'ipv4', 'IP6.ADDRESS': 'ipv6', 'IP4.DNS': 'dns'}.get(key)
                if target:
                    current[target].append(value)
                elif key == 'IP4.GATEWAY':
                    current['gateway'] = value
        vpns = []
        for line in profiles.stdout.splitlines():
            row = fields(line)
            if len(row) == 4 and row[2] in ('vpn', 'wireguard'):
                vpns.append({'uuid': row[0], 'name': row[1], 'type': row[2], 'active': row[3] == 'yes'})
        return {'available': True, 'devices': details, 'vpns': sorted(vpns, key=lambda v: (not v['active'], v['name'].casefold())), 'error': ''}
    except (OSError, subprocess.TimeoutExpired):
        return {'available': False, 'devices': {}, 'vpns': [], 'error': 'Could not read NetworkManager status.'}


def vpn_action(value, runner=nmcli):
    # Validate identity against current saved VPNs; never interpret names as commands.
    try:
        action, uuid = value.split(':', 1)
        if action not in ('up', 'down') or not re.fullmatch(r'[0-9a-fA-F-]{36}', uuid):
            raise ValueError()
        if not any(p['uuid'] == uuid for p in snapshot(runner)['vpns']):
            return {'ok': False, 'error': 'This VPN profile is no longer available.'}
        result = runner('--wait', '6', 'connection', action, 'uuid', uuid)
        return {'ok': result.returncode == 0,
                'error': '' if result.returncode == 0 else 'VPN connection failed. Check its credentials and settings in your network editor.'}
    except (ValueError, OSError, subprocess.TimeoutExpired):
        return {'ok': False, 'error': 'VPN request failed or timed out.'}
