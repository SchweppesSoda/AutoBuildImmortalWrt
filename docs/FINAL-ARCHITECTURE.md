# Generic PVE dual-router reference architecture

## Roles

The public profile builds two ImmortalWrt virtual-machine images that share a
LAN bridge but have different responsibilities.

```text
ISP A ---- PVE WAN bridge ---- Router eth1
ISP B ---- PVE WAN bridge ---- Router eth2
                               Router eth0 ---- LAN bridge ---- clients
                                                     |
                                               Gateway eth0
```

`Router` owns WAN connectivity, NAT, DHCPv4, firewalling, policy routing, and
the LAN default gateway. `Gateway` is an optional one-arm policy gateway for
clients that explicitly select it.

## Example addressing

The workflow defaults are deliberately generic:

| Role | Example address |
| --- | --- |
| Router | `192.168.100.1/24` |
| Gateway | `192.168.100.2/24` |
| Router DHCP pool | last octets `100-249` |

The addresses and netmask are workflow inputs. They are rendered into both the
static network files and first-boot scripts during the build. Do not reuse the
defaults where they overlap an upstream router, modem, VPN, or existing LAN.

## Safety properties

- Both PPPoE interfaces are disabled for automatic startup until credentials
  and PVE interface mappings are verified.
- No PPPoE credential or OpenClash subscription is accepted as a workflow
  input or stored in the image.
- Gateway DHCP, IPv6 RA, and OpenClash interception are disabled by default.
- Flow offload is disabled because it can bypass mwan3 or TProxy marking.
- PVE management, LuCI, SSH, and terminal services must not be published
  directly to the internet.

This document is a reference topology, not a record of any real deployment.
