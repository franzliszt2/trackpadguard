#!/bin/bash
# trackpad-guard
# Persists macOS trackpad gestures against apps that override them.
# Installs a LaunchAgent that reasserts gesture preferences every 5 seconds.
#
# Usage:
#   trackpad-guard install    — set up and start the guard
#   trackpad-guard uninstall  — remove everything
#   trackpad-guard enable     — start the guard (after install)
#   trackpad-guard disable    — stop the guard without uninstalling
#   trackpad-guard toggle     — flip current state
#   trackpad-guard status     — show whether the guard is running

set -euo pipefail

# ── sanity check ─────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: trackpad-guard is macOS only." >&2
    exit 1
fi

# ── paths ────────────────────────────────────────────────────────────────────
LABEL="com.user.trackpad-restore"
SCRIPT_PATH="$HOME/Library/Scripts/restore-trackpad.sh"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"

# ── internal helpers ─────────────────────────────────────────────────────────
_write_restore_script() {
    mkdir -p "$(dirname "$SCRIPT_PATH")"
    cat > "$SCRIPT_PATH" << 'RESTORE'
#!/bin/bash
sleep 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.dock showMissionControlGestureEnabled -bool true
killall Dock 2>/dev/null || true
RESTORE
    chmod +x "$SCRIPT_PATH"
}

_write_plist() {
    mkdir -p "$(dirname "$PLIST_PATH")"
    cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_PATH}</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>${HOME}/Library/Preferences/com.apple.AppleMultitouchTrackpad.plist</string>
        <string>${HOME}/Library/Preferences/com.apple.driver.AppleBluetoothMultitouch.trackpad.plist</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST
}

_is_loaded() {
    launchctl list 2>/dev/null | grep -q "$LABEL"
}

_is_installed() {
    [[ -f "$PLIST_PATH" && -f "$SCRIPT_PATH" ]]
}

# ── commands ─────────────────────────────────────────────────────────────────
cmd_install() {
    if _is_installed; then
        echo "Already installed. Run 'enable' to start, or 'uninstall' first to reinstall."
        exit 0
    fi
    _write_restore_script
    _write_plist
    launchctl load "$PLIST_PATH"
    echo "trackpad-guard installed and running."
}

cmd_uninstall() {
    if _is_loaded; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
    fi
    rm -f "$SCRIPT_PATH" "$PLIST_PATH"
    echo "trackpad-guard uninstalled."
}

cmd_enable() {
    if ! _is_installed; then
        echo "Not installed. Run 'install' first." >&2
        exit 1
    fi
    if _is_loaded; then
        echo "trackpad-guard is already running."
        exit 0
    fi
    launchctl load "$PLIST_PATH"
    echo "trackpad-guard enabled."
}

cmd_disable() {
    if ! _is_loaded; then
        echo "trackpad-guard is already stopped."
        exit 0
    fi
    launchctl unload "$PLIST_PATH"
    echo "trackpad-guard disabled."
}

cmd_toggle() {
    if _is_loaded; then
        cmd_disable
    else
        cmd_enable
    fi
}

cmd_status() {
    if ! _is_installed; then
        echo "trackpad-guard: NOT INSTALLED"
    elif _is_loaded; then
        echo "trackpad-guard: RUNNING"
    else
        echo "trackpad-guard: INSTALLED / STOPPED"
    fi
}

# ── dispatch ─────────────────────────────────────────────────────────────────
case "${1:-}" in
    install)   cmd_install ;;
    uninstall) cmd_uninstall ;;
    enable)    cmd_enable ;;
    disable)   cmd_disable ;;
    toggle)    cmd_toggle ;;
    status)    cmd_status ;;
    *)
        echo "Usage: trackpad-guard {install|uninstall|enable|disable|toggle|status}"
        exit 1
        ;;
esac
