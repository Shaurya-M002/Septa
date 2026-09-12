# Install the Septa cleaner on Windows (same GGUF the Mac app uses).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$Sidecar = Join-Path $Root "sidecar"
$Venv = Join-Path $Sidecar ".venv"
$Dist = Join-Path $Sidecar "dist"
$GgufName = "slm-clean-q5_k_m.gguf"
$Gguf = Join-Path $Dist $GgufName
$Repo = "Shaurya-M002/Septa"

function Find-Python {
  foreach ($cmd in @("py", "python", "python3")) {
    $exe = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($exe) { return $exe.Source }
  }
  throw "Python 3.10+ is required. Install it from https://www.python.org/downloads/ and re-run Install Septa.bat"
}

if (-not (Test-Path (Join-Path $Sidecar "server\app.py"))) {
  throw "sidecar\server\app.py is missing. Unzip the whole Septa-windows.zip, then run Install Septa.bat from inside that folder."
}

Write-Host "==> Python environment"
New-Item -ItemType Directory -Force -Path $Dist, (Join-Path $Sidecar "logs") | Out-Null
$Python = Find-Python
& $Python -m venv $Venv
$Pip = Join-Path $Venv "Scripts\pip.exe"
$VenvPy = Join-Path $Venv "Scripts\python.exe"
& $Pip install -r (Join-Path $Sidecar "requirements.txt")

if (-not (Test-Path $Gguf)) {
  Write-Host "==> Downloading $GgufName (~424 MB)"
  $url = "https://github.com/$Repo/releases/latest/download/$GgufName"
  Invoke-WebRequest -Uri $url -OutFile $Gguf
}

function Find-LlamaServer {
  $local = Join-Path $Root "llama-server.exe"
  if (Test-Path $local) { return $local }
  $onPath = Get-Command "llama-server.exe" -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }
  $onPath = Get-Command "llama-server" -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }
  return $null
}

$llama = Find-LlamaServer
if (-not $llama) {
  Write-Host "==> llama.cpp"
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) {
    try {
      winget install --id ggml.llamacpp -e --accept-package-agreements --accept-source-agreements
    } catch {
      Write-Host "winget could not install llama.cpp; downloading a CPU build instead."
    }
    $llama = Find-LlamaServer
  }
}

if (-not $llama) {
  Write-Host "==> Downloading llama.cpp Windows build"
  $release = Invoke-RestMethod "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest"
  $asset = $release.assets | Where-Object { $_.name -match "bin-win-.*vulkan-x64\.zip" } | Select-Object -First 1
  if (-not $asset) {
    $asset = $release.assets | Where-Object { $_.name -match "bin-win-.*cpu-x64\.zip" } | Select-Object -First 1
  }
  if (-not $asset) { throw "Could not find a Windows llama.cpp zip on GitHub Releases." }
  $zip = Join-Path $env:TEMP $asset.name
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
  $out = Join-Path $Root "llama.cpp"
  if (Test-Path $out) { Remove-Item -Recurse -Force $out }
  Expand-Archive -Path $zip -DestinationPath $out
  $found = Get-ChildItem -Path $out -Recurse -Filter "llama-server.exe" | Select-Object -First 1
  if (-not $found) { throw "llama-server.exe missing from $($asset.name)" }
  Copy-Item $found.FullName (Join-Path $Root "llama-server.exe")
  $llama = Join-Path $Root "llama-server.exe"
}

Set-Content -Path (Join-Path $Sidecar ".backend") -Value "llamacpp" -NoNewline
Write-Host "Installed. Starting Septa..."
& (Join-Path $Root "start.ps1")
