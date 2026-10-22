"""Power Profiles protocol fixture. Only used on the lab's private system bus."""
import asyncio
import json
from pathlib import Path
import sys
from dbus_next import DBusError, Variant
from dbus_next.aio import MessageBus
from dbus_next.constants import PropertyAccess
from dbus_next.service import ServiceInterface, dbus_property, method

state_path=Path(sys.argv[1]);state={'ready':False,'writes':[]}
bus=None
MODERN='org.freedesktop.UPower.PowerProfiles';LEGACY='net.hadess.PowerProfiles'
def save():state_path.write_text(json.dumps(state))

class Profiles(ServiceInterface):
    def __init__(self,interface):
        super().__init__(interface)
        self.profile='balanced';self.supported=['power-saver','balanced','performance'];self.degraded='';self.inhibited='';self.holds=[];self.denied=False
    @dbus_property(access=PropertyAccess.READWRITE)
    def ActiveProfile(self)->'s':return self.profile
    @ActiveProfile.setter
    def ActiveProfile(self,value:'s'):
        if self.denied:raise DBusError('org.freedesktop.DBus.Error.AccessDenied','Synthetic permission failure')
        if value not in self.supported:raise DBusError('org.freedesktop.DBus.Error.Failed','Unavailable profile')
        if value=='performance' and self.inhibited:raise DBusError('org.freedesktop.DBus.Error.Failed','Inhibited')
        self.profile=value;self.holds=[];state['writes'].append({'provider':self.name,'profile':value});save()
        self.emit_properties_changed({'ActiveProfile':value,'ActiveProfileHolds':[]})
    @dbus_property(access=PropertyAccess.READ)
    def Profiles(self)->'aa{sv}':return [{'Profile':Variant('s',p),'Driver':Variant('s','test-driver')} for p in self.supported]
    @dbus_property(access=PropertyAccess.READ)
    def PerformanceDegraded(self)->'s':return self.degraded
    @dbus_property(access=PropertyAccess.READ)
    def PerformanceInhibited(self)->'s':return self.inhibited
    @dbus_property(access=PropertyAccess.READ)
    def ActiveProfileHolds(self)->'aa{sv}':return self.holds

modern=Profiles(MODERN);legacy=Profiles(LEGACY)
class Control(ServiceInterface):
    def __init__(self):super().__init__('org.island.PowerTest')
    @method()
    def Scenario(self,value:'s'):
        for p in (modern,legacy):
            if value=='two':p.supported=['power-saver','balanced'];p.profile='balanced'
            if value=='all':p.supported=['power-saver','balanced','performance'];p.inhibited='';p.degraded='';p.denied=False;p.holds=[]
            if value=='inhibited':p.inhibited='lap-detected'
            if value=='degraded':p.degraded='high-operating-temperature'
            if value=='hold':p.holds=[{'Profile':Variant('s','performance'),'ApplicationId':Variant('s','Game'),'Reason':Variant('s','A game is running')}]
            if value=='denied':p.denied=True
            if value=='external':p.profile='power-saver'
            p.emit_properties_changed({'ActiveProfile':p.profile,'Profiles':p.Profiles,'PerformanceDegraded':p.degraded,'PerformanceInhibited':p.inhibited,'ActiveProfileHolds':p.holds})
    @method()
    async def Names(self,value:'s'):
        if value in ('legacy','none'):await bus.release_name(MODERN)
        if value=='none':await bus.release_name(LEGACY)
        if value=='both':await bus.request_name(LEGACY);await bus.request_name(MODERN)

async def main():
    global bus
    bus=await MessageBus().connect()
    bus.export('/org/freedesktop/UPower/PowerProfiles',modern)
    bus.export('/net/hadess/PowerProfiles',legacy)
    bus.export('/org/island/test',Control())
    await bus.request_name('org.island.PowerTestFixture')
    await bus.request_name(MODERN);await bus.request_name(LEGACY)
    state['ready']=True;save()
    await asyncio.Future()
asyncio.run(main())
