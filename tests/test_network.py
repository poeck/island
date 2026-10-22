import sys
from pathlib import Path
from types import SimpleNamespace
import subprocess
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
from network import fields, snapshot, vpn_action

UUID = '11111111-1111-1111-1111-111111111111'
class NetworkTests(unittest.TestCase):
    def runner(self, *args):
        self.calls.append(args)
        if args[-2:] == ('connection', 'show'):
            return SimpleNamespace(returncode=0,stdout=UUID+r':Work\: VPN:vpn:yes'+'\n22222222-2222-2222-2222-222222222222:LAN:802-3-ethernet:yes\n')
        if args[-2:] == ('device','show'):
            return SimpleNamespace(returncode=0,stdout='GENERAL.DEVICE:enp5s0\nIP4.ADDRESS[1]:192.168.1.5/24\nIP4.GATEWAY:192.168.1.1\nIP4.DNS[1]:1.1.1.1\nIP6.ADDRESS[1]:fd00\\:\\:2/64\nGENERAL.DEVICE:wlan0\nIP4.GATEWAY:\n')
        return SimpleNamespace(returncode=0,stdout='')
    def setUp(self): self.calls=[]
    def test_escaped_names_ipv6_and_multiple_devices(self):
        result=snapshot(self.runner)
        self.assertTrue(result['available'])
        self.assertEqual(result['vpns'],[{'uuid':UUID,'name':'Work: VPN','type':'vpn','active':True}])
        self.assertEqual(result['devices']['enp5s0']['ipv6'],['fd00::2/64'])
        self.assertEqual(result['devices']['enp5s0']['ipv4'],['192.168.1.5/24'])
        self.assertEqual(result['devices']['wlan0']['ipv4'],[])
        self.assertEqual(fields(r'foo\\bar:baz\:quux'),['foo\\bar','baz:quux'])
    def test_dispatch_requires_existing_vpn_and_explicit_action(self):
        self.assertTrue(vpn_action('up:'+UUID,self.runner)['ok'])
        self.assertEqual(self.calls[-1],('--wait','6','connection','up','uuid',UUID))
        for value in ('up:; reboot', 'delete:'+UUID, 'up:33333333-3333-3333-3333-333333333333'):
            self.calls=[]
            self.assertFalse(vpn_action(value,self.runner)['ok'])
            self.assertFalse(any('up' in call or 'delete' in call for call in self.calls))
    def test_unavailable_and_timeout(self):
        def failing(*args): raise subprocess.TimeoutExpired('nmcli',8)
        self.assertFalse(snapshot(failing)['available'])
        self.assertFalse(vpn_action('up:'+UUID,failing)['ok'])
        self.assertFalse(snapshot(lambda *args:SimpleNamespace(returncode=1,stdout=''))['available'])
