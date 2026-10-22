import asyncio
from pathlib import Path
import sys
import unittest
from unittest.mock import AsyncMock, patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'lib'))
from bluetooth_bridge import Agent, Bridge, DBusError, error_message

class AgentTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.events=[]
        self.bridge=Bridge(lambda **event:self.events.append(event))
        self.bridge.pairing_path='/org/bluez/hci0/dev_00_11_22_33_44_55'
    async def prompt(self,kind,value):
        task=asyncio.create_task(self.bridge.agent.request(kind,self.bridge.pairing_path))
        await asyncio.sleep(0)
        self.bridge.agent.respond(value)
        return await task
    async def test_pairing_requests_require_explicit_response(self):
        self.assertTrue(await self.prompt('confirm',True))
        self.assertEqual(self.events[0]['kind'],'confirm')
        self.assertEqual(self.events[-1]['event'],'prompt-clear')
        with self.assertRaises(DBusError): await self.prompt('confirm',None)
    async def test_other_devices_cannot_request_pairing(self):
        with self.assertRaises(DBusError):
            await self.bridge.agent.request('pin','/org/bluez/hci0/dev_OTHER')
        self.assertFalse(self.events)
    async def test_only_current_bluez_objects_are_actionable(self):
        self.bridge.pairing_path=""
        self.bridge.objects=AsyncMock(return_value={})
        self.bridge.call=AsyncMock()
        await self.bridge.action({'id':1,'action':'pair','path':'/invented'})
        self.bridge.call.assert_not_called()
        self.assertFalse(next(e for e in self.events if e['event']=='done')['ok'])
    async def test_trust_never_changes_implicitly_and_forget_uses_device_adapter(self):
        from dbus_next import Variant
        path=self.bridge.pairing_path
        self.bridge.objects=AsyncMock(return_value={path:{'org.bluez.Device1':{'Adapter':Variant('o','/org/bluez/hci9')}}})
        self.bridge.call=AsyncMock(return_value=[])
        await self.bridge.action({'id':1,'action':'forget','path':path})
        self.assertEqual(self.bridge.call.call_args.args,('/org/bluez/hci9','org.bluez.Adapter1','RemoveDevice','o',[path]))
        self.assertTrue(next(e for e in self.events if e['event']=='done')['ok'])
    async def test_scan_timeout_releases_only_the_owned_discovery_session(self):
        path='/org/bluez/hci0'
        self.bridge.call=AsyncMock(return_value=[])
        self.bridge.scans[path]=asyncio.current_task()
        with patch('bluetooth_bridge.asyncio.sleep',new_callable=AsyncMock) as sleep:
            await self.bridge.scan_timeout(path)
            sleep.assert_awaited_once_with(20)
        self.bridge.call.assert_awaited_once_with(path,'org.bluez.Adapter1','StopDiscovery')
        self.assertFalse(self.bridge.scans)
        await self.bridge.stop_scan('/org/bluez/hci9')
        self.assertEqual(self.bridge.call.await_count,1)
    def test_agent_rejects_other_system_bus_senders(self):
        from dbus_next import Message
        self.bridge.owner=':1.7'
        request=Message(path='/org/island/agent',interface='org.bluez.Agent1',member='Cancel',sender=':1.99',serial=10)
        result=self.bridge.filter_agent_sender(request)
        self.assertEqual(result.error_name,'org.bluez.Error.Rejected')
    def test_errors_never_echo_backend_text_or_credentials(self):
        self.assertEqual(error_message(DBusError('org.bluez.Error.AuthenticationFailed','secret input')),'Pairing failed. Check the PIN or passkey and retry.')
        self.assertNotIn('secret',error_message(DBusError('org.bluez.Error.Failed','secret input')))
