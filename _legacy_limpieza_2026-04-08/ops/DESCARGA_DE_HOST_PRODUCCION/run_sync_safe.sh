#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${ROOT_DIR}/sync_config.sh"

if [[ ! -f "$CFG" ]]; then
  echo "Falta configuración: $CFG"
  echo "Primero ejecuta: cp ${ROOT_DIR}/sync_config.example.sh ${ROOT_DIR}/sync_config.sh"
  exit 1
fi

MODE="${1:-assistido}" # assistido | auto

if [[ "$MODE" != "assistido" && "$MODE" != "auto" ]]; then
  echo "Uso: $0 [assistido|auto]"
  exit 1
fi

echo "=============================================="
echo " Sync seguro producción -> local"
echo "=============================================="
echo

echo "[1/4] Snapshot previo en producción"
bash "${ROOT_DIR}/../pre_sync_snapshot.sh"
echo

echo "[2/4] Simulación (dry-run)"
bash "${ROOT_DIR}/pull_prod_to_local.sh" dry-run
echo

do_apply="s"
if [[ "$MODE" == "assistido" ]]; then
  read -r -p "¿Aplicar sincronización real ahora? [s/N]: " do_apply
fi

if [[ "$do_apply" =~ ^[sS]$ ]]; then
  echo
  echo "[3/4] Aplicando sincronización"
  bash "${ROOT_DIR}/pull_prod_to_local.sh" apply
  echo
else
  echo "[3/4] Saltado (no se aplicaron cambios)"
  echo
fi

echo "[4/4] Verificación final"
if bash "${ROOT_DIR}/verify_sync.sh"; then
  echo "OK: copia local consistente con producción."
else
  echo "ATENCIÓN: hay diferencias pendientes."
  exit 2
fi
