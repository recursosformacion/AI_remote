param(
  [ValidateSet('validate','start','stop','restart','status','logs','tunnel-start','tunnel-stop','tunnel-status')]
  [string]$Action = 'status',
  [switch]$MainOnly,
  [switch]$FacturasOnly,
  [string]$HtmlEnvFile = 'D:\Proyectos\AI_recolectorFacturas\Web\.env.server',
  [int]$Tail = 120,
  [bool]$SyncProdDbOnStart = $true,
  [bool]$FailIfProdDbSyncFail = $false,
  [string]$ProdSshTarget = 'ocw@91.134.255.134',
  [int]$ProdSshPort = 22,
  [string]$ProdDbContainer = 'facturas-db-1',
  [string]$ProdDbName = 'facturas',
  [string]$ProdDbUser = 'root',
  [string]$ProdDbPass = '',
  [string]$LocalDbContainer = 'html-db-1',
  [string]$LocalDbSyncUser = 'root',
  [string]$LocalDbSyncPass = '',
  [bool]$StartTunnelOnStart = $true,
  [string]$CloudflaredExePath = 'D:\Proyectos\AI_Servidor\web\ops\cloudflared-windows-amd64.exe',
  [string]$CloudflaredConfigPath = 'D:\RF_GIT\.cloudflared\configPre.yml'
)

$ErrorActionPreference = 'Stop'

$rootPath = 'D:\Proyectos\AI_Servidor\web'
$htmlPath = Join-Path $rootPath 'html'
$rootCompose = Join-Path $rootPath 'docker-compose.yml'
$htmlCompose = Join-Path $htmlPath 'docker-compose.server.yml'

function Get-EnvFileValue {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string]$Key
  )

  if (!(Test-Path $FilePath)) {
    return $null
  }

  $line = Get-Content -Path $FilePath | Where-Object { $_ -match "^\s*$Key\s*=" } | Select-Object -First 1
  if (-not $line) {
    return $null
  }

  $value = ($line -split '=', 2)[1].Trim()
  if ($value.StartsWith('"') -and $value.EndsWith('"')) {
    $value = $value.Substring(1, $value.Length - 2)
  }
  elseif ($value.StartsWith("'") -and $value.EndsWith("'")) {
    $value = $value.Substring(1, $value.Length - 2)
  }

  return $value
}

function Get-EnvFileValueOrDefault {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string]$Key,
    [AllowEmptyString()][string]$DefaultValue = ''
  )

  $value = Get-EnvFileValue -FilePath $FilePath -Key $Key
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $DefaultValue
  }
  return $value
}

function ConvertTo-Bool {
  param(
    [string]$Value,
    [bool]$Default = $false
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $Default
  }

  switch ($Value.Trim().ToLowerInvariant()) {
    '1' { return $true }
    'true' { return $true }
    'yes' { return $true }
    'y' { return $true }
    'on' { return $true }
    '0' { return $false }
    'false' { return $false }
    'no' { return $false }
    'n' { return $false }
    'off' { return $false }
    default { return $Default }
  }
}

function Test-DockerNetworkExists {
  param([string]$NetworkName)

  if ([string]::IsNullOrWhiteSpace($NetworkName)) {
    return $false
  }

  & docker network inspect $NetworkName *> $null
  return ($LASTEXITCODE -eq 0)
}

function Get-EdgeNetworkCandidates {
  $names = (& docker network ls --format '{{.Name}}')
  if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo listar redes Docker para resolver NPM_NETWORK.'
  }

  $filtered = @($names | Where-Object {
    $_ -match '(^|_)edge_net$' -or $_ -eq 'edge_net'
  })

  return ,$filtered
}

function Test-DockerContainerExists {
  param([Parameter(Mandatory = $true)][string]$ContainerName)

  & docker container inspect $ContainerName *> $null
  return ($LASTEXITCODE -eq 0)
}

