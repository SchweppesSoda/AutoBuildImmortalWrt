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
  # A dotted IPv4 value is not necessarily a contiguous network mask.
  local mask_octets=() mask inverse
  IFS='.' read -r -a mask_octets <<< "${LAN_NETMASK}"
  mask=$(( (10#${mask_octets[0]} << 24) | (10#${mask_octets[1]} << 16) |
           (10#${mask_octets[2]} << 8) | 10#${mask_octets[3]} ))
  inverse=$(( mask ^ 4294967295 ))
  if (( (inverse & (inverse + 1)) != 0 )); then
    echo "LAN_NETMASK must have contiguous network bits" >&2
    return 2
  fi
  if [[ "${ROUTER_LAN_IP}" == "${GATEWAY_LAN_IP}" ]]; then
    echo "ROUTER_LAN_IP and GATEWAY_LAN_IP must be different" >&2
    return 2
  fi
}
