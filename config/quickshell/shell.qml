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
        launcherDock.open = false;
    }

    ScreenFrame {}

    TopBar {
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
    QuickSettingsPopup { id: qsPopup; onOpenWallpapers: wallPopup.open = true }
    NotificationsPopup { id: notifPopup }
    WallpaperPopup     { id: wallPopup }
    LauncherDock       { id: launcherDock; pinned: qsPopup.dockPinned }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            var next = !launcherDock.open;
            root.closeAll();
            launcherDock.open = next;
        }
    }
}
