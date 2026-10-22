"""Scoped BlueZ actions and an application pairing agent over private stdio.

No default-agent takeover, shell commands, secret files or public credential IPC.
Native Quickshell objects remain the source of truth for device status.
"""
import asyncio
import contextlib
import json
import signal
import sys

from dbus_next import DBusError, Message, Variant
from dbus_next.aio import MessageBus
from dbus_next.constants import BusType, MessageType
from dbus_next.service import ServiceInterface, method

AGENT = '/org/island/agent'
BLUEZ = 'org.bluez'
ERRORS = {
    'NotReady': 'Bluetooth is off or blocked by the hardware switch.',
    'NotAuthorized': 'Bluetooth permission was denied.',
    'AuthenticationCanceled': 'Pairing canceled.',
    'AuthenticationRejected': 'Pairing was rejected. Try again on both devices.',
    'AuthenticationFailed': 'Pairing failed. Check the PIN or passkey and retry.',
    'AuthenticationTimeout': 'Pairing timed out. Put the device in pairing mode and retry.',
    'ConnectionAttemptFailed': 'Connection failed. Check that the device is nearby and ready.',
    'InProgress': 'Another Bluetooth operation is already running.',
    'DoesNotExist': 'The device or adapter is no longer available.',
    'UnknownObject': 'The device or adapter was removed.',
    'ServiceUnknown': 'The Bluetooth service is unavailable.',
    'NameHasNoOwner': 'The Bluetooth service is unavailable.',
    'NoReply': 'The Bluetooth service did not respond.',
}

def error_message(error):
    if isinstance(error, (asyncio.TimeoutError, TimeoutError)):
        return 'Bluetooth request timed out. Check the device and try again.'
    suffix = getattr(error, 'type', '').rsplit('.', 1)[-1]
    return ERRORS.get(suffix, 'Bluetooth request failed. Check the device and try again.')


class Agent(ServiceInterface):
    def __init__(self, bridge):
        super().__init__('org.bluez.Agent1')
        self.bridge = bridge
        self.response = None
        self.token = 0

    def allowed(self, device):
        if device != self.bridge.pairing_path or not device:
            raise DBusError('org.bluez.Error.Rejected', 'No pairing was requested for this device.')

    async def request(self, kind, device, **extra):
        self.allowed(device)
        if self.response and not self.response.done():
            raise DBusError('org.bluez.Error.InProgress', 'An agent request is already pending.')
        self.token += 1
        self.response = asyncio.get_running_loop().create_future()
        self.bridge.emit(event='prompt', kind=kind, device=device, token=self.token, **extra)
        try:
            value = await asyncio.wait_for(self.response, 45)
            if value is None:
                raise DBusError('org.bluez.Error.Rejected', 'User canceled pairing.')
            return value
        except asyncio.TimeoutError:
            raise DBusError('org.bluez.Error.Canceled', 'Pairing prompt timed out.')
        finally:
            self.response = None
            self.bridge.emit(event='prompt-clear')

    def respond(self, value):
        if self.response and not self.response.done():
            self.response.set_result(value)

    def clear(self):
        self.respond(None)
        self.bridge.emit(event='prompt-clear')

    @method()
    def Release(self):
        self.clear()

    @method()
    async def RequestPinCode(self, device: 'o') -> 's':
        value = await self.request('pin', device)
        if not isinstance(value, str) or not 1 <= len(value) <= 16 or not value.isascii() or not value.isalnum():
            raise DBusError('org.bluez.Error.Rejected', 'PIN must be 1–16 alphanumeric characters.')
        return value

    @method()
    def DisplayPinCode(self, device: 'o', pincode: 's'):
        self.allowed(device)
        self.bridge.emit(event='prompt', kind='display', device=device, code=pincode, entered=0)

    @method()
    async def RequestPasskey(self, device: 'o') -> 'u':
        value = await self.request('passkey', device)
        if not isinstance(value, str) or not value.isascii() or not value.isdigit() or not 1 <= len(value) <= 6:
            raise DBusError('org.bluez.Error.Rejected', 'Passkey must be 0–999999.')
        return int(value)

    @method()
    def DisplayPasskey(self, device: 'o', passkey: 'u', entered: 'q'):
        self.allowed(device)
        self.bridge.emit(event='prompt', kind='display', device=device, code=f'{passkey:06d}', entered=entered)

    @method()
    async def RequestConfirmation(self, device: 'o', passkey: 'u'):
        if await self.request('confirm', device, code=f'{passkey:06d}') is not True:
            raise DBusError('org.bluez.Error.Rejected', 'Confirmation was not approved.')

    @method()
    async def RequestAuthorization(self, device: 'o'):
        if await self.request('authorize', device) is not True:
            raise DBusError('org.bluez.Error.Rejected', 'Authorization was not approved.')

    @method()
    async def AuthorizeService(self, device: 'o', uuid: 's'):
        if await self.request('authorize', device, service=uuid) is not True:
            raise DBusError('org.bluez.Error.Rejected', 'Service was not approved.')

    @method()
    def Cancel(self):
        self.clear()


