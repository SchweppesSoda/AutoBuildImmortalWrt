#!/bin/sh
# Helpers for the PVE uci-defaults scripts. No global errexit: missing optional
# keys are normal, whereas failed reads, required writes and commits are not.

pve_fail() {
  echo "PVE_FIRSTBOOT_FAILED: $1" >&2
  exit 1
}

command -v uci >/dev/null 2>&1 || pve_fail 'uci is unavailable'

pve_uci() {
  # Never log the arguments or command error body; UCI may contain credentials.
  uci "$@" 2>/dev/null || pve_fail 'required UCI operation failed'
}

pve_delete_if_present() {
  local key=$1 package snapshot line
  package=${key%%.*}
  # A failed get alone cannot distinguish an absent option from a broken
  # package. Read the complete package successfully before accepting absence.
  snapshot="$(uci -q show "$package" 2>/dev/null)" || pve_fail 'UCI package read failed'
  while IFS= read -r line; do
    case "$line" in
      "$key="*) pve_uci -q delete "$key"; return 0 ;;
    esac
  done <<EOF
$snapshot
EOF
  return 0
}

pve_service() {
  [ -x "$1" ] || pve_fail 'required init script is unavailable'
  "$@" >/dev/null 2>&1 || pve_fail 'required service default failed'
}
