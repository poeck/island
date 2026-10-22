import QtQuick
import Quickshell
import Quickshell.Io
import "services"
ShellRoot {
    NotificationService { id: service }
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({records: service.records, history: service.history, popup: service.popup, queue: service.queue}); }
        function block(value: bool): void { service.blocked = value; }
        function suppress(value: bool): void { service.suppressed = value; }
        function dnd(value: bool): void { service.dnd = value; }
        function clear(): void { service.clear(); }
        function invoke(id: int, action: string): void { service.invoke(id, action); }
    }
}
