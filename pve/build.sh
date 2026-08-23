#!/bin/bash
set -Eeuo pipefail

ROOT_DIR="${IMAGEBUILDER_ROOT:-/home/build/immortalwrt}"
PVE_DIR="${ROOT_DIR}/pve"
ROLE="${1:-${ROLE:-}}"
ROOTFS_PARTSIZE="${ROOTFS_PARTSIZE:-2048}"
ROUTER_LAN_IP="${ROUTER_LAN_IP:-192.168.100.1}"
GATEWAY_LAN_IP="${GATEWAY_LAN_IP:-192.168.100.2}"
LAN_NETMASK="${LAN_NETMASK:-255.255.255.0}"

case "${ROLE}" in
  Router|Gateway) ;;
  *)
    echo "Usage: build.sh {Router|Gateway}" >&2
    exit 2
    ;;
esac

if ! [[ "${ROOTFS_PARTSIZE}" =~ ^[0-9]+$ ]] ||
   (( ROOTFS_PARTSIZE < 1024 || ROOTFS_PARTSIZE > 8192 )); then
  echo "ROOTFS_PARTSIZE must be an integer from 1024 through 8192 MiB" >&2
  exit 2
fi

validate_ipv4() {
  local ip="$1"
  local octets=()
  local octet

  IFS='.' read -r -a octets <<< "${ip}"
  (( ${#octets[@]} == 4 )) || return 1
  for octet in "${octets[@]}"; do
    [[ "${octet}" =~ ^[0-9]{1,3}$ ]] || return 1
    (( 10#${octet} <= 255 )) || return 1
  done
}

for address in "${ROUTER_LAN_IP}" "${GATEWAY_LAN_IP}" "${LAN_NETMASK}"; do
  if ! validate_ipv4 "${address}"; then
    echo "Invalid IPv4 value: ${address}" >&2
    exit 2
  fi
done

if [[ "${ROUTER_LAN_IP}" == "${GATEWAY_LAN_IP}" ]]; then
  echo "ROUTER_LAN_IP and GATEWAY_LAN_IP must be different" >&2
  exit 2
fi

# shellcheck disable=SC1091
source "${PVE_DIR}/versions.env"

FILES_DIR="$(mktemp -d /tmp/pve-files.XXXXXX)"
DOWNLOAD_DIR="$(mktemp -d /tmp/pve-downloads.XXXXXX)"
PACKAGES_DIR="${ROOT_DIR}/packages"

cleanup() {
  rm -rf "${FILES_DIR}" "${DOWNLOAD_DIR}"
}
trap cleanup EXIT

mkdir -p "${PACKAGES_DIR}" "${ROOT_DIR}/bin/pve-meta"
cp -a "${PVE_DIR}/files/common/." "${FILES_DIR}/"
cp -a "${PVE_DIR}/files/${ROLE}/." "${FILES_DIR}/"
chmod 0755 "${FILES_DIR}"/etc/uci-defaults/*.sh

while IFS= read -r -d '' template; do
  sed -i \
    -e "s/@ROUTER_LAN_IP@/${ROUTER_LAN_IP}/g" \
    -e "s/@GATEWAY_LAN_IP@/${GATEWAY_LAN_IP}/g" \
    -e "s/@LAN_NETMASK@/${LAN_NETMASK}/g" \
    "${template}"
done < <(grep -rlIZ '@\(ROUTER_LAN_IP\|GATEWAY_LAN_IP\|LAN_NETMASK\)@' "${FILES_DIR}")

download_checked() {
  local url="$1"
  local expected_sha256="$2"
  local destination="$3"

  echo "Downloading pinned asset: ${url}"
  curl --fail --location --retry 3 --retry-delay 2 \
    --output "${destination}" "${url}"
  printf '%s  %s\n' "${expected_sha256}" "${destination}" | sha256sum --check --status
}

download_checked "${ARGON_THEME_URL}" "${ARGON_THEME_SHA256}" \
  "${PACKAGES_DIR}/${ARGON_THEME_PACKAGE}"
download_checked "${ARGON_CONFIG_URL}" "${ARGON_CONFIG_SHA256}" \
  "${PACKAGES_DIR}/${ARGON_CONFIG_PACKAGE}"
download_checked "${ARGON_I18N_URL}" "${ARGON_I18N_SHA256}" \
  "${PACKAGES_DIR}/${ARGON_I18N_PACKAGE}"

while read -r expected_sha256 scope package_path; do
  [[ -n "${expected_sha256}" ]] || continue
  [[ "${expected_sha256}" != \#* ]] || continue
  if [[ "${scope}" != "common" && "${scope}" != "${ROLE}" ]]; then
    continue
  fi

  package_name="${package_path##*/}"
  package_url="${VENDOR_APK_REPOSITORY}/${VENDOR_APK_COMMIT}/${package_path}"
  download_checked "${package_url}" "${expected_sha256}" \
    "${PACKAGES_DIR}/${package_name}"
done < "${PVE_DIR}/vendor-packages.lock"

if [[ "${ROLE}" == "Gateway" ]]; then
  mkdir -p "${FILES_DIR}/etc/openclash/core"

  core_archive="${DOWNLOAD_DIR}/mihomo-${MIHOMO_VERSION}.gz"
  download_checked "${MIHOMO_URL}" "${MIHOMO_SHA256}" "${core_archive}"
  gzip --decompress --stdout "${core_archive}" \
    > "${FILES_DIR}/etc/openclash/core/clash_meta"
  chmod 0755 "${FILES_DIR}/etc/openclash/core/clash_meta"

  download_checked "${GEOIP_URL}" "${GEOIP_SHA256}" \
    "${FILES_DIR}/etc/openclash/GeoIP.dat"
  download_checked "${GEOSITE_URL}" "${GEOSITE_SHA256}" \
    "${FILES_DIR}/etc/openclash/GeoSite.dat"
fi

PACKAGE_LIST="$({
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' \
    "${PVE_DIR}/packages/common.txt"
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' \
    "${PVE_DIR}/packages/${ROLE}.txt"
} | sort -u | tr '\n' ' ')"

{
  echo "role=${ROLE}"
  echo "immortalwrt=${IMMORTALWRT_VERSION}"
  echo "rootfs_mib=${ROOTFS_PARTSIZE}"
  echo "router_lan_ip=${ROUTER_LAN_IP}"
  echo "gateway_lan_ip=${GATEWAY_LAN_IP}"
  echo "lan_netmask=${LAN_NETMASK}"
  echo "argon=${ARGON_VERSION}"
  echo "vendor_apk_commit=${VENDOR_APK_COMMIT}"
  if [[ "${ROLE}" == "Gateway" ]]; then
    echo "mihomo=${MIHOMO_VERSION}"
    echo "geodata=${GEODATA_VERSION}"
  fi
} > "${FILES_DIR}/etc/pve-build-info"

tr ' ' '\n' <<< "${PACKAGE_LIST}" \
  > "${ROOT_DIR}/bin/pve-meta/package-request-${ROLE}.txt"

echo "Building ImmortalWrt ${IMMORTALWRT_VERSION} role=${ROLE} rootfs=${ROOTFS_PARTSIZE}MiB"
echo "Requested packages: ${PACKAGE_LIST}"

cd "${ROOT_DIR}"
make image \
  PROFILE="generic" \
  PACKAGES="${PACKAGE_LIST}" \
  FILES="${FILES_DIR}" \
  ROOTFS_PARTSIZE="${ROOTFS_PARTSIZE}"

echo "Build completed: ${ROLE}"
