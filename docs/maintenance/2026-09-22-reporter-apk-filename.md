# 2026-09-22 reporter APK staging

[Run 35676167677](https://github.com/SchweppesSoda/AutoBuildImmortalWrt/actions/runs/35676167677)
used source `8cbc6b285db74485c0ebc1b26aacea0751961243` with release publication disabled.
Router ImageBuilder and artifact upload succeeded. Gateway passed input validation and
reporter download/checksum verification, then failed ImageBuilder package installation:
`po0-outbound-ip-report-2026.09.05-r4: package mentioned in index not found`.
The bundle job was skipped; this was not a successful dual-role firmware build.

The release asset has the generic filename `po0-outbound-ip-report.apk`. Its internal
package revision is `2026.09.05-r4`, independent of release tag `po0-v2026.09.05.8`.
[ImageBuilder 25.12.1](https://github.com/immortalwrt/immortalwrt/blob/v25.12.1/target/imagebuilder/files/Makefile)
indexes local APKs in `packages.adb`; the
[APK repository filename contract](https://github.com/alpinelinux/apk-tools/blob/b5a31c0d865342ad80be10d68f1bb3d3ad9b0866/doc/apk-mkndx.8.scd)
resolves that index to `${name}-${version}.apk`. Copying the generic release filename
therefore left the indexed package unavailable.

The PVE and generic x86 reporter paths now share a helper that reads metadata using
the ImageBuilder host's `apk adbdump --format json`, validates the reporter identity,
and copies unchanged bytes to the canonical filename. It never installs the APK,
runs package hooks, updates repositories or changes the pinned release/checksum gate.
Malformed metadata, an unexpected package identity and an existing destination fail.

Local Windows validation: four synthetic staging tests and two existing build-evidence
tests passed; changed shell syntax, workflow YAML/embedded shell and Python syntax
passed. The same fixed release APK was downloaded for read-only analysis; SHA256
`48d2dbd45e485b22330c8177bbbfbbf8822d1b6ced0b360a0c063d87b4050a23`
matches its published checksum. Local tests mock metadata extraction; actual host APK
execution and a new dual-role ImageBuilder run remain separate Linux gates. No release,
image import, first boot or device validation was performed by this local fix.
