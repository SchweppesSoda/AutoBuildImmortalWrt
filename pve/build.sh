#!/bin/bash
set -Eeuo pipefail

ROOT_DIR="${IMAGEBUILDER_ROOT:-/home/build/immortalwrt}"
PVE_DIR="${ROOT_DIR}/pve"
ROLE="${1:-${ROLE:-}}"
ROOTFS_PARTSIZE="${ROOTFS_PARTSIZE:-2048}"
ROUTER_LAN_IP="${ROUTER_LAN_IP:-192.168.100.1}"
GATEWAY_LAN_IP="${GATEWAY_LAN_IP:-192.168.100.2}"
LAN_NETMASK="${LAN_NETMASK:-255.255.255.0}"
PO0_RELEASE_TAG="${PO0_RELEASE_TAG:-}"

case "${ROLE}" in
  Router|Gateway) ;;
  *)
    echo "Usage: build.sh {Router|Gateway}" >&2
    exit 2
    ;;
esac

# Use the same preflight as CI before reading versions or downloading assets.
# shellcheck disable=SC1091
source "${PVE_DIR}/validate-inputs.sh"
validate_pve_inputs

# shellcheck disable=SC1091
source "${PVE_DIR}/versions.env"
if [[ -n "${IMAGEBUILDER_USED:-}" && "${IMAGEBUILDER_USED}" != "${IMAGEBUILDER_IMAGE}" ]]; then
  echo 'ImageBuilder execution reference does not match the reviewed pin' >&2
  exit 2
fi

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
# The APK carries its own version; a release build number is not an APK revision.
if [[ "${ROLE}" == "Gateway" ]]; then
  PO0_APK="${ROOT_DIR}/po0-packages/po0-outbound-ip-report.apk"
  if [[ ! -f "${PO0_APK}" ]]; then
    echo "Missing mounted PO0 package: ${PO0_APK}" >&2
    exit 1
  fi
  if [[ ! "${PO0_RELEASE_TAG}" =~ ^po0-(apk-)?v[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
    echo "Invalid PO0 release tag: ${PO0_RELEASE_TAG}" >&2
    exit 2
  fi
  cp "${PO0_APK}" "${PACKAGES_DIR}/po0-outbound-ip-report.apk"
fi

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
  echo "imagebuilder_expected=${IMAGEBUILDER_IMAGE}"
  echo "imagebuilder_used=${IMAGEBUILDER_USED:-unverified-local-build}"
  echo "source_commit=${SOURCE_COMMIT:-unknown}"
  echo "rootfs_mib=${ROOTFS_PARTSIZE}"
  echo "router_lan_ip=${ROUTER_LAN_IP}"
  echo "gateway_lan_ip=${GATEWAY_LAN_IP}"
  echo "lan_netmask=${LAN_NETMASK}"
  echo "argon=${ARGON_VERSION}"
  echo "vendor_apk_commit=${VENDOR_APK_COMMIT}"
  if [[ "${ROLE}" == "Gateway" ]]; then
    echo "po0_release=${PO0_RELEASE_TAG}"
    echo "mihomo=${MIHOMO_VERSION}"
    echo "geodata=${GEODATA_VERSION}"
  fi
} > "${FILES_DIR}/etc/pve-build-info"

cp "${FILES_DIR}/etc/pve-build-info" "${ROOT_DIR}/bin/pve-meta/build-info-${ROLE}.txt"
cp "${PVE_DIR}/versions.env" "${ROOT_DIR}/bin/pve-meta/versions-${ROLE}.env"
cp "${PVE_DIR}/vendor-packages.lock" "${ROOT_DIR}/bin/pve-meta/vendor-packages-${ROLE}.lock"
# Store actual selected APK and unpacked runtime hashes as well as the pins.
# Paths are relative to each input tree; no deployment credentials are read.
(
  cd "${PACKAGES_DIR}"
  find . -maxdepth 1 -type f -name '*.apk' -print0 | sort -z | xargs -0 -r sha256sum
) > "${ROOT_DIR}/bin/pve-meta/apk-inputs-${ROLE}.sha256"
if [[ "${ROLE}" == "Gateway" ]]; then
  (cd "${FILES_DIR}" && sha256sum etc/openclash/core/clash_meta etc/openclash/GeoIP.dat etc/openclash/GeoSite.dat) \
    > "${ROOT_DIR}/bin/pve-meta/runtime-inputs-${ROLE}.sha256"
fi

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
