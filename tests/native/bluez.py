"""Synthetic BlueZ daemon on the native lab's private system bus. No hardware access."""
import asyncio
import json
from pathlib import Path
import sys
from dbus_next import DBusError, Message
from dbus_next.aio import MessageBus
from dbus_next.constants import PropertyAccess, MessageType
from dbus_next.service import ServiceInterface, dbus_property, method

state_path=Path(sys.argv[1])
state={'ready':False,'agents':0,'defaultAgentCalls':0,'scanStarts':0,'scanStops':0,'pairs':0,'cancels':0,'connects':0,'disconnects':0,'removes':0,'pin':False,'passkey':False}
bus=None
agents={}

def save(): state_path.write_text(json.dumps(state))

def remove(path, interfaces):
    bus.unexport(path)
    # BlueZ owns one ObjectManager at /; dbus-next otherwise emits removal
    # on the child path, which is not the real BlueZ signal contract.
    bus.send(Message.new_signal(path="/",interface="org.freedesktop.DBus.ObjectManager",member="InterfacesRemoved",signature="oas",body=[path,interfaces]))

class Adapter(ServiceInterface):
    def __init__(self):
        super().__init__('org.bluez.Adapter1')
        self.powered=True;self.discoverable=False;self.discovering=False;self.timeout=120
    @dbus_property(access=PropertyAccess.READ)
    def Address(self)->'s':return '11:22:33:44:55:66'
    @dbus_property(access=PropertyAccess.READ)
    def Name(self)->'s':return 'Island lab'
    @dbus_property(access=PropertyAccess.READWRITE)
    def Alias(self)->'s':return 'Island lab'
    @Alias.setter
    def Alias(self,value:'s'):pass
    @dbus_property(access=PropertyAccess.READWRITE)
    def Powered(self)->'b':return self.powered
    @Powered.setter
    def Powered(self,value:'b'):
        self.powered=value;self.emit_properties_changed({'Powered':value})
        if not value:
            for d in devices.values():d.set_connected(False)
    @dbus_property(access=PropertyAccess.READWRITE)
    def Discoverable(self)->'b':return self.discoverable
    @Discoverable.setter
    def Discoverable(self,value:'b'):self.discoverable=value;self.emit_properties_changed({'Discoverable':value})
    @dbus_property(access=PropertyAccess.READWRITE)
    def DiscoverableTimeout(self)->'u':return self.timeout
    @DiscoverableTimeout.setter
    def DiscoverableTimeout(self,value:'u'):self.timeout=value;self.emit_properties_changed({'DiscoverableTimeout':value})
    @dbus_property(access=PropertyAccess.READWRITE)
    def Pairable(self)->'b':return True
    @Pairable.setter
    def Pairable(self,value:'b'):pass
    @dbus_property(access=PropertyAccess.READWRITE)
    def PairableTimeout(self)->'u':return 0
    @PairableTimeout.setter
    def PairableTimeout(self,value:'u'):pass
    @dbus_property(access=PropertyAccess.READ)
    def Discovering(self)->'b':return self.discovering
    @dbus_property(access=PropertyAccess.READ)
    def UUIDs(self)->'as':return []
    @method()
    def StartDiscovery(self):
        if not self.powered:raise DBusError('org.bluez.Error.NotReady','Adapter off')
        self.discovering=True;self.emit_properties_changed({'Discovering':True});state['scanStarts']+=1;save()
    @method()
    def StopDiscovery(self):
        self.discovering=False;self.emit_properties_changed({'Discovering':False});state['scanStops']+=1;save()
    @method()
    def RemoveDevice(self,device:'o'):
        if device not in devices:raise DBusError('org.bluez.Error.DoesNotExist','Gone')
        remove(device,['org.bluez.Device1']);del devices[device];state['removes']+=1;save()

