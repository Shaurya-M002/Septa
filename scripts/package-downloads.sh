#!/usr/bin/env bash
# Build the files the Download buttons fetch.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist-downloads"
rm -rf "$OUT"
mkdir -p "$OUT/Septa-mac" "$OUT/Septa-windows/sidecar"

cp "$ROOT/packaging/macos/Install Septa.command" "$OUT/Septa-mac/"
cp "$ROOT/packaging/macos/README.txt" "$OUT/Septa-mac/"
chmod +x "$OUT/Septa-mac/Install Septa.command"

cp "$ROOT/packaging/windows/"*.bat "$OUT/Septa-windows/"
cp "$ROOT/packaging/windows/"*.ps1 "$OUT/Septa-windows/"
cp "$ROOT/packaging/windows/README.txt" "$OUT/Septa-windows/"
rsync -a --delete \
  --exclude '.venv' --exclude 'models' --exclude 'dist' --exclude 'logs' \
  --exclude '__pycache__' --exclude '.backend' --exclude '.pytest_cache' \
  --exclude '.DS_Store' \
  "$ROOT/sidecar/" "$OUT/Septa-windows/sidecar/"

export COPYFILE_DISABLE=1
cd "$OUT"
rm -f Septa-mac.zip Septa-windows.zip
zip -r -X Septa-mac.zip Septa-mac
zip -r -X Septa-windows.zip Septa-windows
ls -lh Septa-mac.zip Septa-windows.zip
