"""Event-driven power-profiles-daemon adapter. Reads never change a profile.

Support modern and legacy interfaces, confirm writes, and surface daemon errors
instead of making an optimistic UI selection. No profile holds are acquired.
"""
import asyncio
import contextlib
import json
import signal
import sys

from dbus_next import DBusError, Message, Variant
from dbus_next.aio import MessageBus
from dbus_next.constants import BusType, MessageFlag, MessageType

PROVIDERS = (
    ('org.freedesktop.UPower.PowerProfiles', '/org/freedesktop/UPower/PowerProfiles'),
    ('net.hadess.PowerProfiles', '/net/hadess/PowerProfiles'),
)
PROFILES = ('power-saver', 'balanced', 'performance')


def plain(value):
    if isinstance(value, Variant): return plain(value.value)
    if isinstance(value, dict): return {k: plain(v) for k, v in value.items()}
    if isinstance(value, list): return [plain(v) for v in value]
    return value


def unavailable():
    return {'available': False, 'profile': '', 'profiles': [], 'degraded': '', 'inhibited': '', 'holds': []}


def normalize(properties):
    data = plain(properties)
    supported = [p for p in PROFILES if any(v.get('Profile') == p for v in data.get('Profiles', []) if isinstance(v, dict))]
    return {'available': bool(supported), 'profile': data.get('ActiveProfile', ''), 'profiles': supported,
            'degraded': data.get('PerformanceDegraded', ''), 'inhibited': data.get('PerformanceInhibited', ''),
            'holds': [{'profile': hold.get('Profile', ''), 'app': hold.get('ApplicationId', ''), 'reason': hold.get('Reason', '')}
                      for hold in data.get('ActiveProfileHolds', []) if isinstance(hold, dict)]}


def error_message(error):
    if isinstance(error, asyncio.TimeoutError): return 'Power-profile request timed out. Please try again.'
    name = getattr(error, 'type', '').rsplit('.', 1)[-1]
    if name in ('AccessDenied', 'NotAuthorized', 'AuthFailed'):
        return 'Permission to change the power profile was denied.'
    if name in ('ServiceUnknown', 'NameHasNoOwner', 'UnknownObject', 'Disconnected'):
        return 'The power-profile service is no longer available.'
    return 'Could not change the power profile. Check the system service and try again.'


class Watcher:
    def __init__(self, emit=None):
        self.emit = emit or (lambda **value: print(json.dumps(value), flush=True))
        self.bus = None
        self.target = None
        self.state = unavailable()
        self.last_state = None
        self.refresh_needed = asyncio.Event()
        self.stop = asyncio.Event()
        self.lock = asyncio.Lock()
        self.operation = None

    async def call(self, destination, path, interface, member, signature='', body=None, timeout=5, interactive=False):
        reply = await asyncio.wait_for(self.bus.call(Message(destination=destination, path=path, interface=interface,
            member=member, signature=signature, body=body or [],
            flags=MessageFlag.ALLOW_INTERACTIVE_AUTHORIZATION if interactive else MessageFlag.NONE)), timeout)
        if reply.message_type == MessageType.ERROR:
            raise DBusError(reply.error_name, reply.body[0] if reply.body else 'Power-profile request failed.')
        return reply.body

    def publish(self):
        if self.state != self.last_state:
            self.last_state = self.state
            self.emit(event='state', **self.state)

    async def refresh(self):
        async with self.lock:
            self.target = None
            for name, path in PROVIDERS:
                try:
                    owner = (await self.call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                        'org.freedesktop.DBus', 'GetNameOwner', 's', [name]))[0]
                    # Address the resolved unique owner so a service restart cannot
                    # validate one provider and accidentally write to its replacement.
                    props = (await self.call(owner, path, 'org.freedesktop.DBus.Properties', 'GetAll', 's', [name]))[0]
                    self.state = normalize(props)
                    self.state['provider'] = name
                    self.target = (owner, path, name)
                    self.publish()
                    return
                except (DBusError, asyncio.TimeoutError):
                    continue
            self.state = unavailable()
            self.publish()

    def message(self, msg):
        if msg.message_type != MessageType.SIGNAL: return
        if msg.interface == 'org.freedesktop.DBus' and msg.member == 'NameOwnerChanged' and msg.body[0] in [p[0] for p in PROVIDERS]:
            self.refresh_needed.set()
        elif self.target and msg.sender == self.target[0] and msg.path == self.target[1] and msg.interface == 'org.freedesktop.DBus.Properties' and msg.member == 'PropertiesChanged' and msg.body[0] == self.target[2]:
            self.refresh_needed.set()

    async def changes(self):
        while True:
            await self.refresh_needed.wait()
            self.refresh_needed.clear()
            await self.refresh()

    async def select(self, request):
        ident, profile = request.get('id'), request.get('profile')
        try:
            await self.refresh()
            if not self.target or not self.state['available']:
                raise DBusError('org.freedesktop.DBus.Error.ServiceUnknown', 'No provider')
            if profile not in self.state['profiles']:
                self.emit(event='result', id=ident, ok=False, error='This power profile is not supported by your hardware.')
                return
            if profile == 'performance' and self.state['inhibited']:
                self.emit(event='result', id=ident, ok=False, error='Performance is temporarily unavailable: ' + self.state['inhibited'])
                return
            if profile != self.state['profile']:
                owner, path, interface = self.target
                await self.call(owner, path, 'org.freedesktop.DBus.Properties', 'Set', 'ssv',
                    [interface, 'ActiveProfile', Variant('s', profile)], timeout=60, interactive=True)
                await self.refresh()
                if not self.state['available'] or self.state['profile'] != profile:
                    self.emit(event='result', id=ident, ok=False, error='The system did not keep the requested profile. Another policy may be controlling it.')
                    return
            self.emit(event='result', id=ident, ok=True)
        except (DBusError, asyncio.TimeoutError, OSError) as error:
            self.emit(event='result', id=ident, ok=False, error=error_message(error))
            self.refresh_needed.set()

    async def consume(self):
        reader = asyncio.StreamReader(limit=8192)
        transport, _ = await asyncio.get_running_loop().connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
        try:
            while True:
                line = await reader.readline()
                if not line: return
                try:
                    request = json.loads(line)
                    if not isinstance(request, dict): continue
                    if self.operation is None or self.operation.done(): self.operation = asyncio.create_task(self.select(request))
                    else: self.emit(event='result', id=request.get('id'), ok=False, error='A power-profile request is already running.')
                except (ValueError, TypeError):
                    continue
        finally:
            transport.close()
            self.stop.set()

    async def run(self):
        tasks = []
        loop = asyncio.get_running_loop()
        for signum in (signal.SIGTERM, signal.SIGINT): loop.add_signal_handler(signum, self.stop.set)
        try:
            self.bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
            self.bus.add_message_handler(self.message)
            for name, path in PROVIDERS:
                for rule in (f"type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='{name}'",
                             f"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='{path}',arg0='{name}'"):
                    await self.call('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'AddMatch', 's', [rule])
            await self.refresh()
            tasks = [asyncio.create_task(self.changes()), asyncio.create_task(self.consume())]
            await self.stop.wait()
        except (DBusError, OSError, asyncio.TimeoutError):
            self.state = unavailable(); self.publish()
        finally:
            if self.operation: tasks.append(self.operation)
            for task in tasks: task.cancel()
            for task in tasks:
                with contextlib.suppress(asyncio.CancelledError): await task
            if self.bus: self.bus.disconnect()


def main():
    asyncio.run(Watcher().run())
