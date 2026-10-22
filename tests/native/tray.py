"""Real StatusNotifierItem and DBusMenu fixtures on the disposable session bus."""
import asyncio
import json
from pathlib import Path
import sys

from dbus_next import Variant
from dbus_next.aio import MessageBus
from dbus_next.constants import PropertyAccess
from dbus_next.service import ServiceInterface, dbus_property, method, signal

state_path = Path(sys.argv[1])
state = {'ready': False, 'activate': 0, 'secondary': 0, 'scroll': [], 'menuOpens': 0, 'menuClicks': 0, 'clickedIds': []}

def save():
    state_path.write_text(json.dumps(state))

class TrayItem(ServiceInterface):
    def __init__(self, menu_only=False):
        super().__init__('org.kde.StatusNotifierItem')
        self.menu_only = menu_only
        self.status = 'Active'

    @dbus_property(access=PropertyAccess.READ)
    def Id(self) -> 's': return 'island-menu-only' if self.menu_only else 'island-fixture'
    @dbus_property(access=PropertyAccess.READ)
    def Title(self) -> 's': return 'Island tray fixture'
    @dbus_property(access=PropertyAccess.READ)
    def Category(self) -> 's': return 'ApplicationStatus'
    @dbus_property(access=PropertyAccess.READ)
    def Status(self) -> 's': return self.status
    @dbus_property(access=PropertyAccess.READ)
    def WindowId(self) -> 'u': return 0
    @dbus_property(access=PropertyAccess.READ)
    def IconName(self) -> 's': return ''
    @dbus_property(access=PropertyAccess.READ)
    def IconPixmap(self) -> 'a(iiay)':
        color = bytes([255, 242, 154, 164] if self.menu_only else [255, 164, 235, 217])
        return [[16, 16, color * 256]]
    @dbus_property(access=PropertyAccess.READ)
    def AttentionIconName(self) -> 's': return ''
    @dbus_property(access=PropertyAccess.READ)
    def AttentionIconPixmap(self) -> 'a(iiay)': return self.IconPixmap
    @dbus_property(access=PropertyAccess.READ)
    def OverlayIconName(self) -> 's': return ''
    @dbus_property(access=PropertyAccess.READ)
    def OverlayIconPixmap(self) -> 'a(iiay)': return []
    @dbus_property(access=PropertyAccess.READ)
    def ToolTip(self) -> '(sa(iiay)ss)': return ['', [], 'Island fixture', 'Native tray tooltip']
    @dbus_property(access=PropertyAccess.READ)
    def ItemIsMenu(self) -> 'b': return self.menu_only
    @dbus_property(access=PropertyAccess.READ)
    def Menu(self) -> 'o': return '/MenuBar'
    @signal()
    def NewStatus(self, status: 's') -> 's': return status
    @method()
    def Activate(self, x: 'i', y: 'i'):
        state['activate'] += 1; save()
    @method()
    def SecondaryActivate(self, x: 'i', y: 'i'):
        state['secondary'] += 1; save()
    @method()
    def ContextMenu(self, x: 'i', y: 'i'): pass
    @method()
    def Scroll(self, delta: 'i', orientation: 's'):
        state['scroll'].append([delta, orientation]); save()

