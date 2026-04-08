#!/usr/bin/env bash
set -euo pipefail
cd /servidor
chown ocw:ocw .env
chmod 600 .env
if command -v setfacl >/dev/null 2>&1; then
  setfacl -m u:ocw:rw .env
fi
echo "ok: /servidor/.env => ocw:ocw 600 (+acl if available)"
