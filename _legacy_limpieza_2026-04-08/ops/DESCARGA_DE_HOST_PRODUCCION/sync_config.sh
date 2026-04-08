#!/usr/bin/env bash

# Puente de compatibilidad: usa la configuración principal si existe.
if [[ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../sync_config.sh" ]]; then
  # shellcheck disable=SC1091
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../sync_config.sh"
else
  echo "Falta configuración: ops/sync_config.sh"
  echo "Copia y edita: ops/DESCARGA_DE_HOST_PRODUCCION/sync_config.example.sh -> ops/DESCARGA_DE_HOST_PRODUCCION/sync_config.sh"
  exit 1
fi
