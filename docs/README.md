# PVE dual-image customization

This fork adds a reusable x86-64 PVE build profile to the upstream
ImmortalWrt ImageBuilder project. It produces two independent images:

- `Router`: three VirtIO interfaces, two disabled-by-default PPPoE WANs,
  mwan3, DHCPv4, Lucky, and conservative forwarding defaults.
- `Gateway`: one VirtIO interface, DHCP disabled, OpenClash installed but
  disabled until the operator supplies a configuration.

The build contains no deployment inventory, provider credentials, subscription
URLs, device identifiers, public hostnames, or production access tokens.

Documentation:

- [Reference architecture](./FINAL-ARCHITECTURE.md)
- [Build and import](./BUILD-AND-IMPORT.md)
- [Build design](./IMMORTALWRT-BUILD-PLAN.md)
- [PVE deployment checklist](./PVE-DEPLOYMENT-RUNBOOK.md)
- [Operations and recovery](./OPERATIONS-RECOVERY.md)
- [Network performance](./NETWORK-PERFORMANCE.md)

All addresses shown in this public repository are examples or workflow
defaults. Choose values appropriate for the target network before building.
