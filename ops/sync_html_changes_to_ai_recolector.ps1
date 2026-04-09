param(
  [string]$SourceRepo = 'D:\Proyectos\AI_Servidor\web\html',
  [string]$TargetRepo = 'D:\Proyectos\AI_recolectorFacturas\Web'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-GitRepo {
  param([string]$Path)
  if (!(Test-Path (Join-Path $Path '.git'))) {
    throw "No existe repo Git en: $Path"
  }
}

Assert-GitRepo -Path $SourceRepo
Assert-GitRepo -Path $TargetRepo

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$patchPath = Join-Path $env:TEMP "sync_html_to_ai_$stamp.patch"

Write-Host "[SYNC] Generando patch desde: $SourceRepo"
& git -C $SourceRepo diff --binary HEAD > $patchPath
if ($LASTEXITCODE -ne 0) {
  throw "Fallo al generar patch (codigo $LASTEXITCODE)"
}

$untracked = @(& git -C $SourceRepo ls-files --others --exclude-standard)

if ((Get-Item $patchPath).Length -eq 0) {
  if ($untracked.Count -gt 0) {
    Write-Host "[SYNC] No hay cambios tracked para transferir, pero hay $($untracked.Count) untracked en origen."
    Write-Host '[SYNC] Haz git add en origen (o crea commit) y vuelve a ejecutar.'
  }
  else {
    Write-Host '[SYNC] No hay cambios para transferir.'
  }
  Remove-Item $patchPath -Force -ErrorAction SilentlyContinue
  exit 0
}

if ($untracked.Count -gt 0) {
  Write-Host "[SYNC] Aviso: hay $($untracked.Count) untracked en origen y no se incluyen en el patch."
  Write-Host '[SYNC] Si quieres incluirlos, haz git add primero en origen.'
}

Write-Host "[SYNC] Aplicando patch en: $TargetRepo"
& git -C $TargetRepo apply --index --reject $patchPath
if ($LASTEXITCODE -ne 0) {
  throw "Fallo al aplicar patch en destino (codigo $LASTEXITCODE)"
}

Remove-Item $patchPath -Force -ErrorAction SilentlyContinue

Write-Host '[SYNC] Transferencia completada.'
Write-Host '[SYNC] Estado destino:'
& git -C $TargetRepo status --short
