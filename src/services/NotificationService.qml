import QtQuick
import Quickshell.Services.Notifications
import "../core"

Item {
    id: root
    property bool blocked: false
    property bool suppressed: false
    property bool dnd: false
    property var records: []
    property var queue: []
    property var popup: null
    property double popupUntil: 0
    property var live: ({})
    property int nextDemo: -1
    readonly property int unread: records.filter(r => !r.read).length
    readonly property var history: records.filter(r => !r.transient).slice().reverse()
    onBlockedChanged: Qt.callLater(pump)
    onSuppressedChanged: Qt.callLater(() => { if (suppressed) { popup = null; queue = []; } else pump(); })
    onDndChanged: { if (dnd) { popup = null; queue = []; } }
    function receive(n) {
        n.tracked = true;
        const id = n.id;
        if (!live[id]) {
            n.closed.connect(function () { root.closed(id); });
            // Native replacements emit property changes, not NotificationServer.notification.
            // Defer until all properties in the DBus update have been applied.
            const updateLater = function () { if (root.live[id]) root.update(root.live[id], false); };
            const refresh = function () { Qt.callLater(updateLater); };
            for (const signal of [n.summaryChanged, n.bodyChanged, n.appNameChanged,
                n.appIconChanged, n.actionsChanged, n.expireTimeoutChanged, n.urgencyChanged, n.transientChanged]) signal.connect(refresh);
        }
        live[id] = n;
        update(n, true);
    }
    function update(n, announce) {
        // 0.3.2 exposes the DBus value in milliseconds despite the header saying seconds.
        const duration = n.expireTimeout > 0 ? n.expireTimeout : 5000;
        const persistent = n.expireTimeout === 0 || (n.expireTimeout < 0 && n.urgency === 2);
        const r = {id: n.id, app: n.appName || "Notification", icon: n.appIcon,
            summary: n.summary, body: n.body, transient: n.transient, read: false,
            urgency: n.urgency, time: Date.now(), live: true,
            deadline: persistent ? 0 : Date.now() + duration,
            actions: n.actions.map(a => ({id: a.identifier, text: a.text}))};
        put(r, announce);
    }
    function put(record, announce) {
        const copy = records.filter(r => r.id !== record.id);
        copy.push(record);
        const evicted = copy.slice(0, Math.max(0, copy.length - 200));
        records = copy.slice(-200);
        for (const old of evicted) Qt.callLater(() => { if (live[old.id]) live[old.id].expire(); else closed(old.id); });
        if (popup && popup.id === record.id) { popup = record; popupUntil = record.deadline; }
        if (announce && !dnd && !suppressed) {
            if (!queue.includes(record.id) && (!popup || popup.id !== record.id)) queue = queue.concat([record.id]);
            pump();
        }
    }
    function pump() {
        if (blocked || suppressed || dnd || popup) return;
        const now = Date.now();
        while (queue.length) {
            const id = queue[0]; queue = queue.slice(1);
            const r = records.find(r => r.id === id);
            if (r && r.live && (!r.deadline || r.deadline > now)) {
                popup = r; popupUntil = r.deadline; break;
            }
        }
    }
    function closed(id) {
        delete live[id];
        records = records.filter(r => r.id !== id || !r.transient).map(r => r.id === id ? Object.assign({}, r, {live: false, actions: []}) : r);
        queue = queue.filter(value => value !== id);
        if (popup && popup.id === id) popup = null;
        pump();
    }
    function dismiss(id) {
        if (live[id]) live[id].dismiss();
        records = records.filter(r => r.id !== id);
        queue = queue.filter(value => value !== id);
        if (popup && popup.id === id) popup = null;
        pump();
    }
    function clear() { for (const r of records.slice()) dismiss(r.id); }
    function markRead() { records = records.map(r => Object.assign({}, r, {read: true})); }
    function invoke(id, actionId) {
        const n = live[id];
        if (!n) return;
        const resident = n.resident;
        const action = n.actions.find(a => a.identifier === actionId);
        if (action) action.invoke();
        if (!resident && live[id]) dismiss(id);
    }
    function tick() {
        const now = Date.now();
        for (const r of records.slice()) {
            if (r.live && r.deadline && r.deadline <= now) {
                if (live[r.id]) live[r.id].expire(); else closed(r.id);
            }
        }
        if (popup && popupUntil && popupUntil <= now) popup = null;
        pump();
    }
    function demo() {
        const id = nextDemo--;
        put({id: id, app: "Messages", icon: "", summary: "Natalie", body: "Are you up for a walk?", transient: false,
            read: false, urgency: 1, time: Date.now(), live: true, deadline: Date.now() + 5000, actions: []}, true);
    }
    function systemError(message) {
        put({id: nextDemo--, app: "Island", icon: "", summary: "Session action failed", body: message,
            transient: false, read: false, urgency: 2, time: Date.now(), live: true,
            deadline: Date.now() + 8000, actions: []}, true);
    }
    Timer { interval: 250; running: root.records.some(r => r.live && r.deadline > 0); repeat: true; onTriggered: root.tick() }
    Loader {
        active: Settings.notificationsEnabled
        sourceComponent: Component {
            NotificationServer {
                keepOnReload: false
                persistenceSupported: true
                bodySupported: true
                bodyMarkupSupported: false
                actionsSupported: true
                imageSupported: true
                onNotification: notification => root.receive(notification)
            }
        }
    }
}