class Bridge:
    def __init__(self, emit=None):
        self.emit = emit or (lambda **value: print(json.dumps(value), flush=True))
        self.bus = None
        self.owner = ''
        self.agent = Agent(self)
        self.registered = False
        self.pairing_path = ''
        self.scans = {}
        self.operation = None
        self.stop = asyncio.Event()

    async def call(self, path, interface, member, signature='', body=None, timeout=8):
        reply = await asyncio.wait_for(self.bus.call(Message(destination=BLUEZ, path=path, interface=interface,
                                                              member=member, signature=signature, body=body or [])), timeout)
        if reply.message_type == MessageType.ERROR:
            raise DBusError(reply.error_name, reply.body[0] if reply.body else 'Bluetooth request failed.')
        return reply.body

    async def objects(self):
        return (await self.call('/', 'org.freedesktop.DBus.ObjectManager', 'GetManagedObjects'))[0]

    def filter_agent_sender(self, message):
        # The agent is exported on the system bus; only bluetoothd may invoke it.
        if message.message_type == MessageType.METHOD_CALL and message.path == AGENT and message.interface == 'org.bluez.Agent1' and message.sender != self.owner:
            return Message.new_error(message, 'org.bluez.Error.Rejected', 'Only BlueZ may call this agent.')
        return None

    async def start(self):
        self.bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
        response = await self.bus.call(Message(destination='org.freedesktop.DBus', path='/org/freedesktop/DBus',
                                             interface='org.freedesktop.DBus', member='GetNameOwner', signature='s', body=[BLUEZ]))
        if response.message_type == MessageType.ERROR:
            raise DBusError(response.error_name, 'Bluetooth service unavailable.')
        self.owner = response.body[0]
        self.bus.add_message_handler(self.filter_agent_sender)
        self.bus.export(AGENT, self.agent)
        self.emit(event='ready')

    async def set_property(self, path, interface, prop, signature, value):
        await self.call(path, 'org.freedesktop.DBus.Properties', 'Set', 'ssv', [interface, prop, Variant(signature, value)])

    async def stop_scan(self, path):
        task = self.scans.pop(path, None)
        if task:
            if task is not asyncio.current_task():
                task.cancel()
            with contextlib.suppress(DBusError, asyncio.TimeoutError):
                await self.call(path, 'org.bluez.Adapter1', 'StopDiscovery')
        self.emit(event='scan', paths=list(self.scans))

    async def scan_timeout(self, path):
        await asyncio.sleep(20)
        await self.stop_scan(path)

    async def cancel_pairing(self):
        self.agent.clear()
        if self.pairing_path:
            with contextlib.suppress(DBusError, asyncio.TimeoutError):
                await self.call(self.pairing_path, 'org.bluez.Device1', 'CancelPairing', timeout=2)

    async def action(self, request):
        ident = request.get('id')
        action, path, value = request.get('action'), request.get('path'), request.get('value')
        try:
            objects = await self.objects()
            if not isinstance(path, str) or path not in objects:
                raise DBusError('org.bluez.Error.DoesNotExist', 'Object no longer exists.')
            device = objects[path].get('org.bluez.Device1')
            adapter = objects[path].get('org.bluez.Adapter1')
            if action in ('power', 'visible', 'scan', 'stop-scan') and adapter is not None:
                if action in ('power', 'visible') and not isinstance(value, bool):
                    raise ValueError('Invalid adapter value')
                if action == 'power':
                    if not value: await self.stop_scan(path)
                    await self.set_property(path, 'org.bluez.Adapter1', 'Powered', 'b', value)
                elif action == 'visible':
                    if value: await self.set_property(path, 'org.bluez.Adapter1', 'DiscoverableTimeout', 'u', 120)
                    await self.set_property(path, 'org.bluez.Adapter1', 'Discoverable', 'b', value)
                elif action == 'scan' and path not in self.scans:
                    await self.call(path, 'org.bluez.Adapter1', 'StartDiscovery')
                    self.scans[path] = asyncio.create_task(self.scan_timeout(path))
                    self.emit(event='scan', paths=list(self.scans))
                elif action == 'stop-scan': await self.stop_scan(path)
            elif device is not None and action in ('connect', 'disconnect', 'pair', 'forget', 'trust'):
                if action == 'pair':
                    if not self.registered:
                        await self.call('/org/bluez', 'org.bluez.AgentManager1', 'RegisterAgent', 'os', [AGENT, 'KeyboardDisplay'])
                        self.registered = True
                    self.pairing_path = path
                    await self.call(path, 'org.bluez.Device1', 'Pair', timeout=60)
                    self.agent.clear()
                    # Pairing alone does not mark the device trusted. Connect only
                    # after a successful bond requested by this user.
                    await self.call(path, 'org.bluez.Device1', 'Connect', timeout=15)
                elif action == 'forget':
                    await self.call(device['Adapter'].value, 'org.bluez.Adapter1', 'RemoveDevice', 'o', [path])
                elif action == 'trust':
                    if not isinstance(value, bool): raise ValueError('Invalid trust value')
                    await self.set_property(path, 'org.bluez.Device1', 'Trusted', 'b', value)
                else:
                    await self.call(path, 'org.bluez.Device1', 'Connect' if action == 'connect' else 'Disconnect', timeout=15)
            else:
                raise ValueError('Unsupported Bluetooth action')
            self.emit(event='done', id=ident, ok=True)
        except (DBusError, asyncio.TimeoutError, ValueError, OSError) as error:
            if action == 'pair': await self.cancel_pairing()
            self.emit(event='done', id=ident, ok=False, error=error_message(error))
        finally:
            self.pairing_path = ''
            self.agent.clear()

    async def consume(self):
        reader = asyncio.StreamReader(limit=16384)
        protocol = asyncio.StreamReaderProtocol(reader)
        transport, _ = await asyncio.get_running_loop().connect_read_pipe(lambda: protocol, sys.stdin)
        try:
            while not self.stop.is_set():
                raw = await reader.readline()
                if not raw: break
                try:
                    request = json.loads(raw)
                    if not isinstance(request, dict): continue
                    if request.get('action') == 'reply':
                        if request.get('token') == self.agent.token:
                            self.agent.respond(request.get('value'))
                    elif request.get('action') == 'cancel':
                        await self.cancel_pairing()
                    elif self.operation is None or self.operation.done():
                        self.operation = asyncio.create_task(self.action(request))
                    else:
                        self.emit(event='done', id=request.get('id'), ok=False, error='Another Bluetooth request is running.')
                except (ValueError, TypeError):
                    self.emit(event='error', error='Invalid Bluetooth request.')
        finally:
            transport.close()
            self.stop.set()

    async def close(self):
        await self.cancel_pairing()
        if self.operation and not self.operation.done():
            self.operation.cancel()
            with contextlib.suppress(asyncio.CancelledError): await self.operation
        for path in list(self.scans): await self.stop_scan(path)
        if self.registered:
            with contextlib.suppress(DBusError, asyncio.TimeoutError):
                await self.call('/org/bluez', 'org.bluez.AgentManager1', 'UnregisterAgent', 'o', [AGENT], timeout=2)
        if self.bus:
            self.bus.disconnect()


async def main_async():
    bridge = Bridge()
    consumer = None
    loop = asyncio.get_running_loop()
    for signum in (signal.SIGTERM, signal.SIGINT): loop.add_signal_handler(signum, bridge.stop.set)
    try:
        await bridge.start()
        consumer = asyncio.create_task(bridge.consume())
        await bridge.stop.wait()
    except (DBusError, OSError, asyncio.TimeoutError):
        bridge.emit(event='error', error='The Bluetooth service is unavailable. Check that BlueZ is running.')
    finally:
        if consumer: consumer.cancel()
        if bridge.bus: await bridge.close()


def main():
    asyncio.run(main_async())
