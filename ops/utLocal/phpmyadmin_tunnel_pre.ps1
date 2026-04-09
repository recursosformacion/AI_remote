param(
    [string]$ServerHost = "91.134.255.134",
    [string]$ServerUser = "ocw",
    [int]$LocalPhpMyAdminPort = 8091,
    [int]$RemotePhpMyAdminPort = 8083,
    [string]$RemotePath = "/home/ocw/facturas-pre",
    [string]$EnvFile = ".env.pre.server",
    [string]$ComposeFile = "docker-compose.server.yml",
    [string]$ProjectName = "facturas-pre",
    [switch]$SkipStartPhpMyAdmin
)

$ErrorActionPreference = "Stop"
$remote = "${ServerUser}@${ServerHost}"

if (-not $SkipStartPhpMyAdmin) {
    Write-Host "Levantando phpMyAdmin en PRUEBAS (${ServerHost}:${RemotePath})" -ForegroundColor Cyan
    $remoteUpCmd = "cd '$RemotePath' && docker compose -p '$ProjectName' --env-file '$EnvFile' -f '$ComposeFile' --profile dbadmin up -d phpmyadmin"
    ssh $remote $remoteUpCmd
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo levantar phpMyAdmin en PRUEBAS."
    }
    Write-Host "phpMyAdmin arrancado." -ForegroundColor Green
}

Write-Host ""
Write-Host "Tunnel phpMyAdmin PRUEBAS: http://127.0.0.1:$LocalPhpMyAdminPort  ->  ${ServerHost}:127.0.0.1:$RemotePhpMyAdminPort" -ForegroundColor Yellow
Write-Host "Abre en el navegador: http://127.0.0.1:$LocalPhpMyAdminPort" -ForegroundColor Green
Write-Host "Pulsa Ctrl+C para cerrar el tunel y apagar phpMyAdmin." -ForegroundColor DarkGray
Write-Host ""

try {
    ssh -N -L "${LocalPhpMyAdminPort}:127.0.0.1:${RemotePhpMyAdminPort}" $remote
}
finally {
    Write-Host ""
    Write-Host "Apagando phpMyAdmin PRUEBAS..." -ForegroundColor Yellow
    $remoteDownCmd = "cd '$RemotePath' && docker compose -p '$ProjectName' --env-file '$EnvFile' -f '$ComposeFile' --profile dbadmin stop phpmyadmin"
    ssh $remote $remoteDownCmd
    Write-Host "phpMyAdmin PRUEBAS apagado." -ForegroundColor Green
}
