param(
  [string]$SshUser = 'ocw',
  [string]$SshHost = '91.134.255.134',
  [int]$SshPort = 22,
  [string]$LocalSourcePath = 'D:\Proyectos\AI_Servidor\web\html',
  [string]$LocalEnvFile = 'D:\Proyectos\AI_Servidor\web\html\.env.server',
  [string]$RemotePath = '/opt/facturas-pre',
  [string]$RemoteEnvFile = '.env.pre.server',
  [string]$ComposeFile = 'docker-compose.server.yml',
  [switch]$ImportLocalDb,
  [string]$LocalDbContainer = 'html-db-1'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function ConvertTo-PosixSingleQuoted {
  param([Parameter(Mandatory = $true)][string]$Value)
  $escaped = $Value -replace '''', '''"''"'''
  return "'" + $escaped + "'"
}

function Get-EnvFileValueOrDefault {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string]$Key,
    [AllowEmptyString()][string]$DefaultValue = ''
  )

  if (!(Test-Path $FilePath)) {
    return $DefaultValue
  }

  $line = Get-Content -Path $FilePath | Where-Object { $_ -match "^\s*$Key\s*=" } | Select-Object -First 1
  if (-not $line) {
    return $DefaultValue
  }

  $value = ($line -split '=', 2)[1].Trim()
  if ($value.StartsWith('"') -and $value.EndsWith('"')) {
    return $value.Substring(1, $value.Length - 2)
  }
  if ($value.StartsWith("'") -and $value.EndsWith("'")) {
    return $value.Substring(1, $value.Length - 2)
  }
  return $value
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
$packageName = "facturas_pre_$stamp.tgz"
$packagePath = Join-Path $env:TEMP $packageName

Write-Host "[PRE] Empaquetando codigo: $packagePath"
$WebRoot = Split-Path $LocalSourcePath -Parent
& tar -czf $packagePath --exclude='.git' --exclude='.vscode' --exclude='test' --exclude='utLocal' --exclude='utPorRevisar' --exclude='utRemoto' --exclude='docs' --exclude='html' --exclude='liberar' --exclude='frontend/node_modules' --exclude='backend/vendor' --exclude='extractor/venv' -C $LocalSourcePath backend frontend extractor $RemoteEnvFile -C $WebRoot docker docker-compose.server.yml
if ($LASTEXITCODE -ne 0) {
  throw "Fallo tar local (codigo $LASTEXITCODE)"
}

Write-Host '[PRE] Subiendo paquete al servidor...'
& $scpExe -P $SshPort $packagePath "${target}:/tmp/$packageName"
if ($LASTEXITCODE -ne 0) {
  throw "Fallo scp del paquete (codigo $LASTEXITCODE)"
}

$dbDumpName = "facturas_pre_db_$stamp.sql"
$dbDumpPath = Join-Path $env:TEMP $dbDumpName
$dbDumpRemote = "/tmp/$dbDumpName"

try {
  if ($ImportLocalDb) {
    $dbRootPassword = Get-EnvFileValueOrDefault -FilePath $LocalEnvFile -Key 'DB_ROOT_PASSWORD' -DefaultValue ''
    $dbName = Get-EnvFileValueOrDefault -FilePath $LocalEnvFile -Key 'DB_NAME' -DefaultValue 'facturas'
    if ([string]::IsNullOrWhiteSpace($dbRootPassword)) {
      throw "No se encontro DB_ROOT_PASSWORD en $LocalEnvFile para exportar la BD local."
    }

    Write-Host '[PRE] Exportando BD local para subir a PRE...'
    $dumpCmd = "if command -v mariadb-dump >/dev/null 2>&1; then mariadb-dump --single-transaction --quick --skip-lock-tables --user=root $dbName; elif command -v mysqldump >/dev/null 2>&1; then mysqldump --single-transaction --quick --skip-lock-tables --user=root $dbName; else echo 'ni mariadb-dump ni mysqldump disponible' >&2; exit 127; fi"
    & docker exec -e "MYSQL_PWD=$dbRootPassword" $LocalDbContainer sh -lc $dumpCmd 1> $dbDumpPath
    if ($LASTEXITCODE -ne 0) {
      throw "Fallo exportando BD local (codigo $LASTEXITCODE)"
    }

    Write-Host '[PRE] Subiendo dump de BD a servidor...'
    & $scpExe -P $SshPort $dbDumpPath "${target}:$dbDumpRemote"
    if ($LASTEXITCODE -ne 0) {
      throw "Fallo scp del dump (codigo $LASTEXITCODE)"
    }
  }

  $extractScript = @"
set -e
mkdir -p '$RemotePath'
tar -xzf '/tmp/$packageName' -C '$RemotePath'
rm -f '/tmp/$packageName'
"@

  Write-Host '[PRE] Desplegando paquete en servidor...'
  Invoke-RemoteBash -Script $extractScript -SshExe $sshExe -Target $target -Port $SshPort

  $upScript = @"
set -e
cd '$RemotePath'
docker compose --env-file '$RemoteEnvFile' -f '$ComposeFile' up -d --build
"@

  Write-Host '[PRE] Arrancando stack PRE...'
  Invoke-RemoteBash -Script $upScript -SshExe $sshExe -Target $target -Port $SshPort

  if ($ImportLocalDb) {
    $importScript = @"
set -e
cd '$RemotePath'
test -f '$dbDumpRemote'
cat '$dbDumpRemote' | docker compose --env-file '$RemoteEnvFile' -f '$ComposeFile' exec -T db sh -lc "if command -v mariadb >/dev/null 2>&1; then mariadb --user=root \$MARIADB_DATABASE; elif command -v mysql >/dev/null 2>&1; then mysql --user=root \$MARIADB_DATABASE; else echo 'ni mariadb ni mysql disponible' >&2; exit 127; fi"
rm -f '$dbDumpRemote'
"@

    Write-Host '[PRE] Importando dump en BD de PRE...'
    Invoke-RemoteBash -Script $importScript -SshExe $sshExe -Target $target -Port $SshPort
  }

  Write-Host '[PRE] Despliegue completado.'
}
finally {
  if (Test-Path $packagePath) {
    Remove-Item $packagePath -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path $dbDumpPath) {
    Remove-Item $dbDumpPath -Force -ErrorAction SilentlyContinue
  }
}
