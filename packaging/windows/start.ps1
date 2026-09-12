# Start llama-server + the Septa cleaner, then open the local UI.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Sidecar = Join-Path $Root "sidecar"
$VenvPy = Join-Path $Sidecar ".venv\Scripts\python.exe"
$Gguf = Join-Path $Sidecar "dist\slm-clean-q5_k_m.gguf"

if (-not (Test-Path $VenvPy)) { throw "Run Install Septa.bat first." }
if (-not (Test-Path $Gguf)) { throw "Model missing. Run Install Septa.bat first." }

function Find-LlamaServer {
  $local = Join-Path $Root "llama-server.exe"
  if (Test-Path $local) { return $local }
  $cmd = Get-Command "llama-server.exe" -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command "llama-server" -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  throw "llama-server.exe not found. Run Install Septa.bat."
}

$llama = Find-LlamaServer
$env:SLM_BACKEND = "llamacpp"
$env:SLM_LLAMA_URL = "http://127.0.0.1:8080"

$listening = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if (-not $listening) {
  Start-Process -FilePath $llama -ArgumentList "--model `"$Gguf`" --port 8080 --ctx-size 4096 --alias slm-clean" -WindowStyle Minimized
  Start-Sleep -Seconds 2
}

$listeningClean = Get-NetTCPConnection -LocalPort 8742 -State Listen -ErrorAction SilentlyContinue
if (-not $listeningClean) {
  Start-Process -FilePath $VenvPy -WorkingDirectory $Sidecar -ArgumentList "-m uvicorn server.app:app --host 127.0.0.1 --port 8742" -WindowStyle Minimized
  Start-Sleep -Seconds 2
}

Start-Process "http://127.0.0.1:8742"
Write-Host "Septa cleaner is at http://127.0.0.1:8742"
