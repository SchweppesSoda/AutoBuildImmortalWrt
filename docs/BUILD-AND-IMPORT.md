# Build and import the PVE images

## Build with GitHub Actions

Run **Build PVE dual ImmortalWrt 25.12** from the Actions tab and provide:

- root filesystem size in MiB;
- Router LAN IPv4 address;
- Gateway LAN IPv4 address;
- LAN IPv4 netmask;
- a published VPS-Toolkit `po0-apk-vYYYY.MM.DD.N` or compatible legacy
  `po0-vYYYY.MM.DD.N` tag containing the source-mode Gateway reporter;
- whether to publish a uniquely tagged release.

The Router and Gateway must be different usable unicast hosts in the same LAN
subnet, outside its DHCP pool. Network and broadcast addresses are rejected.
Addresses and netmask use four decimal octets without leading zeros, and
netmask bits must be contiguous. The fixed DHCP pool contains 150 addresses
starting at network address + 100; the entire pool must fit below the broadcast
address. Valid larger subnets such as `/23` are supported; `/25` is too small.
Rootfs size is a decimal integer from 1024 through 8192, without leading zeros. Both
the workflow and local builder run the same preflight before downloads. Use a
subnet that does not overlap another local, VPN, or WAN network.

Run `python3 -m unittest discover -s pve/tests -v` for offline input validation
regressions. These use inert fixtures and do not build or publish firmware.

The workflow executes the reviewed linux/amd64 ImageBuilder digest in
`pve/versions.env`, not the mutable tag. It produces two compressed combined-EFI
images, actual package manifests, requested-package lists, build/source/image
metadata, copied version/vendor locks, actual APK/runtime hashes and SHA-256
checksums. Verify `SHA256SUMS` before importing an image. A manual invocation
without a confirmed container reference records `unverified-local-build`.

This records exact inputs but does not archive every distribution feed package
or promise a byte-identical offline firmware rebuild. Retain the accepted image
as the recovery artifact. Updating a pin requires reviewing the official digest
and architecture, a real build, manifest comparison and separate import approval.

## Suggested PVE mapping

Router VM:

- `net0` -> LAN bridge;
- `net1` -> first dedicated WAN bridge;
- `net2` -> second dedicated WAN bridge.

Gateway VM:

- `net0` -> the same LAN bridge.

Do not put an IP address on a PVE bridge connected directly to an untrusted WAN
unless the deployment explicitly requires it. Keep a separate, tested recovery
path to the PVE host before changing bridges or router VMs.

## First boot

1. Set a root password from the PVE console.
2. Verify the VirtIO interface order against the PVE VM configuration.
3. Confirm the embedded LAN addresses and netmask.
4. Configure PPPoE credentials in LuCI; enable one WAN at a time.
5. Verify routing and DNS before enabling mwan3 policies.
6. Configure the Gateway without exposing subscription URLs in Git or logs.
7. Test one client against the Gateway before directing additional clients to
   it.
