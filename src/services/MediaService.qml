import QtQuick
import QtQml.Models
import Quickshell.Services.Mpris

Item {
    id: root
    property bool demo: false
    property var selected: null
    readonly property bool available: demo || selected !== null
    readonly property string title: demo ? "Bloom" : selected ? selected.trackTitle || selected.identity : "Nothing playing"
    readonly property string artist: demo ? "The Paper Kites" : selected ? selected.trackArtist : ""
    readonly property string album: demo ? "Woodland" : selected ? selected.trackAlbum : ""
    readonly property string art: demo ? "../assets/album.svg" : selected ? selected.trackArtUrl : ""
    property bool demoPlaying: true
    readonly property bool playing: demo ? demoPlaying : selected ? selected.isPlaying : false
    readonly property bool canPrevious: demo || !!(selected && selected.canGoPrevious)
    readonly property bool canNext: demo || !!(selected && selected.canGoNext)
    readonly property bool canToggle: demo || !!(selected && selected.canTogglePlaying)
    function select() {
        const players = Mpris.players.values;
        const playing = players.find(p => p.isPlaying);
        selected = playing || (players.indexOf(selected) >= 0 ? selected : players[0] || null);
    }
    function toggle() { if (demo) demoPlaying = !demoPlaying; else if (canToggle) selected.togglePlaying(); }
    function previous() { if (!demo && canPrevious) selected.previous(); }
    function next() { if (!demo && canNext) selected.next(); }
    Connections { target: Mpris.players; function onValuesChanged() { root.select(); } }
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { root.select(); }
        }
    }
    Component.onCompleted: select()
}
