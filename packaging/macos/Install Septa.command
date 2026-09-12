#!/bin/bash
# Double-click installer for Septa on Apple Silicon Macs.
set -euo pipefail

open_log() {
  osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "Terminal"
  activate
end tell
APPLESCRIPT
}

die() {
  osascript -e "display alert \"Septa install failed\" message \"$1\" as critical" >/dev/null 2>&1 || echo "$1" >&2
  exit 1
}

osascript -e 'display dialog "Septa will clone into ~/Septa, start the local cleaner, and build the Mac app if Xcode is installed.\n\nQuit Hex.app when this finishes so the hotkeys do not fight." buttons {"Install"} default button 1 with title "Install Septa"' >/dev/null

[[ "$(uname -m)" == "arm64" ]] || die "Septa needs an Apple Silicon Mac."
command -v git >/dev/null || die "Install Xcode Command Line Tools (git is missing), then run this again."

DEST="${SEPTA_HOME:-$HOME/Septa}"
mkdir -p "$(dirname "$DEST")"
if [[ -d "$DEST/.git" ]]; then
  git -C "$DEST" pull --ff-only || die "Could not update $DEST"
else
  git clone https://github.com/Shaurya-M002/Septa.git "$DEST" || die "git clone failed"
fi

chmod +x "$DEST/install.sh"
open_log
"$DEST/install.sh"

osascript -e 'display dialog "Septa is installed. The cleaner lives at http://127.0.0.1:8742\n\nIf Septa.app was built, it is in /Applications. Grant microphone and accessibility when asked." buttons {"Open cleaner"} default button 1 with title "Septa"' >/dev/null 2>&1 || true
open "http://127.0.0.1:8742" >/dev/null 2>&1 || true
