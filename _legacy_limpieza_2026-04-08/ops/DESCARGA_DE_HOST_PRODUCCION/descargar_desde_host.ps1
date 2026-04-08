param(
  [string]$RemoteHost = "91.134.255.134",
  [string]$RemoteUser = "ocw",
  [Parameter(Mandatory = $true)]
  [string]$RemotePath,
  [string]$LocalBaseDir = ".\ops\DESCARGA_DE_HOST_PRODUCCION"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $LocalBaseDir)) {
  New-Item -ItemType Directory -Path $LocalBaseDir -Force | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$safeHost = $RemoteHost -replace "[^a-zA-Z0-9._-]", "_"
$safePath = ($RemotePath.TrimStart('/').Replace('/', '_')) -replace "[^a-zA-Z0-9._-]", "_"
$fileName = "${stamp}__${safeHost}__${safePath}"
$localPath = Join-Path $LocalBaseDir $fileName

Write-Host "[CUARENTENA] Descargando desde: ${RemoteUser}@${RemoteHost}:${RemotePath}"
Write-Host "[CUARENTENA] Guardando en    : $localPath"

& scp "${RemoteUser}@${RemoteHost}:${RemotePath}" "$localPath"
if ($LASTEXITCODE -ne 0) {
  throw "Falló descarga SCP"
}

$manifestPath = Join-Path $LocalBaseDir "MANIFEST.log"
$line = "$(Get-Date -Format o)`t${RemoteUser}@${RemoteHost}:${RemotePath}`t$localPath"
Add-Content -Path $manifestPath -Value $line

Write-Host "OK: descarga registrada en $manifestPath"
