param(
    [Parameter(Mandatory = $true)]
    [string]$RemoteHost,
    [string]$RemoteUser = "ocw",
    [ValidateSet("none", "dual", "to-local", "to-prod")]
    [string]$DomainMode = "to-local",
    [string]$WslDistro = "Ubuntu"
)

$ErrorActionPreference = "Stop"

$projectWin = (Resolve-Path "$PSScriptRoot\..\..").Path
$scriptWsl = "/mnt/" + $projectWin.Substring(0,1).ToLower() + $projectWin.Substring(2).Replace('\','/') + "/ops/DESCARGA_DE_HOST_PRODUCCION/run_sync_from_wsl.sh"

Write-Host "=============================================="
Write-Host " Launcher PowerShell -> WSL"
Write-Host "=============================================="
Write-Host "Script WSL : $scriptWsl"
Write-Host "Remoto     : $RemoteUser@$RemoteHost"
Write-Host "Dominios   : $DomainMode"
Write-Host ""

$cmd = "bash $scriptWsl $RemoteHost $RemoteUser $DomainMode"

wsl -d $WslDistro -e bash -lc $cmd
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    throw "El script terminó con código $exitCode"
}
