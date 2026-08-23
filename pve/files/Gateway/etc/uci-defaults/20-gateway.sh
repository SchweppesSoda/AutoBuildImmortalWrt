#!/bin/sh

LOG_FILE="/root/pve-firstboot.log"
exec >>"${LOG_FILE}" 2>&1
echo "[$(date)] applying Gateway defaults"

uci -q set 'system.@system[0].hostname=Gateway'

# Reassert the one-arm PVE mapping after earlier board-default scripts.
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
uci -q set network.lan.ipaddr='@GATEWAY_LAN_IP@'
uci -q set network.lan.netmask='@LAN_NETMASK@'
uci -q set network.lan.gateway='@ROUTER_LAN_IP@'
uci -q delete network.lan.dns
uci -q add_list network.lan.dns='@ROUTER_LAN_IP@'
uci -q set network.lan.delegate='0'
uci -q set network.globals.packet_steering='1'

# dnsmasq remains available for OpenClash DNS, but this VM must never answer
# DHCP requests on the shared LAN.
uci -q set dhcp.lan.interface='lan'
uci -q set dhcp.lan.ignore='1'
uci -q set dhcp.lan.dhcpv6='disabled'
uci -q set dhcp.lan.ra='disabled'
uci -q set dhcp.lan.ndp='disabled'

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

# OpenClash relies on nftables marks/TProxy.  Flow offload is therefore never
# enabled on this role image.
uci -q set 'firewall.@defaults[0].flow_offloading=0'
uci -q set 'firewall.@defaults[0].flow_offloading_hw=0'
uci -q set 'firewall.@defaults[0].fullcone=0'
uci -q set 'firewall.@defaults[0].fullcone6=0'

uci -q commit system
uci -q commit network
uci -q commit dhcp
uci -q commit firewall

# A pinned core and Geo data are present, but no subscription or policy is.
# Do not start interception until the user has reviewed the configuration.
if [ -x /etc/init.d/openclash ]; then
  /etc/init.d/openclash disable
fi

if [ ! -e /sys/class/net/eth0 ]; then
  echo "WARNING: expected PVE interface eth0 was not detected"
fi

echo "[$(date)] Gateway defaults complete"
exit 0
