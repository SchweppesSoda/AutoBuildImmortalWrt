#!/bin/sh

LOG_FILE="/root/pve-firstboot.log"
exec >>"${LOG_FILE}" 2>&1
echo "[$(date)] applying Router defaults"

uci -q set 'system.@system[0].hostname=Router'

# Reassert the deterministic PVE mapping after OpenWrt's earlier board-default
# scripts have run.  No interface is auto-detected or silently bridged.
uci -q delete network.wan
uci -q delete network.wan6
uci -q set network.br_lan='device'
uci -q set network.br_lan.name='br-lan'
uci -q set network.br_lan.type='bridge'
uci -q delete network.br_lan.ports
uci -q add_list network.br_lan.ports='eth0'
uci -q set network.lan='interface'
uci -q set network.lan.device='br-lan'
uci -q set network.lan.proto='static'
uci -q set network.lan.ipaddr='@ROUTER_LAN_IP@'
uci -q set network.lan.netmask='@LAN_NETMASK@'
uci -q set network.lan.delegate='0'
uci -q delete network.lan.ip6assign
uci -q delete network.lan.ip6hint
uci -q delete network.lan.ip6class
uci -q delete network.globals.ula_prefix

# ttyd/libwebsockets binds to only one address when a device has multiple
# IPv4 addresses. Pin it to the trusted management address instead of @lan so
# additional guest or IoT addresses on br-lan cannot capture port 7681.
uci -q set 'ttyd.@ttyd[0].interface=@ROUTER_LAN_IP@'

uci -q set network.wan1='interface'
uci -q set network.wan1.device='eth1'
uci -q set network.wan1.proto='pppoe'
uci -q set network.wan1.ipv6='1'
uci -q set network.wan1.metric='10'
uci -q set network.wan1.auto='0'
uci -q delete network.wan1_6
uci -q set network.wan1_6='interface'
uci -q set network.wan1_6.device='@wan1'
uci -q set network.wan1_6.proto='dhcpv6'
uci -q set network.wan1_6.reqaddress='try'
uci -q set network.wan1_6.reqprefix='no'
uci -q set network.wan1_6.delegate='0'
uci -q set network.wan1_6.defaultroute='1'
uci -q set network.wan1_6.peerdns='1'
uci -q set network.wan1_6.metric='10'
uci -q set network.wan1_6.auto='1'
uci -q set network.wan2='interface'
uci -q set network.wan2.device='eth2'
uci -q set network.wan2.proto='pppoe'
uci -q set network.wan2.ipv6='0'
uci -q set network.wan2.metric='20'
uci -q set network.wan2.auto='0'
uci -q delete network.wan2_6
uci -q set network.globals.packet_steering='1'

# Keep LAN IPv4-only. dnsmasq serves last octets 100 through 249 while odhcpd
# provides no DHCPv6, RA, or NDP service on the LAN.
uci -q set dhcp.lan.interface='lan'
uci -q set dhcp.lan.ignore='0'
uci -q set dhcp.lan.start='100'
uci -q set dhcp.lan.limit='150'
uci -q set dhcp.lan.leasetime='12h'
uci -q set dhcp.lan.dhcpv4='server'
uci -q set dhcp.lan.dhcpv6='disabled'
uci -q set dhcp.lan.ra='disabled'
uci -q set dhcp.lan.ndp='disabled'
uci -q delete dhcp.lan.ra_slaac
uci -q delete dhcp.lan.ra_flags
uci -q delete dhcp.lan.max_preferred_lifetime
uci -q delete dhcp.lan.max_valid_lifetime

find_zone() {
  uci -q show firewall | sed -n \
    "s/^\(firewall\.[^.]*\)\.name='${1}'$/\1/p" | head -n 1
}

lan_zone="$(find_zone lan)"
if [ -z "${lan_zone}" ]; then
  uci -q set firewall.pve_lan='zone'
  uci -q set firewall.pve_lan.name='lan'
  lan_zone='firewall.pve_lan'
fi
uci -q set "${lan_zone}.input=ACCEPT"
uci -q set "${lan_zone}.output=ACCEPT"
uci -q set "${lan_zone}.forward=ACCEPT"
uci -q delete "${lan_zone}.network"
uci -q add_list "${lan_zone}.network=lan"

wan_zone="$(find_zone wan)"
if [ -z "${wan_zone}" ]; then
  uci -q set firewall.pve_wan='zone'
  uci -q set firewall.pve_wan.name='wan'
  wan_zone='firewall.pve_wan'
fi
uci -q set "${wan_zone}.input=REJECT"
uci -q set "${wan_zone}.output=ACCEPT"
uci -q set "${wan_zone}.forward=REJECT"
uci -q set "${wan_zone}.masq=1"
uci -q set "${wan_zone}.mtu_fix=1"
uci -q delete "${wan_zone}.network"
uci -q add_list "${wan_zone}.network=wan1"
uci -q add_list "${wan_zone}.network=wan1_6"
uci -q add_list "${wan_zone}.network=wan2"

# Keep the standard LAN-to-WAN forwarding even if an upstream default image
# changes its anonymous forwarding sections.
uci -q set firewall.pve_lan_wan='forwarding'
uci -q set firewall.pve_lan_wan.src='lan'
uci -q set firewall.pve_lan_wan.dest='wan'

# Flow offload can skip packet-marking paths used by policy routing.  The
# module and LuCI switch are present, but validation comes before enabling it.
uci -q set 'firewall.@defaults[0].flow_offloading=0'
uci -q set 'firewall.@defaults[0].flow_offloading_hw=0'
uci -q set 'firewall.@defaults[0].fullcone=0'
uci -q set 'firewall.@defaults[0].fullcone6=0'

# Useful with four vCPUs and VirtIO multiqueue.  ImmortalWrt's built-in
# autocore separately configures RFS and NIC checksum/GSO/TSO offloads.
uci -q set irqbalance.irqbalance.enabled='1'
if uci -q get 'sqm.@queue[0]' >/dev/null; then
  uci -q set 'sqm.@queue[0].enabled=0'
fi

uci -q commit system
uci -q commit network
uci -q commit dhcp
uci -q commit firewall
uci -q commit irqbalance
uci -q commit sqm
uci -q commit ttyd

if [ -x /etc/init.d/irqbalance ]; then
  /etc/init.d/irqbalance enable
fi

for expected_if in eth0 eth1 eth2; do
  if [ ! -e "/sys/class/net/${expected_if}" ]; then
    echo "WARNING: expected PVE interface ${expected_if} was not detected"
  fi
done

echo "[$(date)] Router defaults complete"
exit 0
