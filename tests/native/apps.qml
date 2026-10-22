import QtQuick
import Quickshell
import Quickshell.Io
import "services"
ShellRoot {
    AppService { id: apps; query: "Island Launch Fixture" }
    IpcHandler {
        target: "apps"
        function ready(): bool { return apps.results.length === 1; }
        function launch(): bool { return apps.launch(0); }
        function state(): string { return JSON.stringify({history:apps.history,error:apps.error}); }
    }
}
