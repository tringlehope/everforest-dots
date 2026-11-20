pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: runner
    Component {
        id: procComp
        Process {}
    }
    function exec(cmd) {
        var p = procComp.createObject(runner, { command: cmd });
        p.exited.connect(function() { p.destroy(); });
        p.running = true;
    }
}
