param(
    [string]$ServerHost = "91.134.255.134",
    [string]$ServerUser = "ocw",
    [int]$LocalPhpMyAdminPort = 8090,
    [int]$RemotePhpMyAdminPort = 8082,
    [int]$LocalMySqlPort = 3308,
    [int]$RemoteMySqlPort = 3307,
    [string]$RemotePath = "/home/ocw/apps/facturas-web",
    [string]$EnvFile = ".env",
    [string]$ComposeFile = "docker-compose.yml",
    [string]$ProjectName = "facturas",
    [ValidateSet("phpmyadmin", "mysql", "both")]
    [string]$Mode = "both",
    [switch]$SkipStartPhpMyAdmin
)

$ErrorActionPreference = "Stop"
$remote = "${ServerUser}@${ServerHost}"

if ($Mode -in @("phpmyadmin", "both") -and -not $SkipStartPhpMyAdmin) {
    Write-Host "Levantando phpMyAdmin remoto en ${ServerHost}:${RemotePath}" -ForegroundColor Cyan
    $remoteUpCmd = "cd '$RemotePath' && docker compose -p '$ProjectName' --env-file '$EnvFile' -f '$ComposeFile' --profile dbadmin up -d phpmyadmin"
    ssh $remote $remoteUpCmd
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo levantar phpMyAdmin remoto."
    }
}

$forwardings = @()

if ($Mode -in @("phpmyadmin", "both")) {
    $forwardings += "${LocalPhpMyAdminPort}:127.0.0.1:${RemotePhpMyAdminPort}"
    Write-Host "Tunnel phpMyAdmin: http://127.0.0.1:$LocalPhpMyAdminPort -> ${ServerHost}:127.0.0.1:$RemotePhpMyAdminPort" -ForegroundColor Yellow
}

if ($Mode -in @("mysql", "both")) {
    $forwardings += "${LocalMySqlPort}:127.0.0.1:${RemoteMySqlPort}"
    Write-Host "Tunnel MySQL: 127.0.0.1:$LocalMySqlPort -> ${ServerHost}:127.0.0.1:$RemoteMySqlPort" -ForegroundColor Yellow
    Write-Host "Conexion sugerida: host=127.0.0.1 port=$LocalMySqlPort" -ForegroundColor Yellow
}

if ($forwardings.Count -eq 0) {
    throw "No se ha configurado ningun forward. Revisa el parametro -Mode."
}

Write-Host "Abriendo tunel SSH. Pulsa Ctrl+C para cerrar." -ForegroundColor Cyan
$sshArgs = @("-N")
foreach ($fwd in $forwardings) {
    $sshArgs += @("-L", $fwd)
}
$sshArgs += $remote

ssh @sshArgs
