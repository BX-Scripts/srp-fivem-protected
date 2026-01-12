#!/usr/bin/env bash
set -euo pipefail

URL="https://fivembackdoor.info/malicious-domains"
S="# SRP_BACKDOOR_BLOCK_START"
E="# SRP_BACKDOOR_BLOCK_END"

TMP="/tmp/srp_bd_list.txt"
DOM="/tmp/srp_bd_domains.txt"
HASH_FILE="/home/container/.srp_backdoor_hash"

log(){ echo "[srp-protect] $*"; }

fetch() {
  curl -fsSL --connect-timeout 3 --max-time 8 "$URL" > "$TMP"
}

extract_domains() {
  # eeldus: list on kujul "IP domain IP domain ..."
  # võta ainult domeenid, üks per rida
  awk '{for(i=2;i<=NF;i+=2) print $i}' "$TMP" \
    | tr -d '\r' \
    | sed '/^$/d' \
    | sort -u > "$DOM"
}

hash_domains() {
  sha256sum "$DOM" | awk '{print $1}'
}

hosts_has_block() {
  grep -qF "$S" /etc/hosts 2>/dev/null
}

remove_block() {
  if hosts_has_block; then
    awk -v s="$S" -v e="$E" '
      $0==s {skip=1; next}
      $0==e {skip=0; next}
      !skip {print}
    ' /etc/hosts > /tmp/hosts.clean && cat /tmp/hosts.clean > /etc/hosts
  fi
}

add_block() {
  {
    echo "$S"
    # IPv4 sinkhole
    awk '{print "0.0.0.0", $0}' "$DOM"
    # IPv6 sinkhole (muidu IPv6 läheb läbi)
    awk '{print "::", $0}' "$DOM"
    echo "$E"
  } >> /etc/hosts
}

# Tee blokk ainult rootina
if [ "$(id -u)" = "0" ]; then
  mkdir -p /home/container

  if fetch; then
    extract_domains
    NEW_HASH="$(hash_domains)"
    OLD_HASH="$(cat "$HASH_FILE" 2>/dev/null || true)"

    if hosts_has_block && [ "$NEW_HASH" = "$OLD_HASH" ]; then
      log "list sama ja blokk olemas -> ei muuda midagi"
    else
      remove_block
      add_block
      echo "$NEW_HASH" > "$HASH_FILE"
      log "blokk uuendatud (domeenid=$(wc -l < "$DOM"))"
    fi
  else
    log "list ei tulnud kätte -> ei muuda /etc/hosts"
  fi
fi

# Jätka base image entrypointiga (Permission denied fix)
exec /bin/bash /entrypoint.sh "$@"
