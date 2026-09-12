# Septa sidecar

Local `POST /v1/clean` that Septa (and anything else) calls after ASR.

```bash
# from the repo root
./install.sh --sidecar-only
curl -X POST localhost:8742/v1/clean \
  -H 'Content-Type: application/json' \
  -d '{"text":"so um send it to rahul no wait rohan","style":"chat"}'
```

- `mlx` — fused Qwen3-0.6B in `models/slm-clean` (Apple Silicon)
- `llamacpp` — Q5 GGUF in `dist/slm-clean-q5_k_m.gguf` via `llama-server`

The app fails open if this process is not running. Read `PRESERVE.md` before
changing what the model is allowed to write.
