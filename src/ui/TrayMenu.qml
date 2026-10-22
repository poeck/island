import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import "../core"

Menu {
    id: root
    property QsMenuHandle handle: null
    // A real popup window keeps menus outside the bar's clipped 40 px surface.
    // Qt owns the popup grab, keyboard navigation and edge-aware submenu placement.
    popupType: Popup.Window
    padding: Theme.trayMenuPadding
    margins: 6
    overlap: 0
    cascade: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    readonly property real entryWidth: {
        let widest = 0;
        for (let i = 0; i < count; i++) widest = Math.max(widest, itemAt(i)?.implicitWidth || 0);
        return widest;
    }
    implicitWidth: Math.min(360, Math.max(220, entryWidth + 2 * padding))
    delegate: TrayMenuItem {}
    background: Rectangle {
        color: Theme.surface
        radius: Theme.trayMenuRadius
        border.color: Theme.borderStrong
    }
    // Opener lifetime also communicates opening/closing to the application's
    // DBusMenu, including menus populated only when they are opened.
    QsMenuOpener { id: opener; menu: root.visible ? root.handle : null }
    function insertNode(index: int, node: var): void { node.insert(index); }
    function removeNode(node: var): void { node.remove(); }
    readonly property Component submenuFactory: Qt.createComponent("TrayMenu.qml")
    Instantiator {
        model: opener.children
        delegate: QtObject {
            id: node
            required property var modelData
            property var item: null
            property bool submenu: false
            function insert(index) {
                if (modelData.isSeparator) {
                    item = separatorComponent.createObject(root.contentItem);
                    root.insertItem(index, item);
                } else if (modelData.hasChildren) {
                    submenu = true;
                    item = root.submenuFactory.createObject(root, {
                        handle: modelData,
                        title: Qt.binding(() => node.modelData.text),
                        enabled: Qt.binding(() => node.modelData.enabled)
                    });
                    root.insertMenu(index, item);
                } else {
                    item = actionComponent.createObject(root.contentItem, {entry: modelData});
                    root.insertItem(index, item);
                }
            }
            function remove() {
                if (!item) return;
                if (submenu) root.removeMenu(item);
                else root.removeItem(item);
                item.destroy();
            }
        }
        onObjectAdded: (index, object) => root.insertNode(index, object)
        onObjectRemoved: (index, object) => root.removeNode(object)
    }
    Component { id: actionComponent; TrayMenuItem {} }
    Component {
        id: separatorComponent
        MenuSeparator {
            verticalPadding: 6
            contentItem: Rectangle { implicitHeight: 1; color: Theme.border }
        }
    }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Settings.reducedMotion ? 0 : 100 }
    }
    exit: Transition {}
}
