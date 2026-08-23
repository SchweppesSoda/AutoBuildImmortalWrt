# Generic operations and recovery guide

## Recovery priorities

1. Preserve local console or out-of-band access to PVE.
2. Restore the Router VM and basic LAN/WAN connectivity.
3. Restore the optional Gateway only after direct Router connectivity works.
4. Re-enable mwan3, proxy interception, DDNS, and inbound publishing one
   feature at a time.

## Gateway failure

Clients explicitly using the Gateway can be returned to the Router for both
gateway and DNS. Critical infrastructure should not depend on the optional
Gateway unless an independent fallback has been tested.

## Router failure

Use the PVE console to inspect interface ordering, PPPoE state, firewall rules,
DHCP service, and recent configuration changes. Restore a known-good VM backup
when a quick rollback is safer than repairing the live configuration.

## PVE failure

Keep VM backups outside the PVE system disk. Document physical NIC mapping and
bridge intent in the deployment's private operations repository. After host
recovery, start the Router before the Gateway and other dependent services.

## Change discipline

- Export configuration before high-risk network changes.
- Change one forwarding, policy-routing, or proxy variable at a time.
- Verify checksums for firmware and manually downloaded packages.
- Never store credentials, subscriptions, device inventories, public DNS
  records, or production recovery material in this public repository.
