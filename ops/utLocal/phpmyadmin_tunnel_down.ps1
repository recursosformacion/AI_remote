param(
    [string]$ServerHost = "91.134.255.134",
    [string]$ServerUser = "ocw",
    [string]$RemotePath = "/home/ocw/apps/facturas-web",
    [string]$EnvFile = ".env",
    [string]$ComposeFile = "docker-compose.yml",
    [string]$ProjectName = "facturas"
)

$ErrorActionPreference = "Stop"
$remote = "$ServerUser@$ServerHost"

Write-Host "Apagando phpMyAdmin remoto en ${ServerHost}:${RemotePath}" -ForegroundColor Yellow
$remoteDownCmd = "cd '$RemotePath' && docker compose -p '$ProjectName' --env-file '$EnvFile' -f '$ComposeFile' --profile dbadmin down phpmyadmin"
ssh $remote $remoteDownCmd

if ($LASTEXITCODE -ne 0) {
    throw "No se pudo apagar phpMyAdmin remoto."
}

Write-Host "phpMyAdmin remoto apagado." -ForegroundColor Green
