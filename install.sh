#!/usr/bin/env bash
# Install Septa on this Mac: sidecar (required) + app (if Xcode is present).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SIDECAR="$ROOT/sidecar"
VENV="$SIDECAR/.venv"
LABEL="app.septa.sidecar"
PLIST_DST="$HOME/Library/LaunchAgents/${LABEL}.plist"
REPO="Shaurya-M002/Septa"
GGUF_NAME="slm-clean-q5_k_m.gguf"
SIDECAR_ONLY=0
APP_ONLY=0
NO_LAUNCH=0

usage() {
  cat <<EOF
Install Septa — Hex-based dictation plus local SLM post-process.

Usage: ./install.sh [options]

  --sidecar-only   Set up the cleaner and LaunchAgent, skip the Mac app
  --app-only       Build/install Septa.app only (sidecar already set up)
  --no-launch      Install files but do not start the sidecar yet
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sidecar-only) SIDECAR_ONLY=1 ;;
    --app-only) APP_ONLY=1 ;;
    --no-launch) NO_LAUNCH=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

log() { printf '\n==> %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

setup_venv() {
  log "Python environment"
  mkdir -p "$SIDECAR/logs" "$SIDECAR/dist" "$SIDECAR/models"
  if have uv; then
    if ! uv venv --python 3.13 "$VENV" 2>/dev/null; then
      uv venv "$VENV"
    fi
    uv pip install --python "$VENV/bin/python" -r "$SIDECAR/requirements.txt"
  else
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -U pip
    "$VENV/bin/pip" install -r "$SIDECAR/requirements.txt"
  fi
}

copy_if_present() {
  local src="$1" dst="$2"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    if [[ -d "$src" ]]; then
      rsync -a --delete "$src/" "$dst/"
    else
      cp -f "$src" "$dst"
    fi
    return 0
  fi
  return 1
}

find_vibe_slm() {
  local candidates=(
    "$ROOT/../Vibe-a-thon/vibes/slm"
    "$HOME/Codes/Projects/Vibe-a-thon/vibes/slm"
  )
  local p
  for p in "${candidates[@]}"; do
    if [[ -d "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

download_gguf() {
  local dest="$SIDECAR/dist/$GGUF_NAME"
  if [[ -f "$dest" ]]; then
    return 0
  fi
  mkdir -p "$SIDECAR/dist"
  log "Downloading $GGUF_NAME from GitHub Releases (~424 MB)"
  if have gh; then
    gh release download --repo "$REPO" --pattern "$GGUF_NAME" --dir "$SIDECAR/dist" --clobber
  else
    local url="https://github.com/${REPO}/releases/latest/download/${GGUF_NAME}"
    curl -fL --progress-bar -o "$dest" "$url"
  fi
  [[ -f "$dest" ]]
}

choose_backend() {
  local vibe
  vibe="$(find_vibe_slm || true)"

  if copy_if_present "${vibe:+$vibe/models/slm-clean}" "$SIDECAR/models/slm-clean" \
    || [[ -d "$SIDECAR/models/slm-clean" ]]; then
    echo mlx > "$SIDECAR/.backend"
    log "Using MLX fused model at sidecar/models/slm-clean"
    if have uv; then
      uv pip install --python "$VENV/bin/python" mlx-lm
    else
      "$VENV/bin/pip" install mlx-lm
    fi
    return 0
  fi

  if copy_if_present "${vibe:+$vibe/dist/$GGUF_NAME}" "$SIDECAR/dist/$GGUF_NAME" \
    || download_gguf; then
    echo llamacpp > "$SIDECAR/.backend"
    log "Using llama.cpp GGUF at sidecar/dist/$GGUF_NAME"
    if ! have llama-server; then
      if have brew; then
        log "Installing llama.cpp"
        brew install llama.cpp
      else
        echo "Install llama.cpp (need llama-server on PATH), then re-run." >&2
        exit 1
      fi
    fi
    return 0
  fi

  cat >&2 <<EOF
Could not find the Septa cleaner model.

Put one of these in place and re-run ./install.sh:

  sidecar/models/slm-clean/     (fused MLX folder)
  sidecar/dist/$GGUF_NAME       (Q5 GGUF)

Or clone next to Vibe-a-thon so install can copy vibes/slm/models or dist/.
EOF
  exit 1
}

install_launchagent() {
  log "Login item for the sidecar"
  mkdir -p "$HOME/Library/LaunchAgents" "$SIDECAR/logs"
  local start="$ROOT/scripts/start-sidecar.sh"
  chmod +x "$start"
  sed \
    -e "s|__START_SIDECAR__|$start|g" \
    -e "s|__REPO_ROOT__|$ROOT|g" \
    -e "s|__SIDECAR_LOG__|$SIDECAR/logs|g" \
    "$ROOT/launchd/app.septa.sidecar.plist.template" > "$PLIST_DST"

  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  if [[ "$NO_LAUNCH" -eq 0 ]]; then
    launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
    launchctl enable "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>/dev/null || launchctl start "$LABEL" || true
  fi
}

wait_healthy() {
  if [[ "$NO_LAUNCH" -eq 1 ]]; then
    return 0
  fi
  log "Waiting for http://127.0.0.1:8742/healthz"
  local i
  for i in $(seq 1 40); do
    if curl -fsS http://127.0.0.1:8742/healthz >/dev/null 2>&1; then
      curl -fsS http://127.0.0.1:8742/healthz
      echo
      return 0
    fi
    sleep 0.5
  done
  echo "Sidecar did not become healthy. Check $SIDECAR/logs/" >&2
  return 1
}

build_app() {
  if [[ "$SIDECAR_ONLY" -eq 1 ]]; then
    return 0
  fi
  if ! xcodebuild -version >/dev/null 2>&1; then
    cat <<EOF

Xcode is not installed, so Septa.app was not built.
The sidecar is enough to clean text at http://127.0.0.1:8742
To build the dictation app later:

  1. Install Xcode from the App Store
  2. sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  3. ./install.sh --app-only

Until then, keep Hex.app quit if you do not want two hotkeys fighting.
EOF
    return 0
  fi

  log "Building Septa.app (this takes a few minutes the first time)"
  local derived="$ROOT/build"
  mkdir -p "$derived"
  xcodebuild \
    -project "$ROOT/Septa.xcodeproj" \
    -scheme Septa \
    -configuration Release \
    -derivedDataPath "$derived" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM= \
    -destination 'platform=macOS' \
    build

  local app
  app="$(find "$derived" -name 'Septa.app' -type d | head -n 1)"
  if [[ -z "$app" ]]; then
    echo "Build finished but Septa.app was not found under $derived" >&2
    return 1
  fi
  log "Installing /Applications/Septa.app"
  rm -rf /Applications/Septa.app
  ditto "$app" /Applications/Septa.app
  open /Applications/Septa.app
  echo "Quit Hex.app if it is still running — both apps bind a global dictation hotkey."
}

if [[ "$APP_ONLY" -eq 1 ]]; then
  build_app
  exit 0
fi

chmod +x "$ROOT/scripts/start-sidecar.sh"
setup_venv
choose_backend
install_launchagent
wait_healthy || true
build_app

cat <<EOF

Septa is installed from:

  $ROOT

Sidecar:  http://127.0.0.1:8742
Health:   curl http://127.0.0.1:8742/healthz
Stop:     launchctl bootout gui/\$(id -u)/$LABEL
Start:    launchctl bootstrap gui/\$(id -u) $PLIST_DST

Dictate with Septa. The sidecar cleans the transcript before paste.
EOF
