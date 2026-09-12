# Septa

**[Download for Mac or Windows](https://shaurya-m002.github.io/Septa/)** — unzip, double-click Install.

Septa is Hex with a local speech-to-text cleaner on the end.

Hold a hotkey, talk, release. Whisper or Parakeet transcribes. Then a 0.6B
model on this machine turns that raw ASR into text you can actually send —
fillers gone, self-corrections kept, rupees and names left alone. No cloud.

It is a fork of [Hex](https://github.com/kitlangton/Hex) 0.8.5 (MIT, Kit Langton).
The dictation shell is Hex. The post-process is Septa.

| | Mac | Windows |
|---|---|---|
| Dictation hotkey | Yes (`Septa.app`) | Not yet (Hex is macOS-only) |
| Cleaner | Yes | Yes, same GGUF |
| Install | [Septa-mac.zip](https://github.com/Shaurya-M002/Septa/releases/latest/download/Septa-mac.zip) | [Septa-windows.zip](https://github.com/Shaurya-M002/Septa/releases/latest/download/Septa-windows.zip) |

## Install from source

```bash
git clone https://github.com/Shaurya-M002/Septa.git
cd Septa
./install.sh
```

That does three things:

1. Sets up the Python sidecar (`POST /v1/clean` on port 8742)
2. Installs a login item so the sidecar starts at boot
3. Builds `Septa.app` into `/Applications` **if Xcode is installed**

Apple Silicon only, same as Hex. The first run downloads the ASR model Hex
already used (Parakeet / Whisper). The cleaner model is either copied from a
local Vibe-a-thon checkout or pulled from this repo's GitHub Releases (~424 MB
GGUF).

Quit **Hex.app** once Septa is running. They both want a global hotkey.

### Sidecar only

```bash
./install.sh --sidecar-only
open http://127.0.0.1:8742
```

Useful on a machine that already has Hex, or while Xcode is installing.

```bash
curl -X POST localhost:8742/v1/clean \
  -H 'Content-Type: application/json' \
  -d '{"text":"so um send it to rahul no wait rohan","style":"chat"}'
```

### App only (after Xcode)

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
./install.sh --app-only
```

## What it cleans

| you said | it pastes |
|---|---|
| so um send it to rahul no wait rohan | Send it to Rohan. |
| the invoice came to twenty thousand rupees | The invoice came to ₹20,000. |
| uh mail priya about the delay | Mail Priya about the delay. |
| three things in my plan: Hyderabad, then Orissa, then Vijayawada | a titled markdown list, in your words |

It does **not** invent an email for Priya. The contract is
[`sidecar/PRESERVE.md`](sidecar/PRESERVE.md). If the sidecar is down, Septa
pastes the raw transcript unchanged.

Styles: `chat`, `bullets`, `email`, `code`. The app currently sends `chat`.

## Layout

```
install.sh                 clone, then run this
scripts/start-sidecar.sh   LaunchAgent calls this
sidecar/                   POST /v1/clean
Hex/                       the dictation app (still named Hex in source)
Septa.xcodeproj            builds Septa.app
```

Weights stay out of git. Rebuild or copy them with `./install.sh`.

## License

MIT. Hex remains Kit Langton's. Septa's additions (sidecar, wiring, rebrand)
are under the same license — see `LICENSE`.
