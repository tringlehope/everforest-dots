import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./frame"
import "./bar"
import "./popups"
import "./launcher"

ShellRoot {
    id: root

    function closeAll() {
        audioPopup.open = false;
        qsPopup.open = false;
        notifPopup.open = false;
        wallPopup.open = false;
        settingsPopup.open = false;
        launcherDock.open = false;
    }

    Process {
        id: frameModeInit
        running: true
        command: ["sh", "-c", "cat ~/.local/state/qs-frame-mode 2>/dev/null || echo 1"]
        stdout: StdioCollector {
            onStreamFinished: Theme.showFrame = (text.trim() !== "0")
        }
    }

    ScreenFrame {}

    TopBar {
        onVolumeScrolled: volumeOsd.trigger()
        onToggleLauncher: {
            var next = !launcherDock.open;
            root.closeAll();
            launcherDock.open = next;
        }
        onToggleAudio: {
            var next = !audioPopup.open;
            root.closeAll();
            audioPopup.open = next;
        }
        onToggleQuickSettings: {
            var next = !qsPopup.open;
            root.closeAll();
            qsPopup.open = next;
        }
        onToggleNotifications: {
            var next = !notifPopup.open;
            root.closeAll();
            notifPopup.open = next;
        }
    }

    AudioPopup         { id: audioPopup }
    QuickSettingsPopup {
        id: qsPopup
        onOpenWallpapers: wallPopup.open = true
        onOpenSettings:   settingsPopup.open = true
    }
    NotificationsPopup { id: notifPopup }
    WallpaperPopup     { id: wallPopup }
    SettingsPopup      { id: settingsPopup }
    LayoutOsd          { id: layoutOsd }
    VolumeOsd          { id: volumeOsd }
    LauncherDock       { id: launcherDock; pinned: qsPopup.dockPinned }

    IpcHandler {
        target: "osd"
        function volume(): void { volumeOsd.trigger(); }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            var next = !launcherDock.open;
            root.closeAll();
            launcherDock.open = next;
        }
    }
}
