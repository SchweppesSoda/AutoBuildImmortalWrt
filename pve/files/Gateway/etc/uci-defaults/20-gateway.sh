#!/bin/sh

[ -r /usr/libexec/pve-firstboot.sh ] || exit 1
. /usr/libexec/pve-firstboot.sh || exit 1

LOG_FILE="/root/pve-firstboot.log"
exec >>"${LOG_FILE}" 2>&1 || exit 1
echo "[$(date)] applying Gateway defaults"

pve_uci -q set 'system.@system[0].hostname=Gateway'

# Reassert the one-arm PVE mapping after earlier board-default scripts.
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
pve_uci -q set network.lan.ipaddr='@GATEWAY_LAN_IP@'
pve_uci -q set network.lan.netmask='@LAN_NETMASK@'
pve_uci -q set network.lan.gateway='@ROUTER_LAN_IP@'
pve_delete_if_present network.lan.dns
pve_uci -q add_list network.lan.dns='@ROUTER_LAN_IP@'
pve_uci -q set network.lan.delegate='0'
pve_uci -q set network.globals.packet_steering='1'

# dnsmasq remains available for OpenClash DNS, but this VM must never answer
# DHCP requests on the shared LAN.
pve_uci -q set dhcp.lan.interface='lan'
pve_uci -q set dhcp.lan.ignore='1'
pve_uci -q set dhcp.lan.dhcpv6='disabled'
pve_uci -q set dhcp.lan.ra='disabled'
pve_uci -q set dhcp.lan.ndp='disabled'

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

# OpenClash relies on nftables marks/TProxy.  Flow offload is therefore never
# enabled on this role image.
pve_uci -q set 'firewall.@defaults[0].flow_offloading=0'
pve_uci -q set 'firewall.@defaults[0].flow_offloading_hw=0'
pve_uci -q set 'firewall.@defaults[0].fullcone=0'
pve_uci -q set 'firewall.@defaults[0].fullcone6=0'

pve_uci -q commit system
pve_uci -q commit network
pve_uci -q commit dhcp
pve_uci -q commit firewall

# A pinned core and Geo data are present, but no subscription or policy is.
# Do not start interception until the user has reviewed the configuration.
pve_service /etc/init.d/openclash disable

if [ ! -e /sys/class/net/eth0 ]; then
  echo "WARNING: expected PVE interface eth0 was not detected"
fi

echo "[$(date)] Gateway defaults complete"
exit 0
