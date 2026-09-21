# Pinned ImageBuilder and build evidence — 2026-09-21

The official Docker Hub tag metadata for `x86-64-openwrt-25.12.1` returned one
linux/amd64 manifest, digest
`sha256:600dbc0bb7c0b0ca6d6b3b783061599bb93e19e220e416ab21911c6d15dc7049`.
The workflow now runs this digest with an explicit platform. The existing
ImmortalWrt, Argon, vendor APK, Mihomo, geodata and reporter versions are retained.
The tag metadata was read; no image was pulled and no container was executed.

Both image artifacts now carry build/source/digest identity, the reviewed input
locks, actual custom APK hashes and (Gateway) unpacked core/geodata hashes.
The existing actual package manifest remains required. The combined checksum
file covers these records, and individual image checksums use portable relative
paths. Release attachment patterns include the records when a later authorized
run explicitly selects release publication.

Two synthetic tests execute the real Router build script with empty fixture APKs
and inert download/make commands: metadata is retained and a conflicting builder
reference stops before downloads. Existing input/first-boot tests are independent.
YAML and embedded Bash parsing passed. Docker and ImageBuilder are unavailable
locally; actual build, release bundle and guest boot remain unverified.

Source: [official Docker Hub metadata](https://hub.docker.com/v2/repositories/immortalwrt/imagebuilder/tags/x86-64-openwrt-25.12.1).
Digest immutability is not an offline package archive or signature attestation.
Public feed availability can still limit reconstruction. Keep accepted images
and their metadata; do not replace a recovery image solely because newer source
exists. Reverting the local change does not alter any deployed device.
