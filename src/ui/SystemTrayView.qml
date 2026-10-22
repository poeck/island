import QtQuick
import QtQuick.Controls.Basic
import Quickshell.Services.SystemTray
import "../core"

Item {
    id: root
    property bool active: true
    property var currentMenu: null
    property bool opening: false
    readonly property bool expanded: drawer.visible
    readonly property bool keyboardWanted: active && (opening || drawer.visible || currentMenu !== null)
    // Read-only geometry for diagnostics and native input checks. Popup windows
    // may be repositioned by Qt/compositor constraints, so use mapped positions.
    function geometry() {
        function rect(item) {
            const p = item.mapToGlobal(0, 0);
            return {x: p.x, y: p.y, width: item.width, height: item.height};
        }
        function rows(menu) {
            const result = [];
            if (!menu || !menu.visible) return result;
            for (let i = 0; i < menu.count; i++) {
                const item = menu.itemAt(i);
                result.push(Object.assign({text: item.text || "", children: rows(menu.menuAt(i))}, rect(item)));
            }
            return result;
        }
        const items = [];
        for (let i = 0; i < buttons.count; i++) {
            const item = buttons.itemAt(i);
            items.push(Object.assign({id: item.modelData.id, attention: item.modelData.status === Status.NeedsAttention}, rect(item)));
        }
        return {items: items, menu: rows(currentMenu)};
    }
    function dismiss() {
        opening = false;
        drawerArm.stop();
        menuArm.stop();
        if (currentMenu && currentMenu.visible) currentMenu.dismiss();
        currentMenu = null;
        drawer.close();
    }
    function toggle() {
        if (opening || drawer.visible) dismiss();
        else if (!closeGuard.running) { opening = true; drawerArm.restart(); }
    }
    function focusItem(index) {
        const count = buttons.count;
        if (!count) return;
        const item = buttons.itemAt((index + count) % count);
        item.forceActiveFocus(Qt.TabFocusReason);
        viewport.contentY = Math.max(0, Math.min(item.y, Math.max(0, grid.height - viewport.height)));
    }
    function showMenu(menu) {
        if (currentMenu && currentMenu.visible) currentMenu.dismiss();
        currentMenu = menu;
        menuArm.restart();
    }
    onActiveChanged: if (!active) dismiss()
    onItemsChanged: if (!items.length) dismiss()
    // Commit keyboard interactivity before mapping the Wayland popup. Otherwise
    // an idle bar with no previous keyboard focus cannot give its menu the grab.
    Timer { id: menuArm; interval: 32; onTriggered: if (root.active && root.currentMenu) root.currentMenu.open() }
    // Qt can replay the outside press onto the chevron after closing a popup.
    // Consume that same click rather than immediately reopening the grid.
    Timer { id: closeGuard; interval: 150 }
    Timer {
        id: drawerArm; interval: 32
        onTriggered: {
            root.opening = false;
            if (root.active && root.items.length) drawer.open();
        }
    }
    readonly property var items: SystemTray.items.values.filter(item => item.status !== Status.Passive)
    readonly property bool attention: items.some(item => item.status === Status.NeedsAttention)
    visible: items.length > 0
    width: visible ? 30 : 0
    height: Theme.barHeight
    BarButton {
        id: toggleButton
        anchors.fill: parent
        selected: drawer.visible || root.opening
        iconName: "chevron-left"
        enabled: root.active
        Accessible.name: drawer.visible ? "Hide system tray" : "Show system tray"
        Accessible.description: root.items.length + " applications" + (root.attention ? ", attention requested" : "")
        contentItem: Icon {
            name: "chevron-left"
            color: toggleButton.hovered || toggleButton.selected ? Theme.text : Theme.secondary
            rotation: toggleButton.selected ? 90 : -90
            Behavior on rotation { NumberAnimation { duration: Settings.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
        }
        onClicked: root.toggle()
        Rectangle {
            x: parent.width - 6; y: 4; width: 4; height: 4; radius: 2
            color: Theme.accent
            visible: root.attention && !drawer.visible
        }
    }
    Menu {
        id: drawer
        popupType: Popup.Window
        x: root.width - width; y: Theme.barHeight + 6
        padding: 10; margins: -1
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        implicitWidth: grid.implicitWidth + 2 * padding
        implicitHeight: Math.min(320, grid.implicitHeight) + 2 * padding
        onOpened: Qt.callLater(() => { if (drawer.visible) root.focusItem(0); })
        onClosed: {
            closeGuard.restart();
            menuArm.stop();
            if (root.currentMenu && root.currentMenu.visible) root.currentMenu.dismiss();
            root.currentMenu = null;
        }
        background: Rectangle {
            color: Theme.background
            radius: Theme.radiusCard
            border.color: Theme.borderStrong
        }
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Settings.reducedMotion ? 0 : 100 }
        }
        exit: Transition {}
        contentItem: Flickable {
            id: viewport
            contentWidth: grid.implicitWidth
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Grid {
                id: grid
                columns: Math.min(4, Math.max(1, root.items.length))
                spacing: Theme.traySpacing
                Repeater {
                    id: buttons
                    model: root.items
                    delegate: Rectangle {
                        id: button
                        required property var modelData
                        required property int index
                        readonly property string tooltip: [modelData.tooltipTitle || modelData.title || modelData.id, modelData.tooltipDescription].filter(Boolean).join("\n")
                        width: Theme.trayCellSize; height: width
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: tooltip
                        Accessible.onPressAction: activate(Qt.LeftButton)
                        function activate(which) {
                            if (which === Qt.RightButton || (which === Qt.LeftButton && modelData.onlyMenu)) {
                                if (modelData.hasMenu) root.showMenu(menu);
                            } else if (which === Qt.MiddleButton) modelData.secondaryActivate();
                            else modelData.activate();
                        }
                        Keys.onLeftPressed: root.focusItem(index - 1)
                        Keys.onRightPressed: root.focusItem(index + 1)
                        Keys.onUpPressed: root.focusItem(index - grid.columns)
                        Keys.onDownPressed: root.focusItem(index + grid.columns)
                        Keys.onReturnPressed: activate(Qt.LeftButton)
                        Keys.onEnterPressed: activate(Qt.LeftButton)
                        Keys.onSpacePressed: activate(Qt.LeftButton)
                        Keys.onMenuPressed: activate(Qt.RightButton)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)) {
                                activate(Qt.RightButton); event.accepted = true;
                            }
                        }
                        radius: Theme.radiusSmall
                        border.color: activeFocus ? Theme.secondary : "transparent"
                        color: menu.visible ? Theme.selection : mouse.containsMouse ? Theme.raised : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
                        enabled: root.active && drawer.visible
                        onEnabledChanged: if (!enabled) {
                            if (menu && menu.visible) menu.dismiss();
                            if (tipDelay) tipDelay.stop();
                            if (tip) tip.visible = false;
                        }
                        Image {
                            id: trayIcon
                            anchors.centerIn: parent
                            width: Theme.trayIconSize; height: width
                            source: button.modelData.icon
                            sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                            fillMode: Image.PreserveAspectFit
                        }
                        Icon { anchors.centerIn: parent; width: Theme.trayIconSize; height: width; name: "app"; color: Theme.secondary; visible: trayIcon.status !== Image.Ready }
                        Rectangle {
                            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 2; bottomMargin: 1 }
                            width: 4; height: width; radius: width / 2
                            color: Theme.accent
                            visible: button.modelData.status === Status.NeedsAttention
                        }
                        TrayMenu {
                            id: menu
                            handle: button.modelData.menu
                            x: button.width - width
                            y: button.height + 4
                            onClosed: if (root.currentMenu === menu) root.currentMenu = null
                            Component.onDestruction: if (root.currentMenu === menu) root.currentMenu = null
                        }
                        Timer { id: tipDelay; interval: 700; onTriggered: if (mouse.containsMouse && button.enabled) tip.visible = true }
                        ToolTip {
                            id: tip
                            popupType: Popup.Window
                            visible: false
                            x: button.width - width; y: button.height + 4
                            padding: 8
                            implicitWidth: Math.min(320, tipText.implicitWidth + 16)
                            implicitHeight: tipText.implicitHeight + 16
                            closePolicy: Popup.NoAutoClose
                            background: Rectangle {
                                color: Theme.surface; radius: Theme.radiusSmall; border.color: Theme.borderStrong
                            }
                            contentItem: Label {
                                id: tipText
                                text: button.tooltip; font.pixelSize: Theme.textSmall
                                wrapMode: Text.Wrap; elide: Text.ElideNone
                            }
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onEntered: tipDelay.restart()
                            onExited: { tipDelay.stop(); tip.visible = false; }
                            onPressed: { tipDelay.stop(); tip.visible = false; }
                            onClicked: event => {
                                button.forceActiveFocus(Qt.MouseFocusReason);
                                button.activate(event.button);
                            }
                            onWheel: event => {
                                if (event.angleDelta.y) button.modelData.scroll(event.angleDelta.y, false);
                                if (event.angleDelta.x) button.modelData.scroll(event.angleDelta.x, true);
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
