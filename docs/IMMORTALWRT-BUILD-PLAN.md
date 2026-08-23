# Generic PVE dual-image build design

## Objective

Build reproducible x86-64 ImmortalWrt images for a PVE router VM and an
optional one-arm policy-gateway VM while keeping site-specific configuration
outside the public repository.

## Reproducibility

- Pin the ImmortalWrt ImageBuilder version in `pve/versions.env`.
- Pin third-party APK paths and SHA-256 hashes.
- Pin the Mihomo core and Geo data versions used by the Gateway role.
- Emit the requested package list, build metadata, image checksum, and package
  manifest for every role.

## Router role

- `eth0`: LAN bridge member.
- `eth1`: first PPPoE interface, disabled by default.
- `eth2`: second PPPoE interface, disabled by default.
- DHCPv4 is enabled for the configured LAN; DHCPv6, RA, and NDP are disabled.
- mwan3 and Lucky are installed but require operator configuration.

## Gateway role

- `eth0`: one-arm LAN interface.
- Uses the Router address as its initial gateway and DNS server.
- DHCP and IPv6 LAN announcements are disabled.
- OpenClash is installed with pinned runtime assets but starts disabled and
  contains no subscription or policy.

## Configuration boundary

The public build accepts only non-secret addressing and image-size inputs.
Provider accounts, tokens, device inventories, static leases, DNS names,
port-forwarding rules, and production policy files belong in a separate
private configuration system and must never be committed here.