function Wait-ContainerHealthy {
  param(
    [Parameter(Mandatory = $true)][string]$ContainerName,
    [int]$TimeoutSeconds = 120
  )

  $startedAt = Get-Date
  while (((Get-Date) - $startedAt).TotalSeconds -lt $TimeoutSeconds) {
    $isRunning = (& docker inspect -f '{{.State.Running}}' $ContainerName 2>$null)
    if ($LASTEXITCODE -ne 0) {
      throw "No se pudo inspeccionar el contenedor $ContainerName"
    }

    if ($isRunning -ne 'true') {
      Start-Sleep -Seconds 2
      continue
    }

    $healthStatus = (& docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $ContainerName 2>$null)
    if ($LASTEXITCODE -ne 0) {
      throw "No se pudo consultar health del contenedor $ContainerName"
    }

    if ($healthStatus -eq 'healthy' -or $healthStatus -eq 'none') {
      return
    }

    if ($healthStatus -eq 'unhealthy') {
      throw "El contenedor $ContainerName esta unhealthy"
    }

    Start-Sleep -Seconds 2
  }

  throw "Timeout esperando a que $ContainerName este listo"
}

function ConvertTo-PosixSingleQuoted {
  param([Parameter(Mandatory = $true)][string]$Value)
  $escaped = $Value -replace '''', '''"''"'''
  return "'" + $escaped + "'"
}

function Sync-ProdDbToLocal {
  if (!(Test-Path $HtmlEnvFile)) {
    throw "No existe env de facturas para sincronizar BD: $HtmlEnvFile"
  }

  $syncEnabled = $SyncProdDbOnStart
  if (-not $syncEnabled) {
    Write-Host "[FACTURAS] Sync PROD->LOCAL desactivada en parametros. Se omite sincronizacion de BD."
    return
  }

  $failOnSyncError = $FailIfProdDbSyncFail

  $dbName = Get-EnvFileValueOrDefault -FilePath $HtmlEnvFile -Key 'DB_NAME' -DefaultValue 'facturas'
  $localDbContainer = $LocalDbContainer
  $localDbUser = $LocalDbSyncUser
  $localDbPass = $LocalDbSyncPass
  if ([string]::IsNullOrWhiteSpace($localDbPass)) {
    $localDbPass = Get-EnvFileValueOrDefault -FilePath $HtmlEnvFile -Key 'DB_ROOT_PASSWORD' -DefaultValue ''
  }

  $prodDbNameEffective = $ProdDbName
  if ([string]::IsNullOrWhiteSpace($prodDbNameEffective)) {
    $prodDbNameEffective = $dbName
  }

  $prodDbPassEffective = $ProdDbPass
  if ([string]::IsNullOrWhiteSpace($prodDbPassEffective)) {
    $prodDbPassEffective = Get-EnvFileValueOrDefault -FilePath $HtmlEnvFile -Key 'DB_ROOT_PASSWORD' -DefaultValue ''
  }

  if ([string]::IsNullOrWhiteSpace($localDbPass)) {
    throw 'LOCAL_DB_SYNC_PASS/DB_ROOT_PASSWORD vacio. No se puede importar BD local.'
  }
  if ([string]::IsNullOrWhiteSpace($prodDbPassEffective)) {
    throw 'PROD_DB_PASS/DB_ROOT_PASSWORD vacio. No se puede extraer BD origen.'
  }
  if ([string]::IsNullOrWhiteSpace($prodSshTarget)) {
    throw 'PROD_SSH_TARGET vacio. No se puede abrir conexion SSH a PROD.'
  }

  $sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
  if ($null -eq $sshCmd) {
    throw 'No se encontro el comando ssh en esta maquina.'
  }
  $sshExe = $sshCmd.Source
  if (-not (Test-DockerContainerExists -ContainerName $localDbContainer)) {
    throw "No existe el contenedor BD local destino: $localDbContainer"
  }

  Write-Host "[FACTURAS] Esperando BD local lista: $localDbContainer"
  Wait-ContainerHealthy -ContainerName $localDbContainer -TimeoutSeconds 180

  Write-Host "[FACTURAS] Sincronizando BD desde PROD '${prodSshTarget}:$ProdDbContainer/$prodDbNameEffective' hacia '$localDbContainer/$dbName'..."

  $prodDbContainerQ = ConvertTo-PosixSingleQuoted -Value $ProdDbContainer
  $prodDbPassQ = ConvertTo-PosixSingleQuoted -Value $prodDbPassEffective
  $prodDbUserQ = ConvertTo-PosixSingleQuoted -Value $ProdDbUser
  $prodDbNameQ = ConvertTo-PosixSingleQuoted -Value $prodDbNameEffective

  $remoteDumpCmdMaria = @(
    'set -e',
    'if command -v docker >/dev/null 2>&1; then DOCKER_BIN=$(command -v docker)',
    'elif [ -x /usr/bin/docker ]; then DOCKER_BIN=/usr/bin/docker',
    'elif [ -x /usr/local/bin/docker ]; then DOCKER_BIN=/usr/local/bin/docker',
    "else echo 'docker no encontrado en host PROD' >&2; exit 127; fi",
    "`$DOCKER_BIN exec -e MYSQL_PWD=$prodDbPassQ -i $prodDbContainerQ mariadb-dump --single-transaction --quick --skip-lock-tables --user=$prodDbUserQ $prodDbNameQ"
  ) -join '; '

  $remoteDumpCmdMysql = @(
    'set -e',
    'if command -v docker >/dev/null 2>&1; then DOCKER_BIN=$(command -v docker)',
    'elif [ -x /usr/bin/docker ]; then DOCKER_BIN=/usr/bin/docker',
    'elif [ -x /usr/local/bin/docker ]; then DOCKER_BIN=/usr/local/bin/docker',
    "else echo 'docker no encontrado en host PROD' >&2; exit 127; fi",
    "`$DOCKER_BIN exec -e MYSQL_PWD=$prodDbPassQ -i $prodDbContainerQ mysqldump --single-transaction --quick --skip-lock-tables --user=$prodDbUserQ $prodDbNameQ"
  ) -join '; '

  $remoteExecMaria = 'bash -lc ' + (ConvertTo-PosixSingleQuoted -Value $remoteDumpCmdMaria)
  $remoteExecMysql = 'bash -lc ' + (ConvertTo-PosixSingleQuoted -Value $remoteDumpCmdMysql)
  $sshArgsMaria = @('-o','BatchMode=yes','-o','ConnectTimeout=20','-p',$prodSshPort,$prodSshTarget,$remoteExecMaria)
  $sshArgsMysql = @('-o','BatchMode=yes','-o','ConnectTimeout=20','-p',$prodSshPort,$prodSshTarget,$remoteExecMysql)

  $dumpFile = Join-Path $env:TEMP ("facturas_prod_dump_{0}.sql" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  try {
    & $sshExe @sshArgsMaria 1> $dumpFile
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "Export con mariadb-dump fallo (codigo $LASTEXITCODE). Reintentando con mysqldump..."
      if (Test-Path $dumpFile) {
        Remove-Item $dumpFile -Force -ErrorAction SilentlyContinue
      }

      & $sshExe @sshArgsMysql 1> $dumpFile
    }

    if ($LASTEXITCODE -ne 0) {
      $msg = "Fallo exportando dump por SSH desde PROD (codigo $LASTEXITCODE)"
      if ($LASTEXITCODE -eq 127) {
        $msg += '. Revisa PATH/docker en shell no interactiva de PROD o usa usuario con docker en PATH.'
      }
      if ($failOnSyncError) {
        throw $msg
      }
      Write-Warning "$msg. Se continua con la BD local actual."
      return
    }

    if (!(Test-Path $dumpFile) -or (Get-Item $dumpFile).Length -lt 50) {
      $msg = 'El dump recibido de PROD esta vacio o no valido.'
      if ($failOnSyncError) {
        throw $msg
      }
      Write-Warning "$msg Se continua con la BD local actual."
      return
    }

    $localDbUserQ = ConvertTo-PosixSingleQuoted -Value $localDbUser
    $dbNameQ = ConvertTo-PosixSingleQuoted -Value $dbName
    $localImportCmd = "if command -v mariadb >/dev/null 2>&1; then mariadb --user=$localDbUserQ $dbNameQ; elif command -v mysql >/dev/null 2>&1; then mysql --user=$localDbUserQ $dbNameQ; else echo 'ni mariadb ni mysql disponible en contenedor local' >&2; exit 127; fi"

    Get-Content -Path $dumpFile -ReadCount 1000 | & docker exec -i -e "MYSQL_PWD=$localDbPass" $localDbContainer sh -lc $localImportCmd
    if ($LASTEXITCODE -ne 0) {
      $msg = "Fallo importando dump en BD local (codigo $LASTEXITCODE)"
      if ($failOnSyncError) {
        throw $msg
      }
      Write-Warning "$msg. Se continua con la BD local actual."
      return
    }
  }
  finally {
    if (Test-Path $dumpFile) {
      Remove-Item $dumpFile -Force -ErrorAction SilentlyContinue
    }
  }

  Write-Host '[FACTURAS] Sincronizacion de BD completada.'
}

function Start-CloudflaredTunnel {
  if (-not $StartTunnelOnStart) {
    Write-Host '[TUNNEL] Inicio de tunel desactivado por parametro.'
    return
  }

  if (!(Test-Path $CloudflaredExePath)) {
    Write-Warning "[TUNNEL] No existe ejecutable cloudflared: $CloudflaredExePath"
    return
  }
  if (!(Test-Path $CloudflaredConfigPath)) {
    Write-Warning "[TUNNEL] No existe config cloudflared: $CloudflaredConfigPath"
    return
  }

  $alreadyRunning = Get-CimInstance Win32_Process -Filter "Name LIKE 'cloudflared%'" |
    Where-Object {
      $_.CommandLine -and $_.CommandLine -match [regex]::Escape($CloudflaredConfigPath)
    } |
    Select-Object -First 1

  if ($alreadyRunning) {
    Write-Host "[TUNNEL] Ya hay un cloudflared activo para esa config (PID $($alreadyRunning.ProcessId))."
    return
  }

  Start-Process -FilePath $CloudflaredExePath -ArgumentList @('tunnel','--config',$CloudflaredConfigPath,'run') -WindowStyle Minimized
  Write-Host "[TUNNEL] Cloudflared iniciado con config: $CloudflaredConfigPath"
}

function Get-CloudflaredTunnelProcess {
  return Get-CimInstance Win32_Process -Filter "Name LIKE 'cloudflared%'" |
    Where-Object {
      $_.CommandLine -and $_.CommandLine -match [regex]::Escape($CloudflaredConfigPath)
    } |
    Select-Object -First 1
}

function Stop-CloudflaredTunnel {
  $process = Get-CloudflaredTunnelProcess
  if (-not $process) {
    Write-Host '[TUNNEL] No hay cloudflared activo para esa config.'
    return
  }

  Stop-Process -Id $process.ProcessId -Force
  Write-Host "[TUNNEL] Cloudflared detenido (PID $($process.ProcessId))."
}

function Show-CloudflaredTunnelStatus {
  $process = Get-CloudflaredTunnelProcess
  if (-not $process) {
    Write-Host '[TUNNEL] Estado: detenido (sin proceso activo para esa config).'
    return
  }

  Write-Host "[TUNNEL] Estado: activo (PID $($process.ProcessId))."
  Write-Host "[TUNNEL] CommandLine: $($process.CommandLine)"
}

function Invoke-DockerComposeRoot {
  param([string[]]$ComposeArgs)
  Push-Location $rootPath
  try {
    $allArgs = @('-f', $rootCompose) + $ComposeArgs
    & docker compose @allArgs
    if ($LASTEXITCODE -ne 0) {
      throw "docker compose root fallo con codigo $LASTEXITCODE"
    }
  }
  finally {
    Pop-Location
  }
}

function Invoke-DockerComposeFacturas {
  param([string[]]$ComposeArgs)
  if (!(Test-Path $htmlCompose)) {
    throw "No existe $htmlCompose"
  }
  if (!(Test-Path $HtmlEnvFile) -and ($Action -ne 'status')) {
    throw "No existe env de facturas: $HtmlEnvFile"
  }

  Push-Location $htmlPath
  $previousNpmNetwork = $env:NPM_NETWORK
  $overrideNetwork = $false
  try {
    $expectedNpmNetwork = Get-EnvFileValue -FilePath $HtmlEnvFile -Key 'NPM_NETWORK'
    if ([string]::IsNullOrWhiteSpace($expectedNpmNetwork)) {
      $expectedNpmNetwork = 'npm_default'
    }

    if (-not (Test-DockerNetworkExists -NetworkName $expectedNpmNetwork)) {
      $edgeCandidates = Get-EdgeNetworkCandidates
      if ($edgeCandidates.Count -eq 1) {
        $env:NPM_NETWORK = $edgeCandidates[0]
        $overrideNetwork = $true
        Write-Warning "NPM_NETWORK '$expectedNpmNetwork' no existe. Usando '$($env:NPM_NETWORK)' para este comando."
      }
      elseif ($edgeCandidates.Count -gt 1) {
        throw "NPM_NETWORK '$expectedNpmNetwork' no existe. Redes edge detectadas: $($edgeCandidates -join ', '). Ajusta NPM_NETWORK en $HtmlEnvFile."
      }
      else {
        throw "NPM_NETWORK '$expectedNpmNetwork' no existe y no se detectaron redes edge. Arranca el stack MAIN o corrige NPM_NETWORK en $HtmlEnvFile."
      }
    }

    $baseArgs = @('-f', $htmlCompose)
    if (Test-Path $HtmlEnvFile) {
      $baseArgs = @('--env-file', $HtmlEnvFile) + $baseArgs
    }
    $allArgs = $baseArgs + $ComposeArgs
    & docker compose @allArgs
    if ($LASTEXITCODE -ne 0) {
      throw "docker compose facturas fallo con codigo $LASTEXITCODE"
    }
  }
  finally {
    if ($overrideNetwork) {
      if ($null -eq $previousNpmNetwork) {
        Remove-Item Env:NPM_NETWORK -ErrorAction SilentlyContinue
      }
      else {
        $env:NPM_NETWORK = $previousNpmNetwork
      }
    }
    Pop-Location
  }
}

$runMain = -not $FacturasOnly
$runFacturas = -not $MainOnly

Write-Host "== Plan deploy operativo =="
Write-Host "Accion: $Action"
Write-Host "Main: $runMain | Facturas: $runFacturas"

switch ($Action) {
  'validate' {
    if ($runMain) {
      Write-Host "[MAIN] Validando compose raiz..."
      Invoke-DockerComposeRoot -ComposeArgs @('config')
    }
    if ($runFacturas) {
      Write-Host "[FACTURAS] Validando compose server..."
      Invoke-DockerComposeFacturas -ComposeArgs @('config')
    }
  }
  'start' {
    if ($runMain) {
      Write-Host "[MAIN] Levantando nginx + web_dominio..."
      Invoke-DockerComposeRoot -ComposeArgs @('up','-d')
    }
    if ($runFacturas) {
      Write-Host "[FACTURAS] Levantando stack facturas..."
      Invoke-DockerComposeFacturas -ComposeArgs @('up','-d','--build')
      Sync-ProdDbToLocal
    }
    if ($runMain -and $runFacturas) {
      Start-CloudflaredTunnel
    }
  }
  'stop' {
    if ($runFacturas) {
      Write-Host "[FACTURAS] Parando stack facturas..."
      Invoke-DockerComposeFacturas -ComposeArgs @('down')
    }
    if ($runMain) {
      Write-Host "[MAIN] Parando stack raiz..."
      Invoke-DockerComposeRoot -ComposeArgs @('down')
    }
  }
  'restart' {
    if ($runMain) {
      Write-Host "[MAIN] Reiniciando stack raiz..."
      Invoke-DockerComposeRoot -ComposeArgs @('up','-d','--force-recreate')
    }
    if ($runFacturas) {
      Write-Host "[FACTURAS] Reiniciando stack facturas..."
      Invoke-DockerComposeFacturas -ComposeArgs @('up','-d','--build','--force-recreate')
    }
  }
  'status' {
    if ($runMain) {
      Write-Host "[MAIN] Estado contenedores raiz"
      Invoke-DockerComposeRoot -ComposeArgs @('ps')
    }
    if ($runFacturas) {
      Write-Host "[FACTURAS] Estado contenedores facturas"
      Invoke-DockerComposeFacturas -ComposeArgs @('ps')
    }
  }
  'logs' {
    if ($runMain) {
      Write-Host "[MAIN] Logs raiz"
      Invoke-DockerComposeRoot -ComposeArgs @('logs','--tail',"$Tail")
    }
    if ($runFacturas) {
      Write-Host "[FACTURAS] Logs facturas"
      Invoke-DockerComposeFacturas -ComposeArgs @('logs','--tail',"$Tail")
    }
  }
  'tunnel-start' {
    Start-CloudflaredTunnel
  }
  'tunnel-stop' {
    Stop-CloudflaredTunnel
  }
  'tunnel-status' {
    Show-CloudflaredTunnelStatus
  }
  default {
    throw "Accion no soportada: $Action"
  }
}
