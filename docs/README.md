# PVE dual-image customization

This fork adds a reusable x86-64 PVE build profile to the upstream
ImmortalWrt ImageBuilder project. It produces two independent images:

- `Router`: three VirtIO interfaces, two disabled-by-default PPPoE WANs,
  mwan3, DHCPv4, Lucky, the PO0 WAN probe, and conservative forwarding
  defaults. The probe initially permits only the paired Gateway address.
- `Gateway`: one VirtIO interface, DHCP disabled, OpenClash installed but
  disabled until the operator supplies a configuration, plus the PO0 reporter.
  The reporter is preset to query all Router WANs but remains disabled until
  its LAN Worker URL and secret are configured in LuCI.

The build contains no deployment inventory, provider credentials, subscription
URLs, device identifiers, public hostnames, or production access tokens.
The workflow downloads both PO0 APKs from a fixed VPS-Toolkit release and
verifies their published SHA-256 checksums. Neither package manages
Mihomo/OpenClash routing or proxy state.

Documentation:

- [Reference architecture](./FINAL-ARCHITECTURE.md)
- [Build and import](./BUILD-AND-IMPORT.md)
- [Build design](./IMMORTALWRT-BUILD-PLAN.md)
- [PVE deployment checklist](./PVE-DEPLOYMENT-RUNBOOK.md)
- [Operations and recovery](./OPERATIONS-RECOVERY.md)
- [Network performance](./NETWORK-PERFORMANCE.md)

All addresses shown in this public repository are examples or workflow
defaults. Choose values appropriate for the target network before building.
