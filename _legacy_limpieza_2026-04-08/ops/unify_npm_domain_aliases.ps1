param(
    [string]$DbPath = "./data/database.sqlite",
    [ValidateSet("dry-run", "apply")]
  [string]$Mode = "dry-run",
  [ValidateSet("dual", "to-local", "to-prod")]
  [string]$Strategy = "dual"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $DbPath)) {
    throw "No existe la base de datos: $DbPath"
}

$sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
if (-not $sqlite) {
    throw "No se encontró sqlite3 en PATH."
}

$aliasesExpr = switch ($Strategy) {
    "dual" {
@"
  SELECT id, name FROM names
  UNION
  SELECT
    id,
    CASE
      WHEN name LIKE '%.com' THEN substr(name, 1, length(name) - 4)
      ELSE name || '.com'
    END AS name
  FROM names
"@
    }
    "to-local" {
@"
  SELECT
    id,
    CASE
      WHEN name LIKE '%.com' THEN substr(name, 1, length(name) - 4)
      ELSE name
    END AS name
  FROM names
"@
    }
    "to-prod" {
@"
  SELECT
    id,
    CASE
      WHEN name LIKE '%.com' THEN name
      ELSE name || '.com'
    END AS name
  FROM names
"@
    }
}

$sqlPreview = @"
WITH names AS (
  SELECT p.id, json_each.value AS name
  FROM proxy_host p, json_each(p.domain_names)
),
aliases AS (
$aliasesExpr
),
dedup AS (
  SELECT id, name
  FROM aliases
  GROUP BY id, name
),
final AS (
  SELECT id, json_group_array(name) AS merged_names
  FROM dedup
  GROUP BY id
)
SELECT p.id,
       p.domain_names AS before,
       f.merged_names AS after
FROM proxy_host p
JOIN final f ON f.id = p.id
WHERE p.domain_names <> f.merged_names
ORDER BY p.id;
"@

$sqlApply = @"
WITH names AS (
  SELECT p.id, json_each.value AS name
  FROM proxy_host p, json_each(p.domain_names)
),
aliases AS (
$aliasesExpr
),
dedup AS (
  SELECT id, name
  FROM aliases
  GROUP BY id, name
),
final AS (
  SELECT id, json_group_array(name) AS merged_names
  FROM dedup
  GROUP BY id
)
UPDATE proxy_host
SET domain_names = (
  SELECT merged_names
  FROM final
  WHERE final.id = proxy_host.id
)
WHERE id IN (
  SELECT p.id
  FROM proxy_host p
  JOIN final f ON f.id = p.id
  WHERE p.domain_names <> f.merged_names
);
"@

Write-Host "==============================================="
Write-Host " Normalización de dominios (NPM)"
Write-Host "==============================================="
Write-Host "DB   : $DbPath"
Write-Host "Modo : $Mode"
Write-Host "Plan : $Strategy"
Write-Host ""

$totalHosts = (& sqlite3 $DbPath "SELECT COUNT(*) FROM proxy_host WHERE is_deleted = 0;")
$comHosts = (& sqlite3 $DbPath "SELECT COUNT(*) FROM proxy_host p, json_each(p.domain_names) j WHERE p.is_deleted = 0 AND j.value LIKE '%.com';")
Write-Host "Hosts activos: $totalHosts (con .com: $comHosts)"
if ($Strategy -eq "to-local" -and $comHosts -eq "0") {
  Write-Host "[INFO] No hay dominios .com en esta BD; to-local no propondrá cambios."
}
Write-Host ""

Write-Host "[Preview] Cambios detectados:"
& sqlite3 $DbPath $sqlPreview

if ($Mode -eq "dry-run") {
    Write-Host ""
    Write-Host "Dry-run completado."
  Write-Host "Para aplicar: ./ops/unify_npm_domain_aliases.ps1 -DbPath \"$DbPath\" -Mode apply -Strategy $Strategy"
    exit 0
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "$DbPath.bak.$stamp"
Copy-Item -LiteralPath $DbPath -Destination $backupPath -Force
Write-Host ""
Write-Host "Backup creado: $backupPath"

& sqlite3 $DbPath $sqlApply

Write-Host ""
Write-Host "Cambios aplicados. Estado final:"
& sqlite3 $DbPath "SELECT id, domain_names FROM proxy_host ORDER BY id;"

Write-Host ""
Write-Host "Siguiente paso recomendado: reiniciar Nginx Proxy Manager para regenerar confs."
Write-Host "Ejemplo: docker restart gestor_trafico"
