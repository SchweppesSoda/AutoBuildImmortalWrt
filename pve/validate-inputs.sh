#!/bin/bash
# Shared by the local ImageBuilder entry point and the PVE workflow.

validate_pve_ipv4() {
  local ip="$1" octet
  local octets=()
  # Anchor the full string: read alone discards a trailing dot or later lines.
  [[ "${ip}" =~ ^(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})$ ]] || return 1
  IFS='.' read -r -a octets <<< "${ip}"
  for octet in "${octets[@]}"; do
    (( 10#${octet} <= 255 )) || return 1
  done
}

validate_pve_inputs() {
  local address
  if ! [[ "${ROOTFS_PARTSIZE:-}" =~ ^[1-8][0-9]{3}$ ]] ||
     (( ROOTFS_PARTSIZE < 1024 || ROOTFS_PARTSIZE > 8192 )); then
    echo "ROOTFS_PARTSIZE must be a decimal integer from 1024 through 8192 MiB" >&2
    return 2
  fi
  for address in "${ROUTER_LAN_IP:-}" "${GATEWAY_LAN_IP:-}" "${LAN_NETMASK:-}"; do
    if ! validate_pve_ipv4 "${address}"; then
      echo "LAN addresses and netmask must use four decimal IPv4 octets without leading zeros" >&2
      return 2
    fi
  done
  if [[ "${ROUTER_LAN_IP}" == "${GATEWAY_LAN_IP}" ]]; then
    echo "ROUTER_LAN_IP and GATEWAY_LAN_IP must be different" >&2
    return 2
  fi
}
