# Build and import the PVE images

## Build with GitHub Actions

Run **Build PVE dual ImmortalWrt 25.12** from the Actions tab and provide:

- root filesystem size in MiB;
- Router LAN IPv4 address;
- Gateway LAN IPv4 address;
- LAN IPv4 netmask;
- whether to publish a uniquely tagged release.

The Router and Gateway addresses must be different valid IPv4 addresses. Use a
subnet that does not overlap another local, VPN, or WAN network.

The workflow produces two compressed combined-EFI images, package manifests,
requested-package lists, and SHA-256 checksums. Verify `SHA256SUMS` before
importing an image.

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
