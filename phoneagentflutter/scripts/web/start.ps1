param([string]$Flutter = 'E:/dev/flutter/bin/flutter.bat')
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location -LiteralPath $projectRoot
if (!(Test-Path -LiteralPath $Flutter -PathType Leaf)) {
  throw "Flutter executable not found: $Flutter"
}
Get-Command node -ErrorAction Stop | Out-Null
foreach ($port in @(8080, 8090)) {
  if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
    throw "Port $port is already in use. Reuse the running Web session or stop its owner before starting another."
  }
}
# Stop this process to stop the proxy. Flutter remains interactive for reload.
$proxyProcess = Start-Process -FilePath 'node' -ArgumentList 'scripts/web/dev-server.mjs' -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
try {
  & $Flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8090 --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://localhost:8080/aiassistant-api/
} finally {
  if (!$proxyProcess.HasExited) { Stop-Process -Id $proxyProcess.Id }
}
