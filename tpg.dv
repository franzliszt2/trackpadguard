#!/bin/bash
# tpg.dv — trackpad-guard (distributable version)
# Persists macOS trackpad/mouse gesture preferences against apps that override them.
# Installs a per-user LaunchAgent that reasserts gesture preferences periodically
# and on preference-file changes.
#
# Usage:
#   tpg.dv install          — set up and start the guard (3-second interval)
#   tpg.dv minimal-install  — install with 60-second interval (lower pulse rate)
#   tpg.dv run-once         — restore preferences once, no LaunchAgent installed
#   tpg.dv uninstall        — stop and remove everything trackpad-guard owns
#   tpg.dv enable           — start the guard (after install)
#   tpg.dv disable          — stop the guard without uninstalling
#   tpg.dv toggle           — flip current state
#   tpg.dv status           — show install + run state and paths
#   tpg.dv audit            — read-only check of installed artifacts
#   tpg.dv privacy          — plain-language disclosure of tool behavior
#   tpg.dv help             — show this message

set -euo pipefail

# ── sanity checks ────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: tpg.dv is macOS only." >&2
    exit 1
fi

_require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: required command not found: $1" >&2
        exit 1
    fi
}

_require_cmd defaults
_require_cmd launchctl
_require_cmd mkdir
_require_cmd chmod
_require_cmd rm

# ── paths (all derived from current user's HOME) ─────────────────────────────
LABEL="com.user.trackpad-restore"
SCRIPTS_DIR="$HOME/Library/Scripts"
AGENTS_DIR="$HOME/Library/LaunchAgents"
SCRIPT_PATH="$SCRIPTS_DIR/restore-trackpad.sh"
PLIST_PATH="$AGENTS_DIR/${LABEL}.plist"

# ── restore script writer ────────────────────────────────────────────────────
_write_restore_script() {
    mkdir -p "$SCRIPTS_DIR"
    cat > "$SCRIPT_PATH" << 'RESTORE'
#!/bin/bash
# Reassert trackpad/mouse gesture prefs. Owned by tpg.dv — do not edit by hand.
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.dock showMissionControlGestureEnabled -bool true
/usr/bin/killall cfprefsd 2>/dev/null || true
RESTORE
    chmod +x "$SCRIPT_PATH"
}

# ── plist writer (interval parameter, default 3s) ────────────────────────────
_write_plist() {
    local interval="${1:-3}"
    mkdir -p "$AGENTS_DIR"
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
    <key>StartInterval</key>
    <integer>${interval}</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

    if command -v plutil >/dev/null 2>&1; then
        if ! plutil -lint "$PLIST_PATH" >/dev/null; then
            echo "Error: generated plist failed validation: $PLIST_PATH" >&2
            exit 1
        fi
    fi
}

# ── launchctl helper layer ───────────────────────────────────────────────────
# Prefer modern bootstrap/bootout on the per-user GUI domain; fall back to
# legacy load/unload for older macOS.
_agent_is_loaded() {
    if launchctl print "gui/$UID/$LABEL" >/dev/null 2>&1; then
        return 0
    fi
    launchctl list 2>/dev/null | grep -q "$LABEL"
}

_load_agent() {
    if launchctl bootstrap "gui/$UID" "$PLIST_PATH" 2>/dev/null; then
        return 0
    fi
    launchctl load "$PLIST_PATH"
}

_unload_agent() {
    if launchctl bootout "gui/$UID/$LABEL" 2>/dev/null; then
        return 0
    fi
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
}

_is_installed() {
    [[ -f "$PLIST_PATH" && -f "$SCRIPT_PATH" ]]
}

# ── preference restoration (inline, no file required) ───────────────────────
_restore_prefs() {
    defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 2
    defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 2
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
    defaults write com.apple.dock showMissionControlGestureEnabled -bool true
    /usr/bin/killall cfprefsd 2>/dev/null || true
}

