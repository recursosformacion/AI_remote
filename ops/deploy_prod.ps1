param(
  [string]$SshUser = 'ocw',
  [string]$SshHost = '91.134.255.134',
  [int]$SshPort = 22,
  [string]$LocalSourcePath = 'D:\Proyectos\AI_Servidor\web\html',
  [string]$RemotePath = '/opt/facturas-prod',
  [string]$RemoteEnvFile = '.env.server',
  [string]$ComposeFile = 'docker-compose.server.yml'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function ConvertTo-PosixSingleQuoted {
  param([Parameter(Mandatory = $true)][string]$Value)
  $escaped = $Value -replace '''', '''"''"'''
  return "'" + $escaped + "'"
}

function Invoke-RemoteBash {
  param(
    [Parameter(Mandatory = $true)][string]$Script,
    [Parameter(Mandatory = $true)][string]$SshExe,
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][int]$Port
  )

  $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes($Script)
  $scriptB64 = [System.Convert]::ToBase64String($scriptBytes)
  $remoteCmd = "echo '$scriptB64' | base64 -d | bash -se"
  & $SshExe -o BatchMode=yes -o ConnectTimeout=20 -p $Port $Target $remoteCmd
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo comando remoto (codigo $LASTEXITCODE)"
  }
}

$sshExe = Join-Path $env:WINDIR 'System32\OpenSSH\ssh.exe'
$scpExe = Join-Path $env:WINDIR 'System32\OpenSSH\scp.exe'
if (!(Test-Path $sshExe) -or !(Test-Path $scpExe)) {
  throw 'No se encontro OpenSSH (ssh.exe/scp.exe) en esta maquina.'
}
if (!(Test-Path $LocalSourcePath)) {
  throw "No existe ruta local: $LocalSourcePath"
}

$target = "$SshUser@$SshHost"
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$packageName = "facturas_prod_$stamp.tgz"
$packagePath = Join-Path $env:TEMP $packageName

Write-Host "[PRO] Empaquetando codigo: $packagePath"
$WebRoot = Split-Path $LocalSourcePath -Parent
& tar -czf $packagePath --exclude='.git' --exclude='.vscode' --exclude='test' --exclude='utLocal' --exclude='utPorRevisar' --exclude='utRemoto' --exclude='docs' --exclude='html' --exclude='liberar' --exclude='frontend/node_modules' --exclude='backend/vendor' --exclude='extractor/venv' -C $LocalSourcePath backend frontend extractor -C $WebRoot docker docker-compose.server.yml
if ($LASTEXITCODE -ne 0) {
  throw "Fallo tar local (codigo $LASTEXITCODE)"
}

Write-Host "[PRO] Subiendo paquete al servidor..."
& $scpExe -P $SshPort $packagePath "${target}:/tmp/$packageName"
if ($LASTEXITCODE -ne 0) {
  throw "Fallo scp (codigo $LASTEXITCODE)"
}

try {
  $extractScript = @"
set -e
mkdir -p '$RemotePath'
tar -xzf '/tmp/$packageName' -C '$RemotePath'
rm -f '/tmp/$packageName'
"@

  Write-Host '[PRO] Desplegando paquete en servidor...'
  Invoke-RemoteBash -Script $extractScript -SshExe $sshExe -Target $target -Port $SshPort

  $upScript = @"
set -e
cd '$RemotePath'
docker compose --env-file '$RemoteEnvFile' -f '$ComposeFile' up -d --build
"@

  Write-Host '[PRO] Arrancando stack PRO...'
  Invoke-RemoteBash -Script $upScript -SshExe $sshExe -Target $target -Port $SshPort

  Write-Host '[PRO] Despliegue completado.'
}
finally {
  if (Test-Path $packagePath) {
    Remove-Item $packagePath -Force -ErrorAction SilentlyContinue
  }
}
