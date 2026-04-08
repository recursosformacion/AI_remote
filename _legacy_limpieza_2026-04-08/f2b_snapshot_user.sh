#!/usr/bin/env bash
set -euo pipefail
OUT="/servidor/openclaw_home/fail2ban_status.txt"
TMP="$(mktemp)"
{
  echo "generated_at: $(date -Is)"
  echo
  echo "=== fail2ban status ==="
  sudo -n fail2ban-client status || true
  echo
  JAILS=$(sudo -n fail2ban-client status 2>/dev/null | sed -n 's/^`- Jail list:[[:space:]]*//p' | tr ',' ' ')
  for jail in $JAILS; do
    jail_trimmed="$(echo "$jail" | xargs)"
    [ -n "$jail_trimmed" ] || continue
    echo "=== jail: $jail_trimmed ==="
    sudo -n fail2ban-client status "$jail_trimmed" || true
    echo
  done
} > "$TMP"
chmod 0644 "$TMP"
mv "$TMP" "$OUT"
