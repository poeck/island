import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "../core"
import "../core/Calendar.js" as Calendar
import "../ui"

FocusScope {
    id: root
    property bool active: false
    property bool opened: active
    signal dismiss()
    // Seconds tick only while this view is visible. The bar retains its minute clock.
    SystemClock { id: clock; precision: SystemClock.Seconds; enabled: root.active }
    readonly property date now: clock.date
    property date displayedMonth: Calendar.month(new Date(), 0)
    property date selectedDate: Calendar.civil(now.getFullYear(), now.getMonth(), now.getDate())
    readonly property var days: Calendar.cells(displayedMonth)
    function today() { selectedDate = Calendar.civil(now.getFullYear(), now.getMonth(), now.getDate()); displayedMonth = Calendar.month(now,0); }
    function navigate(delta) { displayedMonth = Calendar.month(displayedMonth, delta); }
    function select(date) { selectedDate = date; if (date.getMonth() !== displayedMonth.getMonth() || date.getFullYear() !== displayedMonth.getFullYear()) displayedMonth = Calendar.month(date,0); }
    onOpenedChanged: if (opened) today()
    onActiveChanged: if (active) Qt.callLater(() => root.forceActiveFocus())
    Keys.onLeftPressed: select(Calendar.day(selectedDate,-1))
    Keys.onRightPressed: select(Calendar.day(selectedDate,1))
    Keys.onUpPressed: select(Calendar.day(selectedDate,-7))
    Keys.onDownPressed: select(Calendar.day(selectedDate,7))
    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp) { navigate(-1); event.accepted = true; }
        else if (event.key === Qt.Key_PageDown) { navigate(1); event.accepted = true; }
        else if (event.key === Qt.Key_Home) { today(); event.accepted = true; }
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.contentMargin; spacing: 14
        ViewHeader {
            title: "Calendar"
            ActionButton { objectName: "calendarToday"; text: "Today"; onClicked: root.today() }
            IconButton { iconName: "close"; hint: "Close calendar"; onClicked: root.dismiss() }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
            ColumnLayout {
                Layout.preferredWidth: 200; Layout.fillHeight: true; spacing: 2
                Label { objectName: "calendarTime"; text: Qt.formatTime(root.now,"HH:mm:ss"); font.pixelSize: 34; font.weight: Theme.weightSemibold; font.letterSpacing: -1; font.features: Theme.numeric; Layout.fillWidth: true }
                Label { text: Qt.formatDate(root.now,"dddd"); font.pixelSize: Theme.textTitle; font.weight: Theme.weightMedium; Layout.fillWidth: true; Layout.topMargin: 2 }
                Label { objectName: "calendarDate"; text: Qt.formatDate(root.now,"d MMMM yyyy"); color: Theme.secondary; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Item { Layout.fillHeight: true }
                Card {
                    Layout.fillWidth: true; implicitHeight: selectedColumn.implicitHeight + 24
                    ColumnLayout {
                        id: selectedColumn
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 2
                        Label { text: Calendar.same(root.selectedDate,root.now) ? "Today" : "Selected"; color: Theme.muted; font.pixelSize: Theme.textCaption; font.weight: Theme.weightMedium }
                        Label { text: Qt.formatDate(root.selectedDate,"dddd, d MMMM"); font.weight: Theme.weightMedium; Layout.fillWidth: true; Layout.topMargin: 4 }
                        Label { text: Qt.formatDate(root.selectedDate,"yyyy") + " · Week " + Calendar.week(root.selectedDate) + " · Day " + Calendar.dayOfYear(root.selectedDate); font.pixelSize: Theme.textSmall; font.features: Theme.numeric; color: Theme.secondary; Layout.fillWidth: true }
                    }
                }
            }
            Card {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 390
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 30; Layout.leftMargin: 4
                        Label { objectName: "calendarMonth"; text: Qt.formatDate(root.displayedMonth,"MMMM yyyy"); font.pixelSize: Theme.textTitle; font.weight: Theme.weightSemibold; Layout.fillWidth: true }
                        IconButton { objectName: "calendarPrevious"; iconName: "chevron-left"; hint: "Previous month"; onClicked: root.navigate(-1) }
                        IconButton { objectName: "calendarNext"; iconName: "chevron-right"; hint: "Next month"; onClicked: root.navigate(1) }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 2
                        Repeater {
                            model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                            Label { required property string modelData; text: modelData; Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.textCaption; font.weight: Theme.weightMedium; color: Theme.muted }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        columns: 7; rowSpacing: 2; columnSpacing: 2; uniformCellWidths: true; uniformCellHeights: true
                        Repeater {
                            model: root.days
                            Button {
                                id: dateButton
                                required property var modelData
                                required property int index
                                readonly property bool isToday: Calendar.same(modelData,root.now)
                                readonly property bool selected: Calendar.same(modelData,root.selectedDate)
                                readonly property bool inMonth: modelData.getMonth() === root.displayedMonth.getMonth()
                                objectName: "calendarDay-" + index
                                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.preferredHeight: 1
                                padding: 0; hoverEnabled: true
                                Accessible.name: Qt.formatDate(modelData,"dddd, d MMMM yyyy") + (isToday ? ", today" : "")
                                background: Rectangle {
                                    anchors.centerIn: parent; width: Math.min(parent.width,parent.height,36); height: width; radius: Theme.radiusControl
                                    color: dateButton.selected ? Theme.text : dateButton.hovered ? Theme.raised : "transparent"
                                    border.color: dateButton.visualFocus ? Theme.focus : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
                                    // Today keeps a small indigo mark, even when selected.
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                                        width: 4; height: 4; radius: 2; color: Theme.accent; visible: dateButton.isToday
                                    }
                                }
                                contentItem: Label { text: dateButton.modelData.getDate(); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: Theme.textBody; font.features: Theme.numeric; font.weight: dateButton.isToday || dateButton.selected ? Theme.weightBold : Theme.weightRegular; color: dateButton.selected ? Theme.background : !dateButton.inMonth ? Theme.disabled : dateButton.isToday ? Theme.text : Theme.secondary }
                                onClicked: { root.select(modelData); root.forceActiveFocus(); }
                            }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: false; spacing: 5
            Kbd { text: "←→" } Label { text: "Day"; font.pixelSize: Theme.textCaption; color: Theme.muted; Layout.rightMargin: 8 }
            Kbd { text: "↑↓" } Label { text: "Week"; font.pixelSize: Theme.textCaption; color: Theme.muted; Layout.rightMargin: 8 }
            Kbd { text: "PgUp" } Kbd { text: "PgDn" } Label { text: "Month"; font.pixelSize: Theme.textCaption; color: Theme.muted; Layout.rightMargin: 8 }
            Kbd { text: "Home" } Label { text: "Today"; font.pixelSize: Theme.textCaption; color: Theme.muted }
            Item { Layout.fillWidth: true }
        }
    }
}