class Device(ServiceInterface):
    def __init__(self,name,address,icon,paired=False,connected=False,kind='confirm'):
        super().__init__('org.bluez.Device1')
        self.title=name;self.address=address;self.icon=icon;self.paired=paired;self.connected=connected;self.trusted=False;self.kind=kind;self.client='';self.cancelled=False;self.pairing=False
    @property
    def path(self):return '/org/bluez/hci0/dev_'+self.address.replace(':','_')
    @dbus_property(access=PropertyAccess.READ)
    def Address(self)->'s':return self.address
    @dbus_property(access=PropertyAccess.READ)
    def AddressType(self)->'s':return 'public'
    @dbus_property(access=PropertyAccess.READ)
    def Name(self)->'s':return self.title
    @dbus_property(access=PropertyAccess.READWRITE)
    def Alias(self)->'s':return self.title
    @Alias.setter
    def Alias(self,value:'s'):self.title=value;self.emit_properties_changed({'Alias':value})
    @dbus_property(access=PropertyAccess.READ)
    def Icon(self)->'s':return self.icon
    @dbus_property(access=PropertyAccess.READ)
    def Paired(self)->'b':return self.paired
    @dbus_property(access=PropertyAccess.READ)
    def Bonded(self)->'b':return self.paired
    @dbus_property(access=PropertyAccess.READ)
    def Connected(self)->'b':return self.connected
    @dbus_property(access=PropertyAccess.READWRITE)
    def Trusted(self)->'b':return self.trusted
    @Trusted.setter
    def Trusted(self,value:'b'):self.trusted=value;self.emit_properties_changed({'Trusted':value})
    @dbus_property(access=PropertyAccess.READWRITE)
    def Blocked(self)->'b':return False
    @Blocked.setter
    def Blocked(self,value:'b'):pass
    @dbus_property(access=PropertyAccess.READWRITE)
    def WakeAllowed(self)->'b':return False
    @WakeAllowed.setter
    def WakeAllowed(self,value:'b'):pass
    @dbus_property(access=PropertyAccess.READ)
    def Adapter(self)->'o':return '/org/bluez/hci0'
    @dbus_property(access=PropertyAccess.READ)
    def UUIDs(self)->'as':return []
    @dbus_property(access=PropertyAccess.READ)
    def ServicesResolved(self)->'b':return self.connected
    @dbus_property(access=PropertyAccess.READ)
    def RSSI(self)->'n':return -48
    def set_connected(self,value):self.connected=value;self.emit_properties_changed({'Connected':value,'ServicesResolved':value})
    @method()
    def Connect(self):
        if self.kind=='failure':raise DBusError('org.bluez.Error.ConnectionAttemptFailed','Synthetic failure')
        self.set_connected(True);state['connects']+=1;save()
    @method()
    def Disconnect(self):self.set_connected(False);state['disconnects']+=1;save()
    @method()
    async def Pair(self):
        if self.client not in agents:raise DBusError('org.bluez.Error.Rejected','Missing application agent')
        self.cancelled=False;self.pairing=True
        path=agents[self.client]
        member,signature,body={'confirm':('RequestConfirmation','ou',[self.path,42816]),'pin':('RequestPinCode','o',[self.path]),'passkey':('RequestPasskey','o',[self.path]),'display':('DisplayPasskey','ouq',[self.path,42816,2]),'authorize':('RequestAuthorization','o',[self.path])}[self.kind]
        reply=await bus.call(Message(destination=self.client,path=path,interface='org.bluez.Agent1',member=member,signature=signature,body=body))
        if reply.message_type==MessageType.ERROR or self.cancelled:
            self.pairing=False;raise DBusError('org.bluez.Error.AuthenticationRejected','Synthetic rejection')
        if self.kind=='pin':
            if reply.body!=['1234']:raise DBusError('org.bluez.Error.AuthenticationFailed','Invalid PIN')
            state['pin']=True
        if self.kind=='passkey':
            if reply.body!=[42816]:raise DBusError('org.bluez.Error.AuthenticationFailed','Invalid passkey')
            state['passkey']=True
        if self.kind=='display':
            for _ in range(30):
                if self.cancelled:raise DBusError('org.bluez.Error.AuthenticationCanceled','Canceled')
                await asyncio.sleep(.1)
        self.pairing=False;self.paired=True;self.emit_properties_changed({'Paired':True,'Bonded':True});state['pairs']+=1;save()
    @method()
    def CancelPairing(self):self.cancelled=True;state['cancels']+=1;save()

class Battery(ServiceInterface):
    def __init__(self):super().__init__('org.bluez.Battery1')
    @dbus_property(access=PropertyAccess.READ)
    def Percentage(self)->'y':return 84

class Manager(ServiceInterface):
    def __init__(self):super().__init__('org.bluez.AgentManager1');self.client=''
    @method()
    def RegisterAgent(self,agent:'o',capability:'s'):
        assert capability=='KeyboardDisplay'
        agents[self.client]=agent;state['agents']+=1;save()
    @method()
    def UnregisterAgent(self,agent:'o'):
        agents.pop(self.client,None);state['agents']-=1;save()
    @method()
    def RequestDefaultAgent(self,agent:'o'):state['defaultAgentCalls']+=1;save()

class Control(ServiceInterface):
    def __init__(self):super().__init__('org.island.BluetoothTest')
    @method()
    def RemoveAdapter(self):
        for path in list(devices):remove(path,['org.bluez.Device1'])
        devices.clear();remove('/org/bluez/hci0',['org.bluez.Adapter1']);save()

adapter=Adapter();manager=Manager()
devices={}
for d in [Device('Studio headphones','10:20:30:40:50:60','audio-headphones',True,True),Device('Mechanical keyboard','10:20:30:40:50:61','input-keyboard',True),Device('Pixel phone','10:20:30:40:50:62','phone'),Device('Travel mouse','10:20:30:40:50:63','input-mouse',kind='pin'),Device('Passkey device','10:20:30:40:50:64','phone',kind='passkey'),Device('Display keyboard','10:20:30:40:50:65','input-keyboard',kind='display'),Device('Game controller','10:20:30:40:50:67','input-gaming',kind='authorize'),Device('Unavailable speaker','10:20:30:40:50:66','audio-headphones',True,kind='failure')]:devices[d.path]=d

async def main():
    global bus
    bus=await MessageBus().connect()
    def sender(message):
        if message.message_type!=MessageType.METHOD_CALL:return None
        if message.interface=='org.bluez.AgentManager1':manager.client=message.sender
        if message.interface=='org.bluez.Device1' and message.path in devices:devices[message.path].client=message.sender
    bus.add_message_handler(sender)
    bus.export('/org/bluez',manager);bus.export('/org/bluez/hci0',adapter)
    for path,d in devices.items():
        bus.export(path,d)
        if d.connected:bus.export(path,Battery())
    bus.export('/org/island/test',Control())
    await bus.request_name('org.bluez')
    state['ready']=True;save()
    await asyncio.Future()
asyncio.run(main())
