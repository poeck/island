import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../core"
import "../core/Weather.js" as Weather
import "../ui"

FocusScope {
    id: root
    property bool active: false
    property var service: null
    signal dismiss()
    readonly property var forecastData: service ? service.forecastData : null
    readonly property var current: forecastData ? forecastData.current : ({})
    readonly property var today: forecastData && forecastData.daily.length ? forecastData.daily[0] : ({})
    readonly property var conditions: Weather.condition(current.code,current.day)
    function chooseCity(city) { choosing=false; cityInput.text=""; service.choose(city); }
    property bool hourly: false
    property bool choosing: false
    onActiveChanged: {
        if (active) Qt.callLater(() => root.forceActiveFocus());
        else { choosing=false; if (service) service.query=""; }
    }
    // Daily temperature range across the whole week, for the range bars.
    readonly property var weekRange: {
        const days = forecastData ? forecastData.daily.filter(d => d.min !== null && d.max !== null && d.min !== undefined && d.max !== undefined) : [];
        if (!days.length) return [0, 1];
        const low = Math.min(...days.map(d => d.min)), high = Math.max(...days.map(d => d.max));
        return [low, Math.max(high, low + 1)];
    }
    ColumnLayout {
        anchors.fill:parent; anchors.margins:Theme.contentMargin; spacing:10
        ViewHeader {
            title: root.choosing ? "Choose a location" : "Weather"; preview: !!root.service && root.service.demo
            ActionButton {
                objectName:"weatherLocation"; text:root.choosing ? "Back" : "Change city"; iconName: root.choosing ? "chevron-left" : "search"
                enabled:root.service !== null && !root.service.demo
                onClicked: { root.choosing=!root.choosing; if (root.choosing) Qt.callLater(() => cityInput.forceActiveFocus()); }
            }
            IconButton { objectName:"weatherRefresh"; iconName:"refresh"; hint:"Refresh weather"; enabled:root.service !== null && !root.service.loading && !root.service.demo; onClicked:root.service.refresh(true) }
            IconButton { iconName:"close"; hint:"Close weather"; onClicked:root.dismiss() }
        }
        ColumnLayout {
            visible:root.choosing; Layout.fillWidth:true; Layout.fillHeight:true; spacing:10
            Label { text:"Search a city or postcode. Your choice is remembered on this device."; color:Theme.secondary; Layout.fillWidth:true; wrapMode:Text.Wrap }
            Input {
                id:cityInput; objectName:"weatherCityInput"; Layout.fillWidth:true; placeholderText:"City or postcode…"
                onTextChanged:if (root.service) root.service.query=text
                onAccepted:if (root.service && root.service.results.length) { root.chooseCity(root.service.results[0]); }
            }
            ScrollView {
                Layout.fillWidth:true; Layout.fillHeight:true; clip:true; contentWidth:availableWidth
                Column {
                    width:parent.width; spacing:2
                    Repeater {
                        model:root.service ? root.service.results : []
                        Button {
                            id:city; required property var modelData; required property int index
                            objectName:"weatherCity-"+index; width:parent.width; height:46; leftPadding:12; rightPadding:12; topPadding:0; bottomPadding:0; hoverEnabled:true
                            Accessible.name:modelData.name+", "+modelData.country
                            background:Rectangle { radius:Theme.radiusControl; color:city.down ? Theme.pressed : city.hovered ? Theme.raised : "transparent"; border.color:city.visualFocus ? Theme.focus : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.hoverDuration } } }
                            contentItem:RowLayout {
                                spacing: 10
                                Icon { name:"network"; implicitWidth:14; implicitHeight:14; color:Theme.secondary }
                                Label { text:city.modelData.name; font.weight:Theme.weightMedium }
                                Label { text:[city.modelData.region,city.modelData.country].filter(s=>s).join(" · "); font.pixelSize:Theme.textSmall; color:Theme.muted; Layout.fillWidth:true }
                                Icon { name:"chevron-right"; implicitWidth:14; implicitHeight:14; color:city.hovered ? Theme.text : Theme.muted }
                            }
                            onClicked:root.chooseCity(modelData)
                        }
                    }
                    Label {
                        width:parent.width; topPadding:8; leftPadding:12; wrapMode:Text.Wrap; font.pixelSize:Theme.textSmall; color:Theme.secondary
                        text:!root.service ? "" : root.service.searching ? "Searching…" : root.service.searchError || (root.service.searched && !root.service.results.length ? "No matching places. Try a nearby city or add the country." : "")
                    }
                }
            }
        }
        RowLayout {
            visible:!root.choosing && root.forecastData !== null
            Layout.fillWidth:true; Layout.fillHeight:true; Layout.topMargin:4; spacing:10
            ColumnLayout {
                Layout.fillWidth:true; Layout.preferredWidth:400; Layout.fillHeight:true; spacing:10
                Card {
                    Layout.fillWidth:true; implicitHeight:168
                    ColumnLayout {
                        anchors.fill:parent; anchors.margins:16; anchors.leftMargin:18; spacing:0
                        RowLayout {
                            Layout.fillWidth:true; spacing:6
                            Label { objectName:"weatherCityName"; text:root.forecastData ? root.forecastData.location.name : ""; font.weight:Theme.weightMedium }
                            Label { text:root.forecastData ? root.forecastData.location.country : ""; font.pixelSize:Theme.textSmall; color:Theme.muted; Layout.fillWidth:true }
                        }
                        RowLayout {
                            Layout.fillWidth:true; Layout.fillHeight:true; spacing:12
                            Label { objectName:"weatherTemperature"; text:Weather.value(root.current.temperature,"°"); font.pixelSize:60; font.weight:Theme.weightMedium; font.letterSpacing:-2.5; font.features:Theme.numeric; Layout.fillWidth:true }
                            WeatherIcon { code:root.current.code; day:root.current.day !== false; implicitWidth:52; implicitHeight:52; Layout.rightMargin:4 }
                        }
                        RowLayout {
                            Layout.fillWidth:true
                            Label { text:root.conditions.label; color:Theme.secondary; Layout.fillWidth:true }
                            Label { text:"H " + Weather.value(root.today.max,"°") + "   L " + Weather.value(root.today.min,"°"); font.pixelSize:Theme.textSmall; font.weight:Theme.weightMedium; font.features:Theme.numeric; color:Theme.secondary }
                        }
                    }
                }
                Card {
                    Layout.fillWidth:true; Layout.fillHeight:true
                    GridLayout {
                        anchors.fill:parent; anchors.margins:16; anchors.leftMargin:18; columns:3; rowSpacing:12; columnSpacing:12
                        Repeater {
                            model:[{label:"Feels like",value:Weather.value(root.current.feels,"°")},{label:"Humidity",value:Weather.value(root.current.humidity,"%")},{label:"Wind",value:Weather.value(root.current.wind," km/h")+" "+Weather.direction(root.current.direction)},{label:"Gusts",value:Weather.value(root.current.gusts," km/h")},{label:"Sunrise",value:root.today.sunrise || "—"},{label:"Sunset",value:root.today.sunset || "—"},{label:"UV index",value:Weather.value(root.today.uv,"",1)},{label:"Pressure",value:Weather.value(root.current.pressure," hPa")},{label:"Precipitation",value:Weather.value(root.current.precipitation," mm",1)}]
                            ColumnLayout {
                                required property var modelData; Layout.fillWidth:true; Layout.preferredWidth:1; spacing:3
                                Label { text:modelData.label; font.pixelSize:Theme.textCaption; color:Theme.muted; Layout.fillWidth:true }
                                Label { text:modelData.value; font.weight:Theme.weightMedium; font.features:Theme.numeric; Layout.fillWidth:true }
                            }
                        }
                    }
                }
            }
            Card {
                Layout.fillWidth:true; Layout.preferredWidth:270; Layout.fillHeight:true
                ColumnLayout {
                    anchors.fill:parent; anchors.margins:10; spacing:6
                    SegmentedTrack {
                        Layout.fillWidth:true
                        Segment { objectName:"weatherDaily"; text:"7 days"; selected:!root.hourly; Layout.fillHeight:true; onClicked:root.hourly=false }
                        Segment { objectName:"weatherHourly"; text:"24 hours"; selected:root.hourly; Layout.fillHeight:true; onClicked:root.hourly=true }
                    }
                    ListView {
                        id:forecast; objectName:"weatherForecast"; Layout.fillWidth:true; Layout.fillHeight:true; clip:true; spacing:0
                        model:!root.forecastData ? [] : root.hourly ? root.forecastData.hourly : root.forecastData.daily
                        onModelChanged:positionViewAtBeginning()
                        ScrollBar.vertical:ScrollBar { policy:ScrollBar.AsNeeded }
                        delegate:Item {
                            id:entry
                            required property var modelData; required property int index
                            readonly property real low:(root.weekRange[0])
                            readonly property real span:root.weekRange[1]-root.weekRange[0]
                            width:forecast.width; height:40
                            Rectangle { anchors.bottom:parent.bottom; x:8; width:parent.width-16; height:1; color:Theme.border; visible:entry.index < forecast.count-1 }
                            RowLayout {
                                anchors.fill:parent; anchors.leftMargin:8; anchors.rightMargin:8; spacing:8
                                Label { text:root.hourly ? entry.modelData.time : entry.index===0 ? "Today" : entry.modelData.dayLabel; font.weight:entry.index===0 ? Theme.weightMedium : Theme.weightRegular; font.features:Theme.numeric; color:entry.index===0 ? Theme.text : Theme.secondary; Layout.preferredWidth:46 }
                                WeatherIcon { code:entry.modelData.code; day:root.hourly ? entry.modelData.day !== 0 : true; color:Theme.secondary; implicitWidth:16; implicitHeight:16 }
                                Label { text:entry.modelData.rain > 0 ? Weather.value(entry.modelData.rain,"%") : ""; font.pixelSize:Theme.textCaption; font.features:Theme.numeric; color:Theme.muted; Layout.preferredWidth:30 }
                                Item { Layout.fillWidth:true; visible:root.hourly }
                                Label { visible:root.hourly; text:Weather.value(entry.modelData.temperature,"°"); font.weight:Theme.weightMedium; font.features:Theme.numeric }
                                Label { visible:!root.hourly; text:Weather.value(entry.modelData.min,"°"); font.features:Theme.numeric; color:Theme.muted; horizontalAlignment:Text.AlignRight; Layout.preferredWidth:26 }
                                Rectangle {
                                    visible:!root.hourly; Layout.fillWidth:true; implicitHeight:4; radius:2; color:Theme.track
                                    Rectangle {
                                        readonly property bool known:entry.modelData.min !== null && entry.modelData.min !== undefined && entry.modelData.max !== null && entry.modelData.max !== undefined
                                        visible:known
                                        x:known ? parent.width*(entry.modelData.min-entry.low)/entry.span : 0
                                        width:known ? Math.max(parent.height, parent.width*(entry.modelData.max-entry.modelData.min)/entry.span) : 0
                                        height:parent.height; radius:2; color:entry.index===0 ? Theme.text : Theme.secondary
                                    }
                                }
                                Label { visible:!root.hourly; text:Weather.value(entry.modelData.max,"°"); font.weight:Theme.weightMedium; font.features:Theme.numeric; Layout.preferredWidth:26 }
                            }
                        }
                        Label { anchors.centerIn:parent; visible:forecast.count===0; text:"Forecast unavailable"; color:Theme.secondary; font.pixelSize:Theme.textSmall }
                    }
                }
            }
        }
        ColumnLayout {
            visible:!root.choosing && root.forecastData === null; Layout.fillWidth:true; Layout.fillHeight:true; spacing:8
            Item { Layout.fillHeight:true }
            WeatherIcon { code:2; color:Theme.muted; implicitWidth:32; implicitHeight:32; Layout.alignment:Qt.AlignHCenter }
            Label { text:root.service && root.service.loading ? "Looking at the skies…" : "Forecast unavailable"; font.pixelSize:Theme.textTitle; font.weight:Theme.weightMedium; Layout.alignment:Qt.AlignHCenter; Layout.topMargin:6 }
            Label { text:root.service ? root.service.location.name : ""; color:Theme.secondary; Layout.alignment:Qt.AlignHCenter }
            Item { Layout.fillHeight:true }
        }
        Label {
            visible:!root.choosing && root.service !== null && !!root.service.error
            text:root.service ? root.service.error+(root.forecastData ? " Showing saved forecast." : "") : ""
            color:root.forecastData ? Theme.warning : Theme.error; font.pixelSize:Theme.textSmall; Layout.fillWidth:true; wrapMode:Text.Wrap
        }
        RowLayout {
            visible:!root.choosing; Layout.fillWidth:true; Layout.leftMargin:6; Layout.rightMargin:6; spacing:8
            Label { text:!root.service ? "" : root.service.demo ? "Simulated weather · no network requests" : root.service.loading ? "Updating…" : root.forecastData ? (root.service.stale ? "Saved "+(root.forecastData.updatedDateLabel || "forecast") : "Updated "+root.forecastData.updatedLabel)+" · "+root.forecastData.timezone : "Choose a city or retry"; font.pixelSize:Theme.textCaption; color:root.service && root.service.stale ? Theme.warning : Theme.muted; Layout.fillWidth:true }
            Text { id: attribution; font.styleName:""; font.weight:Theme.weightRegular; onFontChanged:Theme.syncFontWeight(attribution); linkColor:Theme.muted; text:["https://open-meteo.com/|Open-Meteo","https://www.geonames.org/|GeoNames"].map(l => '<a href="'+l.split("|")[0]+'" style="color:'+Theme.muted+';text-decoration:none">'+l.split("|")[1]+'</a>').join(" · "); color:Theme.muted; font.family:Theme.font; font.pixelSize:Theme.textCaption; onLinkActivated:link=>Qt.openUrlExternally(link)
                HoverHandler { cursorShape: Qt.PointingHandCursor } }
        }
    }
}
