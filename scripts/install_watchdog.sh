#!/usr/bin/env bash
# install_watchdog.sh
# Install / uninstall / status of the watchdog LaunchAgent.
# Subcommands:
#   install   (default) - render plist from template and launchctl load
#   uninstall           - launchctl unload and remove plist
#   status              - show launchctl list entry
# Constraints:
#   - No sudo (D004).
#   - macOS only for actual launchctl operations; Linux falls back to a cron hint.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LABEL="com.multi-agent-ojousama.watchdog"
TEMPLATE="$SCRIPT_DIR/watchdog.plist.template"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/${LABEL}.plist"

SUBCMD="${1:-install}"

is_macos() {
    [ "$(uname -s)" = "Darwin" ]
}

require_macos_or_hint() {
    if is_macos; then
        return 0
    fi
    cat <<EOF >&2
[install_watchdog] launchctl is macOS-only.
On Linux, schedule scripts/watchdog.sh via cron, e.g.:
  */5 * * * * /bin/bash $PROJECT_ROOT/scripts/watchdog.sh >> /tmp/multi-agent-ojousama-watchdog.log 2>&1
EOF
    return 1
}

render_plist() {
    if [ ! -f "$TEMPLATE" ]; then
        echo "[install_watchdog] template not found: $TEMPLATE" >&2
        exit 1
    fi
    mkdir -p "$PLIST_DIR"
    # Substitute __PROJECT_ROOT__ via sed; use | as delimiter to handle slashes in path.
    sed "s|__PROJECT_ROOT__|${PROJECT_ROOT}|g" "$TEMPLATE" > "$PLIST_PATH"
    echo "[install_watchdog] wrote $PLIST_PATH"
}

cmd_install() {
    require_macos_or_hint || exit 0

    # Ensure watchdog.sh is executable (defensive).
    if [ -f "$SCRIPT_DIR/watchdog.sh" ] && [ ! -x "$SCRIPT_DIR/watchdog.sh" ]; then
        chmod +x "$SCRIPT_DIR/watchdog.sh"
    fi

    if [ -f "$PLIST_PATH" ]; then
        echo "[install_watchdog] existing plist found; unloading first"
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
    fi

    render_plist
    launchctl load "$PLIST_PATH"
    echo "[install_watchdog] loaded $LABEL"
}

cmd_uninstall() {
    require_macos_or_hint || exit 0

    if [ -f "$PLIST_PATH" ]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        echo "[install_watchdog] removed $PLIST_PATH"
    else
        echo "[install_watchdog] no plist at $PLIST_PATH; nothing to remove"
    fi
}

cmd_status() {
    require_macos_or_hint || exit 0

    if launchctl list 2>/dev/null | grep -q "$LABEL"; then
        echo "[install_watchdog] $LABEL is loaded"
        launchctl list | grep "$LABEL" || true
    else
        echo "[install_watchdog] $LABEL is NOT loaded"
    fi

    if [ -f "$PLIST_PATH" ]; then
        echo "[install_watchdog] plist present: $PLIST_PATH"
    else
        echo "[install_watchdog] plist absent: $PLIST_PATH"
    fi
}

case "$SUBCMD" in
    install)   cmd_install ;;
    uninstall) cmd_uninstall ;;
    status)    cmd_status ;;
    *)
        echo "Usage: $0 {install|uninstall|status}" >&2
        exit 2
        ;;
esac
