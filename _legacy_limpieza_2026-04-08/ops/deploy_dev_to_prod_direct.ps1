param(
  [string]$RemoteHost = "91.134.255.134",
  [string]$RemoteUser = "ocw",
  [string]$RemoteAppDir = "/servidor",
  [string]$WorkspaceRoot = "",
  [switch]$DryRun,
  [switch]$CreateSnapshot,
  [switch]$BackupSensitive,
  [switch]$IncludeOpenClawConfig,
  [switch]$BackupOpenClawConfig,
  [switch]$PurgeOldSnapshots,
  [switch]$PullExternalImages,
  [string]$MigrationCmd
)

$ErrorActionPreference = "Stop"

function Invoke-RemoteCommand {
  param([string]$RemoteCommand)

  $target = "$RemoteUser@$RemoteHost"
  if ($DryRun) {
    Write-Host "[DRY_RUN] ssh $target \"$RemoteCommand\""
    return
  }

  & ssh $target $RemoteCommand
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo comando remoto: $RemoteCommand"
  }
}

function Invoke-ScpUpload {
  param(
    [string]$LocalPath,
    [string]$RemotePath
  )

  $target = "$RemoteUser@$RemoteHost`:$RemotePath"
  if ($DryRun) {
    Write-Host "[DRY_RUN] scp $LocalPath $target"
    return
  }

  & scp $LocalPath $target
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo subida SCP: $LocalPath -> $target"
  }
}

if (-not $WorkspaceRoot) {
  $WorkspaceRoot = Split-Path -Parent $PSScriptRoot
}

$WorkspaceRoot = (Resolve-Path $WorkspaceRoot).Path

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$archivePath = Join-Path $env:TEMP "deploy_direct_$stamp.tar"
$remoteArchive = "/tmp/deploy_direct_$stamp.tar"

Write-Host "=============================================="
Write-Host " Deploy DEV -> PROD directo (sin Git)"
Write-Host "=============================================="
Write-Host "Remoto       : ${RemoteUser}@${RemoteHost}:${RemoteAppDir}"
Write-Host "Workspace    : $WorkspaceRoot"
Write-Host "DryRun       : $($DryRun.IsPresent)"
Write-Host "Snapshot     : $($CreateSnapshot.IsPresent)"
Write-Host "BackupSens   : $($BackupSensitive.IsPresent)"
Write-Host "OpenClawCfg  : $($IncludeOpenClawConfig.IsPresent)"
Write-Host "BackupOCfg   : $($BackupOpenClawConfig.IsPresent)"
Write-Host "PurgeSnaps   : $($PurgeOldSnapshots.IsPresent)"
Write-Host "PullImages   : $($PullExternalImages.IsPresent)"
if ($MigrationCmd) { Write-Host "Migraciones  : $MigrationCmd" }
Write-Host ""

$purgeSnapshotsEffective = $PurgeOldSnapshots -or $CreateSnapshot -or $BackupSensitive -or $BackupOpenClawConfig

$localOpenClawConfig = Join-Path $WorkspaceRoot "openclaw_home\openclaw.json"
$remoteOpenClawConfig = "$RemoteAppDir/openclaw_home/openclaw.json"

Write-Host "[1/6] Empaquetando desde DEV (excluye datos/sensibles/runtime)"
$tarArgs = @(
  "-cf", $archivePath,
  "--exclude=.git",
  "--exclude=.env",
  "--exclude=.env.*",
  "--exclude=.vscode",
  "--exclude=data",
  "--exclude=letsencrypt",
  "--exclude=ollama_data",
  "--exclude=openclaw_data",
  "--exclude=openclaw_home",
  "--exclude=openclaw_skills",
  "--exclude=skills",
  "--exclude=ops/snapshots",
  "--exclude=ops/DESCARGA_DE_HOST_PRODUCCION",
  "-C", $WorkspaceRoot,
  "."
)

if ($DryRun) {
  Write-Host "[DRY_RUN] tar $($tarArgs -join ' ')"
} else {
  & tar @tarArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo creando archivo tar local"
  }
}

Write-Host "[2/6] Validando acceso remoto"
Invoke-RemoteCommand "set -e; test -d '$RemoteAppDir'; test -d '$RemoteAppDir/ops'"

if ($purgeSnapshotsEffective) {
  Write-Host "[2b/6] Limpiando snapshots remotos antiguos"
  Invoke-RemoteCommand "set -e; mkdir -p $RemoteAppDir/ops/snapshots; find $RemoteAppDir/ops/snapshots -maxdepth 1 -type f -delete"
}

if ($CreateSnapshot) {
  Write-Host "[3/6] Snapshot remoto (opcional)"
  Invoke-RemoteCommand "bash /servidor/ops/pre_sync_snapshot.sh"
} else {
  Write-Host "[3/6] Snapshot omitido (CreateSnapshot=false)"
}

if ($BackupSensitive) {
  Write-Host "[4/6] Backup sensible remoto (opcional)"
  $backupCmd = "set -e; cd $RemoteAppDir; mkdir -p ops/snapshots; stamp=`$(date +%F_%H%M%S); [ -f docker-compose.yml ] && cp docker-compose.yml ops/snapshots/docker-compose.`${stamp}.yml || true; [ -d data/nginx ] && tar -C . -I 'zstd -T0 -3' -cf ops/snapshots/nginx_data.`${stamp}.tar.zst data/nginx || true"
  Invoke-RemoteCommand $backupCmd
} else {
  Write-Host "[4/6] Backup sensible omitido (BackupSensitive=false)"
}

Write-Host "[5/6] Subiendo artefacto y aplicando en PROD"
try {
  Invoke-ScpUpload -LocalPath $archivePath -RemotePath $remoteArchive
  Invoke-RemoteCommand "set -e; mkdir -p $RemoteAppDir; tar -xf $remoteArchive -C $RemoteAppDir --no-same-owner --no-same-permissions --touch; rm -f $remoteArchive"

  if ($IncludeOpenClawConfig) {
    Write-Host "[5b/6] Subiendo openclaw.json (explicito)"
    if (-not (Test-Path $localOpenClawConfig)) {
      throw "No existe config local: $localOpenClawConfig"
    }

    if ($BackupOpenClawConfig) {
      $backupOpenClawCmd = "set -e; stamp=`$(date +%F_%H%M%S); mkdir -p $RemoteAppDir/ops/snapshots; [ -f $remoteOpenClawConfig ] && cp $remoteOpenClawConfig $RemoteAppDir/ops/snapshots/openclaw.json.`${stamp}.bak || true"
      Invoke-RemoteCommand $backupOpenClawCmd
    }

    Invoke-RemoteCommand "set -e; mkdir -p $RemoteAppDir/openclaw_home"
    Invoke-ScpUpload -LocalPath $localOpenClawConfig -RemotePath $remoteOpenClawConfig
  }
}
finally {
  if ((-not $DryRun) -and (Test-Path $archivePath)) {
    Remove-Item $archivePath -Force -ErrorAction SilentlyContinue
  }
}

if (-not [string]::IsNullOrWhiteSpace($MigrationCmd)) {
  Write-Host "[6/6] Migraciones y servicios"
  Invoke-RemoteCommand "cd $RemoteAppDir; $MigrationCmd"
} else {
  Write-Host "[6/6] Reinicio servicios"
}

if ($PullExternalImages) {
  Invoke-RemoteCommand "cd $RemoteAppDir; docker compose pull; docker compose up -d --remove-orphans"
} else {
  Invoke-RemoteCommand "cd $RemoteAppDir; docker compose up -d --remove-orphans"
}

Write-Host "Deploy directo finalizado."
