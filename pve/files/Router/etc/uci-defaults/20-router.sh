#!/bin/sh

[ -r /usr/libexec/pve-firstboot.sh ] || exit 1
. /usr/libexec/pve-firstboot.sh || exit 1

LOG_FILE="/root/pve-firstboot.log"
exec >>"${LOG_FILE}" 2>&1 || exit 1
echo "[$(date)] applying Router defaults"

pve_uci -q set 'system.@system[0].hostname=Router'

# Reassert the deterministic PVE mapping after OpenWrt's earlier board-default
# scripts have run.  No interface is auto-detected or silently bridged.
pve_delete_if_present network.wan
pve_delete_if_present network.wan6
pve_uci -q set network.br_lan='device'
pve_uci -q set network.br_lan.name='br-lan'
pve_uci -q set network.br_lan.type='bridge'
pve_delete_if_present network.br_lan.ports
pve_uci -q add_list network.br_lan.ports='eth0'
pve_uci -q set network.lan='interface'
pve_uci -q set network.lan.device='br-lan'
pve_uci -q set network.lan.proto='static'
pve_uci -q set network.lan.ipaddr='@ROUTER_LAN_IP@'
pve_uci -q set network.lan.netmask='@LAN_NETMASK@'
pve_uci -q set network.lan.delegate='0'
pve_delete_if_present network.lan.ip6assign
pve_delete_if_present network.lan.ip6hint
pve_delete_if_present network.lan.ip6class
pve_delete_if_present network.globals.ula_prefix

# ttyd/libwebsockets binds to only one address when a device has multiple
# IPv4 addresses. Pin it to the trusted management address instead of @lan so
# additional guest or IoT addresses on br-lan cannot capture port 7681.
pve_uci -q set 'ttyd.@ttyd[0].interface=@ROUTER_LAN_IP@'

pve_uci -q set network.wan1='interface'
pve_uci -q set network.wan1.device='eth1'
pve_uci -q set network.wan1.proto='pppoe'
pve_uci -q set network.wan1.ipv6='1'
pve_uci -q set network.wan1.metric='10'
pve_uci -q set network.wan1.auto='0'
pve_delete_if_present network.wan1_6
pve_uci -q set network.wan1_6='interface'
pve_uci -q set network.wan1_6.device='@wan1'
pve_uci -q set network.wan1_6.proto='dhcpv6'
pve_uci -q set network.wan1_6.reqaddress='try'
pve_uci -q set network.wan1_6.reqprefix='no'
pve_uci -q set network.wan1_6.delegate='0'
pve_uci -q set network.wan1_6.defaultroute='1'
pve_uci -q set network.wan1_6.peerdns='1'
pve_uci -q set network.wan1_6.metric='10'
pve_uci -q set network.wan1_6.auto='1'
pve_uci -q set network.wan2='interface'
pve_uci -q set network.wan2.device='eth2'
pve_uci -q set network.wan2.proto='pppoe'
pve_uci -q set network.wan2.ipv6='0'
pve_uci -q set network.wan2.metric='20'
pve_uci -q set network.wan2.auto='0'
pve_delete_if_present network.wan2_6
pve_uci -q set network.globals.packet_steering='1'

# Keep LAN IPv4-only. dnsmasq serves network offsets 100 through 249 while odhcpd
# provides no DHCPv6, RA, or NDP service on the LAN.
pve_uci -q set dhcp.lan.interface='lan'
pve_uci -q set dhcp.lan.ignore='0'
pve_uci -q set dhcp.lan.start='100'
pve_uci -q set dhcp.lan.limit='150'
pve_uci -q set dhcp.lan.leasetime='12h'
pve_uci -q set dhcp.lan.dhcpv4='server'
pve_uci -q set dhcp.lan.dhcpv6='disabled'
pve_uci -q set dhcp.lan.ra='disabled'
pve_uci -q set dhcp.lan.ndp='disabled'
pve_delete_if_present dhcp.lan.ra_slaac
pve_delete_if_present dhcp.lan.ra_flags
pve_delete_if_present dhcp.lan.max_preferred_lifetime
pve_delete_if_present dhcp.lan.max_valid_lifetime

firewall_snapshot="$(pve_uci -q show firewall)" || exit 1

find_zone() {
  printf '%s\n' "$firewall_snapshot" | sed -n \
    "s/^\(firewall\.[^.]*\)\.name='${1}'$/\1/p" | head -n 1
}

lan_zone="$(find_zone lan)"
if [ -z "${lan_zone}" ]; then
  pve_uci -q set firewall.pve_lan='zone'
  pve_uci -q set firewall.pve_lan.name='lan'
  lan_zone='firewall.pve_lan'
fi
pve_uci -q set "${lan_zone}.input=ACCEPT"
pve_uci -q set "${lan_zone}.output=ACCEPT"
pve_uci -q set "${lan_zone}.forward=ACCEPT"
pve_delete_if_present "${lan_zone}.network"
pve_uci -q add_list "${lan_zone}.network=lan"

wan_zone="$(find_zone wan)"
if [ -z "${wan_zone}" ]; then
  pve_uci -q set firewall.pve_wan='zone'
  pve_uci -q set firewall.pve_wan.name='wan'
  wan_zone='firewall.pve_wan'
fi
pve_uci -q set "${wan_zone}.input=REJECT"
pve_uci -q set "${wan_zone}.output=ACCEPT"
pve_uci -q set "${wan_zone}.forward=REJECT"
pve_uci -q set "${wan_zone}.masq=1"
pve_uci -q set "${wan_zone}.mtu_fix=1"
pve_delete_if_present "${wan_zone}.network"
pve_uci -q add_list "${wan_zone}.network=wan1"
pve_uci -q add_list "${wan_zone}.network=wan1_6"
pve_uci -q add_list "${wan_zone}.network=wan2"

# Keep the standard LAN-to-WAN forwarding even if an upstream default image
# changes its anonymous forwarding sections.
pve_uci -q set firewall.pve_lan_wan='forwarding'
pve_uci -q set firewall.pve_lan_wan.src='lan'
pve_uci -q set firewall.pve_lan_wan.dest='wan'

# Flow offload can skip packet-marking paths used by policy routing.  The
# module and LuCI switch are present, but validation comes before enabling it.
pve_uci -q set 'firewall.@defaults[0].flow_offloading=0'
pve_uci -q set 'firewall.@defaults[0].flow_offloading_hw=0'
pve_uci -q set 'firewall.@defaults[0].fullcone=0'
pve_uci -q set 'firewall.@defaults[0].fullcone6=0'

# Useful with four vCPUs and VirtIO multiqueue.  ImmortalWrt's built-in
# autocore separately configures RFS and NIC checksum/GSO/TSO offloads.
pve_uci -q set irqbalance.irqbalance.enabled='1'
if pve_has_key 'sqm.@queue[0]'; then
  pve_uci -q set 'sqm.@queue[0].enabled=0'
fi

pve_uci -q commit system
pve_uci -q commit network
pve_uci -q commit dhcp
pve_uci -q commit firewall
pve_uci -q commit irqbalance
pve_uci -q commit sqm
pve_uci -q commit ttyd

pve_service /etc/init.d/irqbalance enable

for expected_if in eth0 eth1 eth2; do
  if [ ! -e "/sys/class/net/${expected_if}" ]; then
    echo "WARNING: expected PVE interface ${expected_if} was not detected"
  fi
done

echo "[$(date)] Router defaults complete"
exit 0