class Menu(ServiceInterface):
    def __init__(self):
        super().__init__('com.canonical.dbusmenu')
        self.checked = True
    def properties(self, entry):
        props = {'label': Variant('s', {1: 'Open application', 3: 'Notifications', 4: 'Available', 5: 'Unavailable action', 6: 'More options', 7: 'Nested action'}.get(entry, '')),
                 'enabled': Variant('b', entry != 5), 'visible': Variant('b', True)}
        if entry == 2: props['type'] = Variant('s', 'separator')
        if entry in (3, 4):
            props.update({'toggle-type': Variant('s', 'checkmark' if entry == 3 else 'radio'), 'toggle-state': Variant('i', int(self.checked) if entry == 3 else 1)})
        if entry == 6: props['children-display'] = Variant('s', 'submenu')
        return props
    @signal()
    def ItemsPropertiesUpdated(self, updated: 'a(ia{sv})', removed: 'a(ias)') -> 'a(ia{sv})a(ias)': return [updated, removed]
    @dbus_property(access=PropertyAccess.READ)
    def Version(self) -> 'u': return 3
    @dbus_property(access=PropertyAccess.READ)
    def TextDirection(self) -> 's': return 'ltr'
    @dbus_property(access=PropertyAccess.READ)
    def Status(self) -> 's': return 'normal'
    @dbus_property(access=PropertyAccess.READ)
    def IconThemePath(self) -> 'as': return []
    @method()
    def GetLayout(self, parent: 'i', depth: 'i', properties: 'as') -> 'u(ia{sv}av)':
        def layout(entry, remaining):
            children = range(1, 7) if entry == 0 else [7] if entry == 6 else []
            return [entry, self.properties(entry) if entry else {},
                    [Variant('(ia{sv}av)', layout(child, remaining - 1)) for child in children] if remaining != 0 else []]
        return [1, layout(parent, depth)]
    @method()
    def GetGroupProperties(self, ids: 'ai', names: 'as') -> 'a(ia{sv})': return [[entry, self.properties(entry)] for entry in ids]
    @method()
    def AboutToShow(self, entry: 'i') -> 'b':
        state['menuOpens'] += 1; save(); return False
    @method()
    def Event(self, entry: 'i', event: 's', data: 'v', timestamp: 'u'):
        if event == 'clicked':
            state['menuClicks'] += 1; state['clickedIds'].append(entry); save()
            if entry == 3:
                self.checked = not self.checked
                self.ItemsPropertiesUpdated([[3, {'toggle-state': Variant('i', int(self.checked))}]], [])

class Control(ServiceInterface):
    def __init__(self, bus, watcher, item):
        super().__init__('org.island.TrayFixture')
        self.bus, self.watcher, self.item = bus, watcher, item
        self.extra_buses = []
    @method()
    def SetStatus(self, status: 's'):
        self.item.status = status
        self.item.emit_properties_changed({'Status': status})
        self.item.NewStatus(status)
    @method()
    async def AddMenuOnly(self):
        self.menu_bus = await MessageBus().connect()
        self.menu_bus.export('/StatusNotifierItem', TrayItem(True))
        self.menu_bus.export('/MenuBar', Menu())
        await self.menu_bus.request_name('org.island.TrayFixture.MenuOnly')
        await self.watcher.call_register_status_notifier_item('org.island.TrayFixture.MenuOnly')

    @method()
    async def AddItems(self, count: 'u'):
        for _ in range(min(count, 64)):
            extra = await MessageBus().connect()
            extra.export('/StatusNotifierItem', TrayItem())
            extra.export('/MenuBar', Menu())
            name = 'org.island.TrayFixture.Extra' + str(len(self.extra_buses))
            await extra.request_name(name)
            await self.watcher.call_register_status_notifier_item(name)
            self.extra_buses.append(extra)

async def main():
    bus = await MessageBus().connect()
    await bus.request_name('org.island.TrayFixture')
    introspection = await bus.introspect('org.kde.StatusNotifierWatcher', '/StatusNotifierWatcher')
    watcher = bus.get_proxy_object('org.kde.StatusNotifierWatcher', '/StatusNotifierWatcher', introspection).get_interface('org.kde.StatusNotifierWatcher')
    item = TrayItem()
    bus.export('/StatusNotifierItem', item)
    bus.export('/MenuBar', Menu())
    bus.export('/Control', Control(bus, watcher, item))
    await watcher.call_register_status_notifier_item('org.island.TrayFixture')
    state['ready'] = True; save()
    await asyncio.Future()

asyncio.run(main())
