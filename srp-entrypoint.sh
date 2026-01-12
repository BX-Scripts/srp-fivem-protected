#!/usr/bin/env bash
set -euo pipefail

LIST_URL="https://fivembackdoor.info/malicious-domains"
MARK_START="# SRP_BACKDOOR_BLOCK_START"
MARK_END="# SRP_BACKDOOR_BLOCK_END"

HASH_FILE="/home/container/.srp_backdoor_hash"
TMP_LIST="/tmp/srp_backdoor_list.txt"

log(){ echo "[srp-protect] $*"; }

fetch_list() {
  curl -fsSL --connect-timeout 3 --max-time 8 "$LIST_URL" \
  | awk '{for (i=1; i<=NF; i+=2) print $i, $(i+1)}' > "$TMP_LIST"
}

calc_hash() {
  sha256sum "$TMP_LIST" | awk '{print $1}'
}

hosts_has_block() {
  grep -qF "$MARK_START" /etc/hosts 2>/dev/null
}

remove_block() {
  if hosts_has_block; then
    awk -v s="$MARK_START" -v e="$MARK_END" '
      $0==s {skip=1; next}
      $0==e {skip=0; next}
      !skip {print}
    ' /etc/hosts > /tmp/hosts.clean && cat /tmp/hosts.clean > /etc/hosts
  fi
}

add_block() {
  {
    echo "$MARK_START"
    cat "$TMP_LIST"
    echo "$MARK_END"
  } >> /etc/hosts
}

# Kaitse ainult siis, kui oleme root
if [ "$(id -u)" = "0" ]; then
  mkdir -p /home/container

  if fetch_list; then
    NEW_HASH="$(calc_hash)"
    OLD_HASH="$(cat "$HASH_FILE" 2>/dev/null || true)"

    if hosts_has_block && [ "$NEW_HASH" = "$OLD_HASH" ]; then
      log "list muutumatu ja blokk olemas -> ei muuda midagi"
    else
      remove_block
      add_block
      echo "$NEW_HASH" > "$HASH_FILE"
      log "blokk uuendatud (hash=$NEW_HASH)"
    fi
  else
    log "list ei tulnud kätte -> ei muuda /etc/hosts"
  fi
fi

# Anna juhtimine base image originaal entrypointile (see hoiab serveri normaalselt käimas)
exec /entrypoint.sh "$@"
