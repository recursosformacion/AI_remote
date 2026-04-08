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

echo "[verify] Comparación no destructiva con rsync --dry-run --checksum"

base_flags=(
  -aHAX
  --numeric-ids
  --dry-run
  --checksum
  --delete
  --itemize-changes
  --exclude-from="$EXCLUDES_FILE"
)

total_changes=0

for rel_path in "${SYNC_PATHS[@]}"; do
  SRC="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE_DIR}/${rel_path}/"
  DST="${LOCAL_MIRROR_DIR}/${rel_path}/"
  mkdir -p "$DST"

  echo "[verify] Revisando: $rel_path"
  if [[ -n "${SSH_OPTS:-}" ]]; then
    out="$(rsync "${base_flags[@]}" -e "ssh ${SSH_OPTS}" "$SRC" "$DST" || true)"
  else
    out="$(rsync "${base_flags[@]}" "$SRC" "$DST" || true)"
  fi

  changes="$(echo "$out" | sed '/^$/d' | wc -l | tr -d ' ')"
  total_changes=$((total_changes + changes))

  if [[ "$changes" -eq 0 ]]; then
    echo "[verify] OK: sin diferencias en $rel_path"
  else
    echo "[verify] Diferencias en $rel_path: $changes"
    echo "$out"
  fi
done

if [[ "$total_changes" -eq 0 ]]; then
  echo "[verify] Consistencia completa entre producción y espejo local."
  exit 0
fi

echo "[verify] Hay diferencias pendientes: $total_changes"
exit 2
