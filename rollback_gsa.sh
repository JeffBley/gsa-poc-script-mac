#!/bin/bash
# ============================================================
# Global Secure Access Client - macOS Rollback Script
# Reverses all changes made by install_gsa.sh:
#   1. Uninstalls the Global Secure Access client
#   2. Removes GSA button visibility preferences
#   3. Restores QUIC in Chrome and Edge (removes managed policy)
# ============================================================

set -euo pipefail

# ---------- Helper functions ----------

log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

# Delete a key from a plist only if the plist exists.
# If the plist becomes empty after removal, delete the file entirely.
remove_plist_key() {
    local plist="$1"
    local key="$2"

    if [[ ! -f "$plist" ]]; then
        log "  Plist not found, skipping: $plist"
        return
    fi

    if defaults read "$plist" "$key" &>/dev/null; then
        defaults delete "$plist" "$key"
        log "  Removed key '$key' from $plist"
    else
        log "  Key '$key' not present in $plist — nothing to remove."
    fi

    # If the plist now has no keys, remove the file entirely
    local remaining
    remaining=$(defaults read "$plist" 2>/dev/null | grep -c "=" || true)
    if [[ "$remaining" -eq 0 ]]; then
        rm -f "$plist"
        log "  Plist is now empty — removed: $plist"
    fi
}

# ---------- Preflight checks ----------

if [[ "$(uname -s)" != "Darwin" ]]; then
    die "This script must be run on macOS."
fi

if [[ "$EUID" -ne 0 ]]; then
    die "This script must be run as root. Please re-run with: sudo $0"
fi

# ---------- Step 1: Uninstall Global Secure Access client ----------

GSA_UNINSTALL_SCRIPT="/Applications/GlobalSecureAccessClient/Global Secure Access Client.app/Contents/Resources/install_scripts/uninstall"

log "Uninstalling Global Secure Access client..."

if [[ -f "$GSA_UNINSTALL_SCRIPT" ]]; then
    "$GSA_UNINSTALL_SCRIPT"
    log "Global Secure Access client uninstalled successfully."
elif [[ -d "/Applications/GlobalSecureAccessClient" ]]; then
    warn "Uninstall script not found at expected path."
    warn "Attempting manual removal of /Applications/GlobalSecureAccessClient..."
    rm -rf "/Applications/GlobalSecureAccessClient"
    log "Removed /Applications/GlobalSecureAccessClient"
else
    warn "Global Secure Access client does not appear to be installed — skipping uninstall."
fi

# ---------- Step 2: Remove GSA button visibility preferences ----------

GSA_PREF_FILE="/Library/Preferences/com.microsoft.globalsecureaccess.plist"

log "Removing GSA system tray button visibility preferences..."

for key in HideDisablePrivateAccessButton HideDisableButton HidePauseButton HideQuitButton; do
    remove_plist_key "$GSA_PREF_FILE" "$key"
done

log "GSA button preferences removed."

# ---------- Step 3: Restore QUIC in Chrome and Edge ----------
#
# Removes the QuicAllowed key written by install_gsa.sh from the managed
# preferences plists. When the key is absent, Chrome and Edge revert to
# their built-in default (QUIC enabled).
# If no other keys remain in the plist, the file is deleted entirely.

MANAGED_PREFS_DIR="/Library/Managed Preferences"

log "Restoring QUIC policy for Google Chrome..."
remove_plist_key "${MANAGED_PREFS_DIR}/com.google.Chrome.plist" "QuicAllowed"

log "Restoring QUIC policy for Microsoft Edge..."
remove_plist_key "${MANAGED_PREFS_DIR}/com.microsoft.Edge.plist" "QuicAllowed"

log "QUIC policy removed. Restart Chrome/Edge for the change to take effect."

# ---------- Done ----------

log "------------------------------------------------------------"
log "Rollback complete. Summary of actions taken:"
log "  - Global Secure Access client uninstalled"
log "  - GSA button visibility preferences removed"
log "  - QUIC policy removed for Chrome and Edge"
log ""
log "You may also want to manually check:"
log "  System Settings > Privacy & Security (system extensions)"
log "  chrome://policy  /  edge://policy (after browser restart)"
log "------------------------------------------------------------"
