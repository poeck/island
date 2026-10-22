import asyncio
from pathlib import Path
import sys
import unittest
from unittest.mock import AsyncMock
from dbus_next import DBusError,Variant
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'lib'))
from power_profiles import Watcher,normalize,error_message

class PowerProfileTests(unittest.IsolatedAsyncioTestCase):
    def test_capabilities_and_holds_come_from_daemon(self):
        s=normalize({'ActiveProfile':Variant('s','balanced'),'Profiles':Variant('aa{sv}',[{'Profile':Variant('s','balanced')},{'Profile':Variant('s','power-saver')},{'Profile':Variant('s','unknown')}]),'ActiveProfileHolds':Variant('aa{sv}',[{'Profile':Variant('s','power-saver'),'Reason':Variant('s','Battery low'),'ApplicationId':Variant('s','Power manager')}])})
        self.assertEqual(s['profiles'],['power-saver','balanced'])
        self.assertEqual(s['holds'],[{'profile':'power-saver','reason':'Battery low','app':'Power manager'}])
        self.assertFalse(normalize({})['available'])
    async def test_unsupported_inhibited_and_same_profile_do_not_write(self):
        events=[];w=Watcher(lambda **v:events.append(v));w.target=('owner','/path','interface')
        w.refresh=AsyncMock();w.call=AsyncMock()
        w.state={'available':True,'profile':'balanced','profiles':['power-saver','balanced'],'inhibited':''}
        await w.select({'id':1,'profile':'performance'})
        self.assertFalse(events[-1]['ok']);w.call.assert_not_awaited()
        await w.select({'id':2,'profile':'balanced'})
        self.assertTrue(events[-1]['ok']);w.call.assert_not_awaited()
        w.state['profiles'].append('performance');w.state['inhibited']='lap-detected'
        await w.select({'id':3,'profile':'performance'})
        self.assertFalse(events[-1]['ok']);w.call.assert_not_awaited()
    async def test_denied_writes_keep_confirmed_state(self):
        events=[];w=Watcher(lambda **v:events.append(v));w.target=('owner','/path','interface')
        w.state={'available':True,'profile':'balanced','profiles':['power-saver','balanced'],'inhibited':''}
        w.refresh=AsyncMock();w.call=AsyncMock(side_effect=DBusError('org.freedesktop.DBus.Error.AccessDenied','private daemon detail'))
        await w.select({'id':1,'profile':'power-saver'})
        self.assertEqual(w.state['profile'],'balanced')
        self.assertEqual(events[-1]['error'],'Permission to change the power profile was denied.')
    def test_errors_are_readable_and_do_not_echo_daemon_payloads(self):
        self.assertNotIn('private',error_message(DBusError('org.freedesktop.DBus.Error.Failed','private detail')))
