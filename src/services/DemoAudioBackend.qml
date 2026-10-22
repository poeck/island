import QtQuick

QtObject {
    id: root
    readonly property bool ready: true
    property QtObject speaker: DemoNode { id: speaker; idNumber: 1; description: "Desktop speakers"; name: "alsa_output.desktop"; isSink: true; initialVolume: .62 }
    property QtObject headset: DemoNode { id: headset; idNumber: 2; description: "Wireless headphones"; name: "bluez_output.headphones"; isSink: true; initialVolume: .48 }
    property QtObject display: DemoNode { id: display; idNumber: 3; description: "Monitor speakers"; name: "alsa_output.hdmi"; isSink: true; initialVolume: .8 }
    property QtObject microphone: DemoNode { id: mic; idNumber: 4; description: "USB microphone"; name: "alsa_input.usb"; isSink: false; initialVolume: .73 }
    property QtObject headsetMic: DemoNode { id: headsetMic; idNumber: 5; description: "Headset microphone"; name: "bluez_input.headphones"; isSink: false; initialVolume: .68 }
    property QtObject browser: DemoNode { id: browser; idNumber: 6; description: "Browser"; name: "browser-playback"; isSink: false; isStream: true; initialVolume: .85; applicationName: "Firefox"; iconName: "firefox" }
    property QtObject music: DemoNode { id: music; idNumber: 7; description: "Music"; name: "music-playback"; isSink: false; isStream: true; initialVolume: .7; applicationName: "Music"; iconName: "multimedia-player" }
    property QtObject call: DemoNode { id: call; idNumber: 8; description: "Voice call"; name: "call-capture"; isSink: true; isStream: true; initialVolume: 1; applicationName: "Voice call"; iconName: "audio-input-microphone" }
    property QtObject nodes: QtObject { property var values: [speaker, headset, display, mic, headsetMic, browser, music, call] }
    property var defaultAudioSink: speaker
    property var defaultAudioSource: mic
    property var preferredDefaultAudioSink: null
    property var preferredDefaultAudioSource: null
    onPreferredDefaultAudioSinkChanged: if (preferredDefaultAudioSink) defaultAudioSink = preferredDefaultAudioSink
    onPreferredDefaultAudioSourceChanged: if (preferredDefaultAudioSource) defaultAudioSource = preferredDefaultAudioSource
    component DemoNode: QtObject {
        required property int idNumber
        readonly property int id: idNumber
        property string name: ""
        property string description: ""
        property string nickname: ""
        property bool isSink: false
        property bool isStream: false
        property bool ready: true
        property real initialVolume: 1
        property string applicationName: ""
        property string iconName: ""
        property var properties: ({"application.name": applicationName, "application.icon-name": iconName})
        property QtObject audio: QtObject {
            property real volume: initialVolume
            property bool muted: false
            signal volumesChanged()
            onVolumeChanged: volumesChanged()
        }
    }
}
