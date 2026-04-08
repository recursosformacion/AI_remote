param(
  [string]$RemoteHost = "91.134.255.134",

  [string]$RemoteUser = "ocw",

  [string]$RemoteAppDir = "/servidor",

  [string]$Branch = "main",

  [switch]$DryRun,

  [switch]$AllowSensitiveChanges,

  [switch]$SkipGitCheck,

  [switch]$StrictSnapshot,

  [string]$MigrationCmd
)

$ErrorActionPreference = "Stop"

$dryRunValue = if ($DryRun) { "1" } else { "0" }
$allowSensitiveValue = if ($AllowSensitiveChanges) { "1" } else { "0" }
$skipGitCheckValue = if ($SkipGitCheck) { "1" } else { "0" }

function Invoke-LocalCommand {
  param([string]$Command)

  if ($DryRun) {
    Write-Host "[DRY_RUN] $Command"
    return
  }

  & powershell -NoProfile -Command $Command
  if ($LASTEXITCODE -ne 0) {
    throw "Falló comando local: $Command"
  }
}

function Invoke-RemoteCommand {
  param([string]$RemoteCommand)

  $target = "$RemoteUser@$RemoteHost"
  if ($DryRun) {
    Write-Host "[DRY_RUN] ssh $target \"$RemoteCommand\""
    return
  }

  & ssh $target $RemoteCommand
  if ($LASTEXITCODE -ne 0) {
    throw "Falló comando remoto: $RemoteCommand"
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
    throw "Falló subida SCP: $LocalPath -> $target"
  }
}

function Get-LocalCommandOutput {
  param([string]$Command)
  $output = & powershell -NoProfile -Command $Command
  if ($LASTEXITCODE -ne 0) {
    throw "Falló comando local: $Command"
  }
  return $output
}

Write-Host "=============================================="
Write-Host " Deploy seguro -> producción (PowerShell)"
Write-Host "=============================================="
Write-Host "Remoto     : ${RemoteUser}@${RemoteHost}:${RemoteAppDir}"
Write-Host "Rama       : $Branch"
Write-Host "DryRun     : $dryRunValue"
Write-Host "Sensitive  : $allowSensitiveValue"
Write-Host "SkipGit    : $skipGitCheckValue"
Write-Host "StrictSnap : $($StrictSnapshot.IsPresent)"
if ($MigrationCmd) { Write-Host "Migraciones: $MigrationCmd" }
Write-Host ""

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git no está disponible en Windows/PATH."
}

Write-Host "[1/8] Validando estado git local"
if ($SkipGitCheck) {
  Write-Host "[WARN] Validación git omitida por -SkipGitCheck"
} else {
  $status = (Get-LocalCommandOutput "git status --porcelain") -join "`n"
  if (-not [string]::IsNullOrWhiteSpace($status)) {
    throw "Hay cambios sin commit. Haz commit/stash antes de desplegar."
  }

  $currentBranch = (Get-LocalCommandOutput "git rev-parse --abbrev-ref HEAD" | Select-Object -First 1).Trim()
  if ($currentBranch -ne $Branch) {
    throw "Rama actual: $currentBranch (esperada: $Branch)"
  }
}

Write-Host "[2/8] Revisando cambios sensibles (nginx/docker-compose)"
$hasOriginBranch = $true
& git show-ref --verify --quiet "refs/remotes/origin/$Branch"
if ($LASTEXITCODE -ne 0) {
  $hasOriginBranch = $false
}

$changedFiles = @()
if ($hasOriginBranch) {
  $changedFiles = Get-LocalCommandOutput "git diff --name-only origin/$Branch...$Branch"
} else {
  & git rev-parse --verify --quiet "HEAD~1"
  if ($LASTEXITCODE -eq 0) {
    Write-Host "[WARN] No existe origin/$Branch; usando diff local HEAD~1..HEAD."
    $changedFiles = Get-LocalCommandOutput "git diff --name-only HEAD~1..HEAD"
  } else {
    Write-Host "[WARN] Sin origin/$Branch y sin histórico local suficiente; no se puede calcular diff de seguridad."
  }
}

