param(
  [string]$BaseCompose = "docker-compose.yml",
  [string]$LocalCompose = "",
  [string]$GatewayToken = "",
  [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"

if (-not $GatewayToken) {
  $configPath = Join-Path $PSScriptRoot "..\openclaw_home\openclaw.json"
  if (Test-Path $configPath) {
    try {
      $config = Get-Content $configPath -Raw | ConvertFrom-Json
      $GatewayToken = [string]$config.gateway.auth.token
    }
    catch {
      Write-Host "Warning: unable to parse $configPath" -ForegroundColor Yellow
    }
  }
}

if (-not $GatewayToken) {
  throw "Gateway token not found. Provide -GatewayToken or set gateway.auth.token in openclaw_home/openclaw.json"
}

Write-Host "[1/4] Starting OpenClaw with local Windows override..." -ForegroundColor Cyan
$composeArgs = @("-f", $BaseCompose)
if ($LocalCompose) {
  if (Test-Path $LocalCompose) {
    $composeArgs += @("-f", $LocalCompose)
  } else {
    Write-Host "[WARN] Local compose override not found: $LocalCompose. Continuing with base compose only." -ForegroundColor Yellow
  }
}
docker compose @composeArgs up -d openclaw

Write-Host "[2/4] Waiting for OpenClaw health..." -ForegroundColor Cyan
Start-Sleep -Seconds 8
docker compose ps openclaw

Write-Host "[3/4] Recent OpenClaw logs:" -ForegroundColor Cyan
docker logs --since 60s openclaw

Write-Host "[4/4] Next steps:" -ForegroundColor Green
Write-Host "- Gateway token: $GatewayToken"
if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
  $GatewayToken | Set-Clipboard
  Write-Host "- Token copied to clipboard."
}
Write-Host "- Open: http://localhost:3000"
Write-Host "- Paste the copied value into the UI field: Gateway token"
Write-Host "- If still failing: clear site data for openclaw.gestionproyectos and localhost, then hard reload."
Write-Host "- Verify logs no longer show: reason=device identity required"

if ($OpenBrowser) {
  Start-Process "http://localhost:3000"
}
