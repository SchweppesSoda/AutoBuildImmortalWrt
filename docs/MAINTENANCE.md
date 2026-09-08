# Maintaining this fork

`master` follows the upstream project. `pve-dual` owns the reusable PVE
customization under `pve/` and its build workflow. The generic x86 workflow
also consumes the optional Gateway reporter. Keep upstream hardware support
and historical references unless a scoped change explicitly retires them.

## Entry points

- [PVE documentation](README.md): roles, defaults and deployment prerequisites.
- [Build and import](BUILD-AND-IMPORT.md): build inputs and image acceptance.
- `pve/build.sh`, `pve/packages/`, `pve/files/`: image assembly and first boot.
- `.github/workflows/build-pve-dual-25.12.yml`: two-role build and release.
- `.github/workflows/build-x86-64-25.12.x.yml`, `x86-64/build25.sh`: generic x86.

Production topology, device state and credentials belong to the deployment's
private operations repository. A newer package installed on a device does
not silently change this fork's fixed build input.

## Fixed reporter dependency

The source-mode work closes out with the existing fixed default
`po0-v2026.09.05.8`. The Router no longer ships the HTTP WAN probe; the
Gateway retains a disabled reporter and empty deployment-specific sources.
The documentation for that fixed package includes its historical Worker mode.
It is not an instruction to re-enable retired features on a newer deployment.

The later official-only APK is a separate dependency-upgrade task. Before
changing the default, review that package's UCI contract, first-boot defaults,
asset checksum and both workflows, then build and inspect the images. The
2026-09-08 repository cleanup neither upgrades this dependency nor publishes
or imports firmware.

## Validation and closeout

1. Inspect `git status`, the active branch and remote heads. Preserve existing
   work and use only one writer in this checkout.
2. Run `bash -n` on changed shell files. Parse changed YAML and syntax-check
   embedded `run` blocks after replacing GitHub expressions with inert values.
   For first-boot changes, inspect role-specific UCI commands and empty secrets.
3. Full validation requires the relevant GitHub Actions/ImageBuilder run,
   package-manifest and checksum inspection, followed by controlled import
   acceptance. Static parsing alone is not a successful firmware build.
4. Commit implementation separately from maintenance-only documentation.
   Report local commits, remote state, release state and validation limits.

New local test output goes under ignored `.tmp/`. Keep source and maintenance
records in responsibility directories; do not store the only recovery copy
in a test directory or delete historical release tags as cleanup.
