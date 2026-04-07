#!/bin/bash
# ============================================================
# Global Secure Access Client - macOS Installer
# Downloads and installs the Microsoft Global Secure Access
# client from the official Microsoft download link.
# ============================================================

set -euo pipefail

DOWNLOAD_URL="https://aka.ms/GlobalSecureAccess-macOS"
TMP_DIR=$(mktemp -d)
INSTALLER_PATH="$TMP_DIR/GlobalSecureAccessClient.pkg"

# ---------- Helper functions ----------

log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ---------- Preflight checks ----------

if [[ "$(uname -s)" != "Darwin" ]]; then
    die "This script must be run on macOS."
fi

if [[ "$EUID" -ne 0 ]]; then
    die "This script must be run as root. Please re-run with: sudo $0"
fi

# ---------- Download ----------

log "Downloading Global Secure Access client..."
log "Source: $DOWNLOAD_URL"

curl --fail \
     --silent \
     --show-error \
     --location \
     --output "$INSTALLER_PATH" \
     "$DOWNLOAD_URL"

if [[ ! -f "$INSTALLER_PATH" ]]; then
    die "Download failed — installer file not found at $INSTALLER_PATH"
fi

FILESIZE=$(du -sh "$INSTALLER_PATH" | cut -f1)
log "Download complete. Package size: $FILESIZE"

# ---------- Verify it is a valid pkg ----------

FILE_TYPE=$(file -b "$INSTALLER_PATH")
log "Detected file type: $FILE_TYPE"

if ! echo "$FILE_TYPE" | grep -qi "xar\|package\|installer\|data"; then
    warn "File type check inconclusive. Attempting installation anyway..."
fi

# ---------- Install ----------

log "Installing Global Secure Access client..."
installer -pkg "$INSTALLER_PATH" -target /

# ---------- Unhide all system tray menu buttons ----------
#
# By default, two buttons are hidden by Microsoft:
#   HideDisablePrivateAccessButton  (default: hidden)
#   HideQuitButton                  (default: hidden)
#
# The other two are already shown by default but are set explicitly here
# so the configuration is fully declared and idempotent:
#   HideDisableButton               (default: shown)
#   HidePauseButton                 (default: shown)
#
# Setting a key to 'false' means the button is SHOWN (not hidden).

PREF_DOMAIN="com.microsoft.globalsecureaccess"
PREF_FILE="/Library/Preferences/${PREF_DOMAIN}.plist"

log "Configuring system tray menu buttons (unhiding all)..."

defaults write "$PREF_FILE" HideDisablePrivateAccessButton -bool false
defaults write "$PREF_FILE" HideDisableButton              -bool false
defaults write "$PREF_FILE" HidePauseButton                -bool false
defaults write "$PREF_FILE" HideQuitButton                 -bool false

# Ensure the plist is readable by all users
chmod 644 "$PREF_FILE" 2>/dev/null || true

log "Button visibility configured:"
log "  HideDisablePrivateAccessButton = false  (Disable Private Access: SHOWN)"
log "  HideDisableButton              = false  (Disable: SHOWN)"
log "  HidePauseButton                = false  (Pause: SHOWN)"
log "  HideQuitButton                 = false  (Quit: SHOWN)"

# ---------- Disable QUIC in Chrome and Edge ----------
#
# QUIC is a UDP-based protocol that can bypass TCP-based proxies used by
# Global Secure Access. Disabling it forces both browsers to use TCP/HTTPS,
# ensuring traffic is properly intercepted and secured by GSA.
#
# This is applied as a machine-level managed policy (requires root) so it
# persists across all user profiles and cannot be overridden by the user.
# Changes take effect after the browser is restarted.
#
# Note: Safari does not expose a policy for this — QUIC in Safari is
# controlled at the OS network layer and cannot be disabled via a plist.

PREFS_DIR="/Library/Preferences"

disable_quic() {
    local domain="$1"
    local label="$2"
    local plist="${PREFS_DIR}/${domain}.plist"

    log "Disabling QUIC for ${label}..."
    defaults write "$plist" QuicAllowed -bool false
    chmod 644 "$plist" 2>/dev/null || true
    log "  Written: ${plist}"
    log "  Verify after browser restart at: $(echo "$domain" | sed 's/com\.google\.Chrome/chrome/' | sed 's/com\.microsoft\.Edge/edge/')://policy"
}

if command -v "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" &>/dev/null || \
   [ -d "/Applications/Google Chrome.app" ]; then
    disable_quic "com.google.Chrome" "Google Chrome"
else
    log "Google Chrome not detected — writing QUIC policy anyway (will apply if Chrome is installed later)."
    disable_quic "com.google.Chrome" "Google Chrome"
fi

if command -v "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" &>/dev/null || \
   [ -d "/Applications/Microsoft Edge.app" ]; then
    disable_quic "com.microsoft.Edge" "Microsoft Edge"
else
    log "Microsoft Edge not detected — writing QUIC policy anyway (will apply if Edge is installed later)."
    disable_quic "com.microsoft.Edge" "Microsoft Edge"
fi

log "QUIC disabled for Chrome and Edge via managed policy."
log "  Restart any open browser windows for the change to take effect."

# ---------- Launch the client ----------

log "------------------------------------------------------------"
log "Global Secure Access client installation complete."
log "You may need to approve the system extension in:"
log "  System Settings > Privacy & Security"
log "Restart Chrome/Edge to apply the QUIC policy."
log "------------------------------------------------------------"

log "Launching Global Secure Access client..."
GSA_APP="/Applications/GlobalSecureAccessClient/Global Secure Access Client.app"
if [[ -d "$GSA_APP" ]]; then
    open "$GSA_APP"
    log "Client launched. Check the menu bar for the GSA icon."
else
    warn "App not found at '$GSA_APP' — launch it manually from /Applications/GlobalSecureAccessClient/."
fi
