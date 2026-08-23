# Generic PVE deployment checklist

## Before import

- Record the physical NIC-to-PVE-interface mapping.
- Create dedicated WAN bridges and a LAN bridge.
- Confirm local console or recovery access to the PVE host.
- Verify image checksums and retain a known-good PVE backup.

## Router VM

- Use x86-64/q35-compatible virtual hardware supported by the selected image.
- Attach three VirtIO network interfaces in LAN, WAN1, WAN2 order.
- Use multiple queues only after the PVE host and guest CPU allocation are
  stable.
- Start with both PPPoE interfaces disabled.

## Gateway VM

- Attach one VirtIO interface to the LAN bridge.
- Keep DHCP and OpenClash disabled during initial reachability testing.
- Do not make the Gateway a dependency for PVE management or other critical
  infrastructure.

## Acceptance checks

- Router and Gateway are reachable only from intended management networks.
- Exactly one DHCP server is active on the LAN.
- WAN bridges are not accidentally connected to the LAN bridge.
- Each PPPoE session works independently before mwan3 is enabled.
- A Gateway outage can be bypassed by selecting the Router as gateway and DNS.
- LuCI, SSH, terminal services, and the PVE UI are not exposed directly to WAN.

All VM IDs, hostnames, bridge names, physical ports, and production addresses
are deployment choices and are intentionally absent from this repository.
