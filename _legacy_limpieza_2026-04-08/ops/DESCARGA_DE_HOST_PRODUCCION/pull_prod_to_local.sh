#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${ROOT_DIR}/sync_config.sh"
EXCLUDES_FILE="${ROOT_DIR}/sync_excludes.txt"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Falta configuración: $CONFIG_FILE"
  echo "Copia y edita: ${ROOT_DIR}/sync_config.example.sh -> ${ROOT_DIR}/sync_config.sh"
  exit 1
fi

source "$CONFIG_FILE"

MODE="${1:-dry-run}" # dry-run | apply

if [[ "$MODE" != "dry-run" && "$MODE" != "apply" ]]; then
  echo "Uso: $0 [dry-run|apply]"
  exit 1
fi

mkdir -p "$LOCAL_MIRROR_DIR"

RSYNC_FLAGS=(
  -aHAX
  --numeric-ids
  --delete
  --delete-excluded
  --human-readable
  --info=stats2,progress2
  --partial
  --mkpath
  --exclude-from="$EXCLUDES_FILE"
)

if [[ "${EXCLUDE_LOG_ROTATED:-1}" == "1" ]]; then
  RSYNC_FLAGS+=(--exclude='**/*.log.[1-9]*' --exclude='**/*.log.[1-9]*.gz')
fi

if [[ "$MODE" == "dry-run" ]]; then
  RSYNC_FLAGS+=(--dry-run --itemize-changes)
  echo "[sync] Modo simulación (no escribe cambios)."
else
  echo "[sync] Modo apply (escribirá cambios locales)."
fi

for rel_path in "${SYNC_PATHS[@]}"; do
  SRC="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/${rel_path}/"
  DST="${LOCAL_MIRROR_DIR}/${rel_path}/"
  mkdir -p "$DST"
  echo "[sync] ${SRC} -> ${DST}"
  if [[ -n "${SSH_OPTS:-}" ]]; then
    rsync "${RSYNC_FLAGS[@]}" -e "ssh ${SSH_OPTS}" "$SRC" "$DST"
  else
    rsync "${RSYNC_FLAGS[@]}" "$SRC" "$DST"
  fi
done

echo "[sync] Finalizado: $MODE"