# ── commands ─────────────────────────────────────────────────────────────────
cmd_install() {
    if _is_installed && _agent_is_loaded; then
        echo "tpg.dv: already installed and running."
        return 0
    fi
    if _agent_is_loaded; then
        _unload_agent
    fi
    _write_restore_script
    _write_plist 3
    _restore_prefs
    _load_agent
    echo "tpg.dv: installed and running (3-second interval)."
    echo "  plist:   $PLIST_PATH"
    echo "  restore: $SCRIPT_PATH"
}

cmd_minimal_install() {
    if _is_installed && _agent_is_loaded; then
        echo "tpg.dv: already installed. Run 'uninstall' first to change modes."
        return 0
    fi
    if _agent_is_loaded; then
        _unload_agent
    fi
    _write_restore_script
    _write_plist 60
    _restore_prefs
    _load_agent
    echo "tpg.dv: installed in minimal mode (60-second interval + WatchPaths)."
    echo "  Tradeoff: lower polling frequency reduces write activity but allows"
    echo "  a restrictive app to suppress gestures for up to 60 seconds between"
    echo "  corrections. Use 'install' for stronger protection."
    echo "  plist:   $PLIST_PATH"
    echo "  restore: $SCRIPT_PATH"
}

cmd_run_once() {
    _restore_prefs
    echo "tpg.dv: preferences restored (one-time only — no LaunchAgent installed)."
}

cmd_uninstall() {
    local removed=0
    if _agent_is_loaded; then
        _unload_agent
        echo "  unloaded: $LABEL"
    fi
    if [[ -f "$PLIST_PATH" ]]; then
        rm -f "$PLIST_PATH"
        echo "  removed:  $PLIST_PATH"
        removed=1
    fi
    if [[ -f "$SCRIPT_PATH" ]]; then
        rm -f "$SCRIPT_PATH"
        echo "  removed:  $SCRIPT_PATH"
        removed=1
    fi
    if [[ $removed -eq 0 ]]; then
        echo "tpg.dv: nothing to remove."
    else
        echo "tpg.dv: uninstalled."
    fi
}

cmd_enable() {
    if ! _is_installed; then
        echo "tpg.dv: not installed. Run 'install' first." >&2
        exit 1
    fi
    if _agent_is_loaded; then
        echo "tpg.dv: already running."
        return 0
    fi
    _load_agent
    echo "tpg.dv: enabled."
}

cmd_disable() {
    if ! _agent_is_loaded; then
        echo "tpg.dv: already stopped."
        return 0
    fi
    _unload_agent
    echo "tpg.dv: disabled."
}

cmd_toggle() {
    if _agent_is_loaded; then
        cmd_disable
    else
        cmd_enable
    fi
}

cmd_status() {
    local installed running
    if _is_installed; then installed="yes"; else installed="no"; fi
    if _agent_is_loaded; then running="yes"; else running="no"; fi
    echo "tpg.dv status:"
    echo "  installed: $installed"
    echo "  running:   $running"
    echo "  plist:     $PLIST_PATH"
    echo "  restore:   $SCRIPT_PATH"
}

cmd_audit() {
    local loaded
    if _agent_is_loaded; then loaded="yes"; else loaded="no"; fi
    echo "tpg.dv audit (read-only — no changes made):"
    echo ""
    echo "  label:           $LABEL"
    echo "  agent loaded:    $loaded"
    echo ""
    if [[ -f "$PLIST_PATH" ]]; then
        local mtime
        mtime="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$PLIST_PATH" 2>/dev/null || echo "unknown")"
        echo "  plist:           $PLIST_PATH"
        echo "  plist modified:  $mtime"
    else
        echo "  plist:           not found"
        echo "  expected path:   $PLIST_PATH"
    fi
    echo ""
    if [[ -f "$SCRIPT_PATH" ]]; then
        local smtime
        smtime="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$SCRIPT_PATH" 2>/dev/null || echo "unknown")"
        echo "  restore:         $SCRIPT_PATH"
        echo "  restore modified:$smtime"
    else
        echo "  restore:         not found"
        echo "  expected path:   $SCRIPT_PATH"
    fi
}

