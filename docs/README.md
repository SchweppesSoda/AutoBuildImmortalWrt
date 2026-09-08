# PVE dual-image customization

See [fork maintenance](MAINTENANCE.md) for branch ownership, the distinction
between fixed build inputs and deployed package versions, and validation limits.

This fork adds a reusable x86-64 PVE build profile to the upstream
ImmortalWrt ImageBuilder project. It produces two independent images:

- `Router`: three VirtIO interfaces, two disabled-by-default PPPoE WANs,
  mwan3, DHCPv4, Lucky, and conservative forwarding defaults.
- `Gateway`: one VirtIO interface, DHCP disabled, OpenClash installed but
  disabled until the operator supplies a configuration, plus the PO0 reporter.
  The reporter uses source mode and the parameterized Router address for real
  DNS resolution. Source addresses are empty and reporting remains disabled.

The build contains no deployment inventory, provider credentials, subscription
URLs, device identifiers, public hostnames, or production access tokens.
The workflow downloads only the Gateway reporter APK from a fixed VPS-Toolkit
release and verifies its published SHA-256 checksum. Independent APK releases
use `po0-apk-vYYYY.MM.DD.N`; existing `po0-vYYYY.MM.DD.N` releases remain
accepted for compatible packages. Download by fixed tag, never `latest`:
independent APK releases do not replace the script release's latest marker.
The current default is the published source-mode release `po0-v2026.09.05.8`.
The Router needs DNS and
mwan3 for this feature; it does not host an HTTP WAN query service.

Before enabling the Gateway reporter:

1. Select unused addresses on the deployed LAN, outside dynamic DHCP allocation.
   Check static reservations, leases, neighbors and ARP conflicts; do not reuse
   an existing proxy source address. Persist each address locally as a /32.
2. Put source-only rules before broad Router mwan3 rules. Map each source to its
   matching WAN-only policy with `last_resort=unreachable`, so a failed WAN
   cannot silently use the other WAN.
3. Reuse OpenClash's custom firewall hook to bypass interception for these local
   source addresses in OUTPUT only. Verify restoration after firewall reload;
   do not extend the bypass to all LAN forwarding or pin query-service IPs.
4. Set `official_source_wan1` / `official_source_wan2`, select the required WANs,
   and configure Worker credentials or official account bindings in LuCI before
   enabling reporting. Ordinary Worker submission follows the normal network
   path; public-IP queries and official requests use the selected direct source.

`probe_dns_server` is initialized from the Router address input. Query endpoints
are resolved through that DNS server at runtime; no production source addresses,
fixed endpoint IPs or OpenClash routing changes are embedded in the image.
The generic x86 workflow offers `none` and `gateway-reporter` with the same
source-mode defaults and disabled service.

Documentation:

- [Reference architecture](./FINAL-ARCHITECTURE.md)
- [Build and import](./BUILD-AND-IMPORT.md)
- [Build design](./IMMORTALWRT-BUILD-PLAN.md)
- [PVE deployment checklist](./PVE-DEPLOYMENT-RUNBOOK.md)
- [Operations and recovery](./OPERATIONS-RECOVERY.md)
- [Network performance](./NETWORK-PERFORMANCE.md)

All addresses shown in this public repository are examples or workflow
defaults. Choose values appropriate for the target network before building.
