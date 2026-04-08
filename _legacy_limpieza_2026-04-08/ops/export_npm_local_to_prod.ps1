param(
  [string]$RemoteHost = "91.134.255.134",
  [string]$RemoteUser = "ocw",
  [string]$RemoteAppDir = "/servidor",
  [ValidateSet("dry-run", "apply")]
  [string]$Mode = "dry-run",
  [switch]$WithSnapshot,
  [switch]$UploadHtpasswd,
  [int]$MinFreeMb = 1024
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

$localDb = Join-Path $rootDir "data\database.sqlite"
$localCustomDir = Join-Path $rootDir "data\nginx\custom"
$localHtpasswd = Join-Path $rootDir "data\nginx\.htpasswd_openclaw"
$unifyScript = Join-Path $scriptDir "unify_npm_domain_aliases.ps1"

if ([string]::IsNullOrWhiteSpace($RemoteAppDir)) { throw "RemoteAppDir no puede estar vacío." }
if (!(Test-Path $localDb)) { throw "No existe DB local: $localDb" }
if (!(Test-Path $unifyScript)) { throw "No existe script de normalización: $unifyScript" }
if (!(Get-Command sqlite3 -ErrorAction SilentlyContinue)) { throw "No se encontró sqlite3 en PATH local." }

$sshTarget = "$RemoteUser@$RemoteHost"
$sshOpts = @(
  "-o", "BatchMode=yes",
  "-o", "NumberOfPasswordPrompts=0",
  "-o", "PreferredAuthentications=publickey",
  "-o", "ConnectTimeout=15"
)
$scpOpts = @(
  "-o", "BatchMode=yes",
  "-o", "NumberOfPasswordPrompts=0",
  "-o", "PreferredAuthentications=publickey",
  "-o", "ConnectTimeout=15"
)

function Invoke-Ssh {
  param([string]$Command)
  & ssh @sshOpts $sshTarget $Command
  if ($LASTEXITCODE -ne 0) { throw "SSH falló: $Command" }
}

function Invoke-SshCapture {
  param([string]$Command)
  $output = & ssh @sshOpts $sshTarget $Command
  if ($LASTEXITCODE -ne 0) { throw "SSH falló: $Command" }
  return ($output -join "`n").Trim()
}

function Invoke-Scp {
  param([string]$LocalPath, [string]$RemotePath)
  & scp @scpOpts $LocalPath "${sshTarget}:$RemotePath"
  if ($LASTEXITCODE -ne 0) { throw "SCP falló: $LocalPath -> $RemotePath" }
}

$tmpDb = Join-Path $env:TEMP ("npm_prod_export_{0}.sqlite" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
Copy-Item $localDb $tmpDb -Force
$useContainerDbCopy = $false
$remoteDbUploadPath = "$RemoteAppDir/data/database.sqlite"

try {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $unifyScript -DbPath $tmpDb -Mode apply -Strategy to-prod | Out-Null

  $forceRegenSql = @'
UPDATE proxy_host
SET meta=json_object('nginx_online', 0, 'nginx_err', NULL)
WHERE is_deleted=0;
'@
  & sqlite3 $tmpDb $forceRegenSql
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo al preparar DB temporal para regeneración NPM"
  }

  $invalidMetaCount = (& sqlite3 $tmpDb "SELECT COUNT(1) FROM proxy_host WHERE is_deleted=0 AND json_valid(meta)=0;").Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo al validar JSON de meta en DB temporal"
  }
  if ($invalidMetaCount -ne "0") {
    throw "Se detectaron $invalidMetaCount filas con meta inválido en DB temporal"
  }

  $certIdsRaw = (& sqlite3 $tmpDb "SELECT DISTINCT certificate_id FROM proxy_host WHERE is_deleted=0 AND enabled=1 AND IFNULL(certificate_id,0)>0 ORDER BY certificate_id;")
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo al leer certificate_id desde DB temporal"
  }
  $certIds = @($certIdsRaw | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne "" })

  Write-Host "==============================================="
  Write-Host " Export NPM local -> producción (PowerShell)"
  Write-Host "==============================================="
  Write-Host "Remoto        : ${RemoteUser}@${RemoteHost}:${RemoteAppDir}"
  Write-Host "Modo          : $Mode"
  Write-Host "Snapshot      : $($WithSnapshot.IsPresent)"
  Write-Host "UploadHtpasswd: $($UploadHtpasswd.IsPresent)"
  Write-Host "MinFreeMb     : $MinFreeMb"
  Write-Host "DB src        : $localDb"
  Write-Host "DB tmp        : $tmpDb"
  Write-Host ""

  Write-Host "[1/5] Preflight remoto"
  if ($Mode -eq "dry-run") {
    Write-Host "[DRY_RUN] ssh $sshTarget 'test -d $RemoteAppDir/data && test -d $RemoteAppDir/ops && test -d $RemoteAppDir/data/nginx/custom'"
    Write-Host ('[DRY_RUN] ssh {0} "df --output=avail / | tail -n 1"' -f $sshTarget)
    Write-Host "[DRY_RUN] ssh $sshTarget 'test -w $RemoteAppDir/data/database.sqlite'"
    Write-Host "[DRY_RUN] ssh $sshTarget 'test -w $RemoteAppDir/data/nginx/custom'"
    if ($UploadHtpasswd -and (Test-Path $localHtpasswd)) {
      Write-Host "[DRY_RUN] ssh $sshTarget 'test -w $RemoteAppDir/data/nginx/.htpasswd_openclaw'"
    }
    foreach ($certId in $certIds) {
      Write-Host "[DRY_RUN] ssh $sshTarget 'docker exec gestor_trafico sh -lc ''test -f /etc/letsencrypt/live/npm-$certId/fullchain.pem && test -f /etc/letsencrypt/live/npm-$certId/privkey.pem'''"
    }
  } else {
    Invoke-Ssh "test -d '$RemoteAppDir/data' && test -d '$RemoteAppDir/ops' && test -d '$RemoteAppDir/data/nginx/custom'"
    $freeKbRaw = Invoke-SshCapture "df --output=avail / | tail -n 1"
    $freeKb = 0
    if (-not [int]::TryParse($freeKbRaw, [ref]$freeKb)) {
      throw "No se pudo parsear espacio libre remoto: '$freeKbRaw'"
    }
    $requiredKb = $MinFreeMb * 1024
    if ($freeKb -lt $requiredKb) {
      throw "Espacio insuficiente en remoto: ${freeKb}KB disponibles (< ${requiredKb}KB)."
    }

    try {
      Invoke-Ssh "test -w '$RemoteAppDir/data/database.sqlite'"
    }
    catch {
      Write-Host "[INFO] Sin escritura directa en database.sqlite; se usará copia vía contenedor gestor_trafico."
      Invoke-Ssh "docker ps --format '{{.Names}}' | grep -Fx 'gestor_trafico' >/dev/null"
      $useContainerDbCopy = $true
      $remoteDbUploadPath = "/tmp/npm_prod_export_database.sqlite"
    }

    Invoke-Ssh "test -w '$RemoteAppDir/data/nginx/custom'"
    if ($UploadHtpasswd -and (Test-Path $localHtpasswd)) {
      Invoke-Ssh "test -w '$RemoteAppDir/data/nginx/.htpasswd_openclaw'"
    }

    $missingCertIds = @()
    foreach ($certId in $certIds) {
      try {
        Invoke-Ssh "docker exec gestor_trafico sh -lc 'test -f /etc/letsencrypt/live/npm-$certId/fullchain.pem && test -f /etc/letsencrypt/live/npm-$certId/privkey.pem'"
      }
      catch {
        $missingCertIds += $certId
      }
    }
    if ($missingCertIds.Count -gt 0) {
      $missingStr = ($missingCertIds -join ",")
      Write-Warning "Certificados runtime ausentes para certificate_id: $missingStr. La subida continuará, pero esos proxy_host no generarán *.conf hasta emitir/importar sus certificados en PROD."
    }
  }

  Write-Host "[2/5] Snapshot remoto"
  if ($WithSnapshot) {
    if ($Mode -eq "dry-run") {
      Write-Host "[DRY_RUN] ssh $sshTarget 'bash $RemoteAppDir/ops/pre_sync_snapshot.sh'"
    } else {
      Invoke-Ssh "bash '$RemoteAppDir/ops/pre_sync_snapshot.sh'"
    }
  } else {
    Write-Host "Snapshot omitido (usar -WithSnapshot para activarlo)."
  }

  Write-Host "[3/5] Subida NPM (DB + custom + opcional htpasswd)"
  Write-Host "[INFO] /data/nginx/proxy_host/*.conf no se suben: NPM los regenera desde DB al reiniciar."
  if ($Mode -eq "dry-run") {
    Write-Host "[DRY_RUN] scp $tmpDb -> ${sshTarget}:$RemoteAppDir/data/database.sqlite"
    if (Test-Path $localCustomDir) {
      Write-Host "[DRY_RUN] scp -r $localCustomDir/* -> ${sshTarget}:$RemoteAppDir/data/nginx/custom/"
    }
    if ($UploadHtpasswd -and (Test-Path $localHtpasswd)) {
      Write-Host "[DRY_RUN] scp $localHtpasswd -> ${sshTarget}:$RemoteAppDir/data/nginx/.htpasswd_openclaw"
    } elseif (Test-Path $localHtpasswd) {
      Write-Host "[INFO] .htpasswd omitido (usar -UploadHtpasswd para subirlo)."
    }
  } else {
    Invoke-Scp -LocalPath $tmpDb -RemotePath $remoteDbUploadPath

    if ($useContainerDbCopy) {
      Invoke-Ssh "docker cp /tmp/npm_prod_export_database.sqlite gestor_trafico:/tmp/npm_prod_export_database.sqlite && docker exec gestor_trafico sh -lc 'cp /tmp/npm_prod_export_database.sqlite /data/database.sqlite' && rm -f /tmp/npm_prod_export_database.sqlite"
    }

    if (Test-Path $localCustomDir) {
      & scp @scpOpts -r (Join-Path $localCustomDir "*") "${sshTarget}:$RemoteAppDir/data/nginx/custom/"
      if ($LASTEXITCODE -ne 0) {
        throw "SCP falló: $localCustomDir -> $RemoteAppDir/data/nginx/custom/"
      }
    }

    if ($UploadHtpasswd -and (Test-Path $localHtpasswd)) {
      Invoke-Scp -LocalPath $localHtpasswd -RemotePath "$RemoteAppDir/data/nginx/.htpasswd_openclaw"
    } elseif (Test-Path $localHtpasswd) {
      Write-Host "[INFO] .htpasswd omitido (usar -UploadHtpasswd para subirlo)."
    }
  }

  Write-Host "[4/5] Reinicio NPM"
  if ($Mode -eq "dry-run") {
    Write-Host "[DRY_RUN] ssh $sshTarget 'docker restart gestor_trafico'"
  } else {
    Invoke-Ssh "docker restart gestor_trafico >/dev/null"
  }

  Write-Host "[5/5] Verificación mínima"
  if ($Mode -eq "dry-run") {
    Write-Host ('[DRY_RUN] ssh {0} "sqlite3 {1}/data/database.sqlite ''SELECT id,domain_names FROM proxy_host WHERE is_deleted=0 ORDER BY id;''"' -f $sshTarget, $RemoteAppDir)
  } else {
    Invoke-Ssh "sleep 3; sqlite3 '$RemoteAppDir/data/database.sqlite' 'SELECT id,domain_names FROM proxy_host WHERE is_deleted=0 ORDER BY id;'"
  }

  Write-Host ""
  Write-Host "Exportación finalizada: $Mode"
}
finally {
  if (Test-Path $tmpDb) {
    Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue
  }
}
