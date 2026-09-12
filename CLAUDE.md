# Septa

Hex fork with a local SLM post-processor. User-facing name is **Septa**;
internal Swift types are still `Hex*` so the upstream app keeps compiling.

- App: `Septa.xcodeproj`, scheme `Septa`, bundle `app.septa.Septa`
- Sidecar: `sidecar/server/app.py` on port 8742
- Install: `./install.sh`

Do not point Sparkle at Hex's appcast. Do not commit GGUF or fused weights.
