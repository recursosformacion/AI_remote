#!/usr/bin/env bash
set -euo pipefail

LOCAL_MIRROR_DIR="/mnt/d/Proyectos/remoteIA/web"
REMOTE_BASE_DIR="/servidor"

usage() {
  echo "Uso: $0 <remote_host> [remote_user] [domain_mode]"
  echo "domain_mode: none | dual | to-local | to-prod (default: to-local)"
  echo "Ejemplo: $0 mi-servidor.com ocw to-local"
}

if [[ "${1:-}" == "" ]]; then
  usage
  exit 1
fi

REMOTE_HOST="$1"
REMOTE_USER="${2:-ocw}"
DOMAIN_MODE="${3:-to-local}"

if [[ "$DOMAIN_MODE" != "none" && "$DOMAIN_MODE" != "dual" && "$DOMAIN_MODE" != "to-local" && "$DOMAIN_MODE" != "to-prod" ]]; then
  echo "domain_mode inválido: $DOMAIN_MODE (usa none|dual|to-local|to-prod)"
  exit 1
fi

if [[ ! -d "/mnt/d" ]]; then
  echo "Este script está pensado para WSL (ruta /mnt/d no existe)."
  exit 1
fi

mkdir -p "$LOCAL_MIRROR_DIR"

echo "=============================================="
echo " Mirror prod -> local (WSL)"
echo "=============================================="
echo "Remoto: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}"
echo "Local : ${LOCAL_MIRROR_DIR}"
echo "Dominios NPM: ${DOMAIN_MODE}"
echo

echo "[1/5] Snapshot remoto previo"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "bash ${REMOTE_BASE_DIR}/ops/pre_sync_snapshot.sh" || {
  echo "No se pudo ejecutar snapshot remoto. Revisa SSH o ruta del script."
  exit 1
}
echo

EXCLUDES=(
  --exclude='**/*.pid'
  --exclude='**/*.sock'
  --exclude='**/*.lock'
  --exclude='**/tmp/**'
  --exclude='**/.cache/**'
  --exclude='**/node_modules/**'
  --exclude='**/.vscode-server/**'
  --exclude='**/*.log'
  --exclude='**/*.log.[1-9]*'
  --exclude='**/*.gz'
)

echo "[2/5] Simulación (dry-run)"
rsync -az --delete --itemize-changes "${EXCLUDES[@]}" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/docker-compose.yml" \
  "${LOCAL_MIRROR_DIR}/"

rsync -az --delete --itemize-changes "${EXCLUDES[@]}" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/.env" \
  "${LOCAL_MIRROR_DIR}/"

for p in data html letsencrypt openclaw_home ops; do
  rsync -az --delete --dry-run --itemize-changes "${EXCLUDES[@]}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/${p}/" \
    "${LOCAL_MIRROR_DIR}/${p}/"
done
echo

read -r -p "¿Aplicar sincronización real ahora? [s/N]: " do_apply
if [[ ! "$do_apply" =~ ^[sS]$ ]]; then
  echo "Sincronización cancelada por usuario."
  exit 0
fi

echo
echo "[3/5] Aplicando sincronización"
rsync -az --delete "${EXCLUDES[@]}" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/docker-compose.yml" \
  "${LOCAL_MIRROR_DIR}/"

rsync -az --delete "${EXCLUDES[@]}" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/.env" \
  "${LOCAL_MIRROR_DIR}/"

for p in data html letsencrypt openclaw_home ops; do
  rsync -az --delete "${EXCLUDES[@]}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/${p}/" \
    "${LOCAL_MIRROR_DIR}/${p}/"
done
echo

if [[ "$DOMAIN_MODE" != "none" ]]; then
  echo "[4/6] Normalizando dominios NPM (${DOMAIN_MODE})"
  NPM_DB_PATH="${LOCAL_MIRROR_DIR}/data/database.sqlite"
  NPM_SCRIPT="${LOCAL_MIRROR_DIR}/ops/unify_npm_domain_aliases.sh"

  if [[ ! -f "$NPM_DB_PATH" ]]; then
    echo "[WARN] No existe DB NPM local en ${NPM_DB_PATH}. Se omite normalización."
  elif [[ ! -f "$NPM_SCRIPT" ]]; then
    echo "[WARN] No existe script ${NPM_SCRIPT}. Se omite normalización."
  elif ! command -v sqlite3 >/dev/null 2>&1; then
    echo "[WARN] Falta sqlite3 en WSL. Se omite normalización."
  else
    bash "$NPM_SCRIPT" "$NPM_DB_PATH" apply "$DOMAIN_MODE"
  fi
  echo
fi

echo "[5/6] Verificación final (dry-run)"
pending=0
for p in data html letsencrypt openclaw_home ops; do
  out="$(rsync -az --delete --dry-run --itemize-changes "${EXCLUDES[@]}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/${p}/" \
    "${LOCAL_MIRROR_DIR}/${p}/" || true)"
  if [[ -n "$(echo "$out" | sed '/^$/d')" ]]; then
    pending=1
    echo "$out"
  fi
done

if [[ "$pending" -eq 0 ]]; then
  echo "OK: espejo local consistente."
else
  echo "ATENCIÓN: quedan diferencias. Revisa salida anterior."
fi
echo

echo "[6/6] (Opcional) Dump DB Docker"
echo "Si quieres incluir backup de base de datos, ejecuta:"
echo "ssh ${REMOTE_USER}@${REMOTE_HOST} \"docker ps --format '{{.Names}}'\""
echo "y luego:"
echo "ssh ${REMOTE_USER}@${REMOTE_HOST} \"docker exec <NOMBRE_CONTENEDOR_DB> sh -c 'pg_dumpall -U postgres'\" > ${LOCAL_MIRROR_DIR}/ops/db_dump.sql"
