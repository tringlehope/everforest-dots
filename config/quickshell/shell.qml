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
        id: themeInit
        running: true
        command: ["sh", "-c", "cat ~/.local/state/qs-theme 2>/dev/null || echo everforest"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (Theme.palettes[t]) {
                    Theme.currentTheme = t;
                    var pal = Theme.palettes[t];
                    var isW7 = (t === "win7");
                    var hlCmd = isW7
                        ? "hl.config({ general = { border_size = 2, col = { active_border = 'rgb(" + pal.hyprActive + ")', inactive_border = 'rgb(" + pal.hyprInactive + ")' } }, decoration = { rounding = 0, active_opacity = 0.90, inactive_opacity = 0.84, blur = { enabled = true, size = 6, passes = 2 } } })"
                        : "hl.config({ general = { border_size = 4, col = { active_border = 'rgb(" + pal.hyprActive + ")', inactive_border = 'rgb(" + pal.hyprInactive + ")' } }, decoration = { rounding = 12, active_opacity = 1.0, inactive_opacity = 1.0, blur = { enabled = false } } })";
                    Quickshell.execDetached(["hyprctl", "eval", hlCmd]);
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/scripts/set_gtk_theme.sh", pal.gtkTheme]);
                }
            }
        }
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
        recording: recManager.recording
        recPaused: recManager.paused
        recElapsed: recManager.elapsedText
        screenSharing: recManager.screenSharing
        onToggleRecPause: recManager.togglePause()
        onStopRecording: recManager.stopRecording()
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
        onOpenPowerMenu:  powerMenu.open()
        onStartCapture:   recManager.startRecording()
        recording:        recManager.recording
    }
    NotificationsPopup { id: notifPopup }
    WallpaperPopup     { id: wallPopup }
    PowerMenu          { id: powerMenu }
    SettingsPopup      { id: settingsPopup }
    ScreenshotOverlay  { id: shotOverlay }
    RecordingManager   { id: recManager }
    LayoutOsd          { id: layoutOsd }
    VolumeOsd          { id: volumeOsd }
    LauncherDock       { id: launcherDock; pinned: qsPopup.dockPinned }

    IpcHandler {
        target: "capture"
        function start(): void { root.closeAll(); shotOverlay.start(); }
    }

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
