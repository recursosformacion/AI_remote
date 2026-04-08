#!/usr/bin/env bash

# Copia este archivo a: ops/DESCARGA_DE_HOST_PRODUCCION/sync_config.sh
# y ajusta valores según tu entorno.

REMOTE_HOST="tu-servidor-prod"
REMOTE_USER="ocw"
REMOTE_BASE_DIR="/servidor"
LOCAL_MIRROR_DIR="$HOME/servidor_prod_mirror"
SSH_OPTS=""

SYNC_PATHS=(
  "data"
  "html"
  "letsencrypt"
  "openclaw_home"
  "ops"
)

EXCLUDE_LOG_ROTATED="1"
