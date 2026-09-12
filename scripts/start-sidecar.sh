#!/usr/bin/env bash
# Start Septa's local ASR cleaner (POST http://127.0.0.1:8742/v1/clean).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIDECAR="$ROOT/sidecar"
cd "$SIDECAR"

mkdir -p logs dist models
VENV="$SIDECAR/.venv"
PYTHON="$VENV/bin/python"
BACKEND_FILE="$SIDECAR/.backend"
BACKEND="${SLM_BACKEND:-}"
if [[ -z "$BACKEND" && -f "$BACKEND_FILE" ]]; then
  BACKEND="$(tr -d '[:space:]' < "$BACKEND_FILE")"
fi
BACKEND="${BACKEND:-mlx}"

if [[ ! -x "$PYTHON" ]]; then
  echo "Septa sidecar venv is missing. Run ./install.sh first." >&2
  exit 1
fi

LLAMA_PID=""
cleanup() {
  if [[ -n "${LLAMA_PID}" ]]; then
    kill "$LLAMA_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

wait_for_port() {
  local port="$1"
  local tries=0
  while ! nc -z 127.0.0.1 "$port" 2>/dev/null; do
    tries=$((tries + 1))
    if (( tries > 60 )); then
      echo "Timed out waiting for port $port" >&2
      return 1
    fi
    sleep 0.5
  done
}

if [[ "$BACKEND" == "llamacpp" || "$BACKEND" == "llama.cpp" || "$BACKEND" == "gguf" ]]; then
  GGUF="${SLM_GGUF:-$SIDECAR/dist/slm-clean-q5_k_m.gguf}"
  if [[ ! -f "$GGUF" ]]; then
    echo "GGUF not found at $GGUF" >&2
    echo "Re-run ./install.sh so it can copy or download the model." >&2
    exit 1
  fi
  LLAMA_BIN="${LLAMA_SERVER_BIN:-}"
  if [[ -z "$LLAMA_BIN" ]]; then
    if command -v llama-server >/dev/null 2>&1; then
      LLAMA_BIN="$(command -v llama-server)"
    elif [[ -x /opt/homebrew/bin/llama-server ]]; then
      LLAMA_BIN=/opt/homebrew/bin/llama-server
    else
      echo "llama-server not found. brew install llama.cpp" >&2
      exit 1
    fi
  fi
  export SLM_BACKEND=llamacpp
  export SLM_LLAMA_URL="${SLM_LLAMA_URL:-http://127.0.0.1:8080}"
  "$LLAMA_BIN" --model "$GGUF" --port 8080 --ctx-size 4096 --alias slm-clean \
    >>"$SIDECAR/logs/llama-server.log" 2>&1 &
  LLAMA_PID=$!
  wait_for_port 8080
else
  export SLM_BACKEND=mlx
  export SLM_MODEL="${SLM_MODEL:-$SIDECAR/models/slm-clean}"
  if [[ ! -d "$SLM_MODEL" ]]; then
    echo "MLX model not found at $SLM_MODEL" >&2
    echo "Re-run ./install.sh so it can copy the fused weights, or use the GGUF path." >&2
    exit 1
  fi
fi

exec "$PYTHON" -m uvicorn server.app:app --host 127.0.0.1 --port 8742