cmd_privacy() {
    cat << 'PRIVACY'
tpg.dv — Privacy & Artifact Disclosure
───────────────────────────────────────

FILES WRITTEN (install / minimal-install only)
  ~/Library/Scripts/restore-trackpad.sh
  ~/Library/LaunchAgents/com.user.trackpad-restore.plist

  run-once writes no files.

LAUNCHAGENT LABEL
  com.user.trackpad-restore

PREFERENCE DOMAINS MODIFIED
  com.apple.AppleMultitouchTrackpad
    TrackpadThreeFingerHorizSwipeGesture = 2
    TrackpadFourFingerVertSwipeGesture   = 2

  com.apple.driver.AppleBluetoothMultitouch.trackpad
    TrackpadThreeFingerHorizSwipeGesture = 2
    TrackpadFourFingerVertSwipeGesture   = 2

  com.apple.dock
    showMissionControlGestureEnabled = true

NETWORK BEHAVIOR
  No network access occurs after installation.
  The initial download via curl from GitHub is the only network event.
  The tool contains no telemetry, no callbacks, and no remote logging.

OBSERVABILITY
  This tool is transparent and visible to administrator-level monitoring.
  The following activity can be observed by system admins, MDM agents,
  and endpoint security software:

    - LaunchAgent plist present in ~/Library/LaunchAgents
    - Shell script present in ~/Library/Scripts
    - launchctl bootstrap/load recorded in the macOS unified log
    - /bin/bash running the restore script on the configured interval
    - defaults write calls to trackpad and Dock preference domains
    - killall cfprefsd on each restore cycle

  This tool does not attempt to hide from monitoring software.
  It does not clear logs, shell history, forensic records, or system
  databases of any kind.

UNINSTALL
  'tpg.dv uninstall' removes only the two files listed above and unloads
  the LaunchAgent. No other files are created or modified by this tool.
  The command prints each artifact removed before exiting.
PRIVACY
}

cmd_help() {
    cat << 'HELP'
tpg.dv — trackpad-guard (distributable)
Persists macOS trackpad gesture preferences against apps that override them.

Usage:
  tpg.dv install          Set up and start the guard (3-second interval)
  tpg.dv minimal-install  Install with 60-second interval (lower pulse rate)
  tpg.dv run-once         Restore preferences once — no LaunchAgent installed
  tpg.dv uninstall        Stop and remove only files trackpad-guard owns
  tpg.dv enable           Start the guard (after install)
  tpg.dv disable          Stop the guard without uninstalling
  tpg.dv toggle           Flip current state
  tpg.dv status           Show install + run state and paths
  tpg.dv audit            Read-only check of installed artifacts and mtimes
  tpg.dv privacy          Plain-language disclosure of tool behavior
  tpg.dv help             Show this message

Files written (per-user, no sudo required):
  ~/Library/Scripts/restore-trackpad.sh
  ~/Library/LaunchAgents/com.user.trackpad-restore.plist

Preferences enforced:
  - TrackpadThreeFingerHorizSwipeGesture (three-finger app switching)
  - TrackpadFourFingerVertSwipeGesture   (four-finger Mission Control)
  - showMissionControlGestureEnabled
HELP
}

# ── dispatch ─────────────────────────────────────────────────────────────────
case "${1:-help}" in
    install)          cmd_install ;;
    minimal-install)  cmd_minimal_install ;;
    run-once)         cmd_run_once ;;
    uninstall)        cmd_uninstall ;;
    enable)           cmd_enable ;;
    disable)          cmd_disable ;;
    toggle)           cmd_toggle ;;
    status)           cmd_status ;;
    audit)            cmd_audit ;;
    privacy)          cmd_privacy ;;
    help|-h|--help)   cmd_help ;;
    *)
        echo "Usage: tpg.dv {install|minimal-install|run-once|uninstall|enable|disable|toggle|status|audit|privacy|help}" >&2
        exit 1
        ;;
esac