$sensitiveHits = @()
foreach ($filePath in $changedFiles) {
  if ($filePath -like "docker-compose*.yml" -or $filePath -like "data/nginx/*" -or $filePath -like "letsencrypt/*") {
    $sensitiveHits += $filePath
  }
}

if ($sensitiveHits.Count -gt 0) {
  Write-Host "Se detectaron cambios sensibles:"
  $sensitiveHits | ForEach-Object { Write-Host " - $_" }
  if (-not $AllowSensitiveChanges) {
    throw "Abortado por seguridad. Relanza con -AllowSensitiveChanges si confirmas estos cambios."
  }
  Write-Host "[WARN] Continuando por -AllowSensitiveChanges"
} else {
  Write-Host "Sin cambios sensibles en nginx/docker-compose."
}

Write-Host "[3/8] Publicando rama remota (opcional)"
& git remote get-url origin 1>$null 2>$null
if ($LASTEXITCODE -eq 0) {
  Invoke-LocalCommand "git push origin $Branch"
} else {
  Write-Host "[WARN] Sin remoto origin configurado; se continúa con despliegue por artefacto."
}

Write-Host "[4/8] Snapshot remoto pre-deploy"
try {
  Invoke-RemoteCommand "bash /servidor/ops/pre_sync_snapshot.sh"
} catch {
  if ($StrictSnapshot) {
    throw
  }
  Write-Warning "Snapshot remoto falló, se continúa (usa -StrictSnapshot para abortar)."
}

Write-Host "[5/8] Backup remoto de docker-compose y data/nginx"
$remoteBackupCmd = "set -e; cd $RemoteAppDir; mkdir -p ops/snapshots; stamp=`$(date +%F_%H%M%S); [ -f docker-compose.yml ] && cp docker-compose.yml ops/snapshots/docker-compose.`${stamp}.yml || true; [ -d data/nginx ] && tar -C . -I 'zstd -T0 -3' -cf ops/snapshots/nginx_data.`${stamp}.tar.zst data/nginx || true"
Invoke-RemoteCommand $remoteBackupCmd

Write-Host "[6/8] Subiendo código a producción (/servidor sin git)"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$localArchive = Join-Path $env:TEMP "deploy_$stamp.tar"
$remoteArchive = "/tmp/deploy_$stamp.tar"

try {
  if ($DryRun) {
    Write-Host "[DRY_RUN] git archive --format=tar --output=$localArchive $Branch"
  } else {
    & git archive --format=tar --output=$localArchive $Branch
    if ($LASTEXITCODE -ne 0) {
      throw "Falló git archive para rama $Branch"
    }
  }

  Invoke-ScpUpload -LocalPath $localArchive -RemotePath $remoteArchive
  $remoteExtractCmd = "set -e; mkdir -p $RemoteAppDir; tar -xf $remoteArchive -C $RemoteAppDir; rm -f $remoteArchive"
  Invoke-RemoteCommand $remoteExtractCmd
}
finally {
  if ((-not $DryRun) -and (Test-Path $localArchive)) {
    Remove-Item $localArchive -Force -ErrorAction SilentlyContinue
  }
}

if (-not [string]::IsNullOrWhiteSpace($MigrationCmd)) {
  Write-Host "[7/8] Ejecutando migraciones"
  $remoteMigrationCmd = "cd $RemoteAppDir; $MigrationCmd"
  Invoke-RemoteCommand $remoteMigrationCmd
} else {
  Write-Host "[7/8] Migraciones omitidas (MigrationCmd vacío)"
}

Write-Host "[8/8] Reiniciando servicios docker"
$remoteDockerCmd = "cd $RemoteAppDir; docker compose pull; docker compose up -d --remove-orphans"
Invoke-RemoteCommand $remoteDockerCmd

Write-Host "Deploy finalizado."
