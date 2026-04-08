#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="${1:-}"
REMOTE_USER="${2:-ocw}"
MODE="${3:-dry-run}" # dry-run | apply

REMOTE_BASE_DIR="${REMOTE_BASE_DIR:-/servidor}"
LOCAL_BASE_DIR="${LOCAL_BASE_DIR:-/mnt/d/Proyectos/remoteIA/web}"

if [[ -z "$REMOTE_HOST" ]]; then
  echo "Uso: $0 <remote_host> [remote_user] [dry-run|apply]"
  echo "Ejemplo: $0 91.134.255.134 ocw dry-run"
  exit 1
fi

if [[ "$MODE" != "dry-run" && "$MODE" != "apply" ]]; then
  echo "Modo inválido: $MODE (usa dry-run o apply)"
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "Falta rsync en local. Instala rsync y vuelve a ejecutar."
  exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
  echo "Falta ssh en local. Instala openssh-client y vuelve a ejecutar."
  exit 1
fi

echo "================================================="
echo " Bootstrap local desde producción"
echo "================================================="
echo "Remoto : ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}"
echo "Local  : ${LOCAL_BASE_DIR}"
echo "Modo   : ${MODE}"
echo

echo "[1/5] Verificando acceso SSH"
ssh -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo ok" >/dev/null

echo "[2/5] Snapshot remoto previo"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "bash ${REMOTE_BASE_DIR}/ops/pre_sync_snapshot.sh"

mkdir -p "${LOCAL_BASE_DIR}"

RSYNC_FLAGS=(
  -az
  --delete
  --human-readable
  --info=stats2,progress2
  --exclude='**/*.pid'
  --exclude='**/*.sock'
  --exclude='**/*.lock'
  --exclude='**/tmp/**'
  --exclude='**/.cache/**'
  --exclude='**/.vscode-server/**'
  --exclude='**/node_modules/**'
)

if [[ "$MODE" == "dry-run" ]]; then
  RSYNC_FLAGS+=(--dry-run --itemize-changes)
fi

echo "[3/5] Sincronizando archivos raíz"
rsync "${RSYNC_FLAGS[@]}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/docker-compose.yml" "${LOCAL_BASE_DIR}/"

echo "[4/5] Guardando env de producción como snapshot local"
if [[ "$MODE" == "dry-run" ]]; then
  rsync "${RSYNC_FLAGS[@]}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/.env" "${LOCAL_BASE_DIR}/.env.prod.snapshot"
else
  rsync "${RSYNC_FLAGS[@]}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/.env" "${LOCAL_BASE_DIR}/.env.prod.snapshot"
  if [[ ! -f "${LOCAL_BASE_DIR}/.env.dev" ]]; then
    cp -f "${LOCAL_BASE_DIR}/.env.prod.snapshot" "${LOCAL_BASE_DIR}/.env.dev"
    echo "[INFO] Creado ${LOCAL_BASE_DIR}/.env.dev a partir de snapshot de prod"
  fi
fi

echo "[5/5] Sincronizando estructura principal"
for p in data html letsencrypt openclaw openclaw_home ops; do
  mkdir -p "${LOCAL_BASE_DIR}/${p}"
  rsync "${RSYNC_FLAGS[@]}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/${p}/" \
    "${LOCAL_BASE_DIR}/${p}/"
done

echo
echo "Finalizado: ${MODE}"
echo "Siguiente paso: revisar ${LOCAL_BASE_DIR}/.env.dev y arrancar local con start_local_dev.sh"
