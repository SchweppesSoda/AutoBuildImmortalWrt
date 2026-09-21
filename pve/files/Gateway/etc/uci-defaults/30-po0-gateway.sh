#!/bin/sh

[ -r /usr/libexec/pve-firstboot.sh ] || exit 1
. /usr/libexec/pve-firstboot.sh || exit 1

# Configure unused local sources and upstream WAN-only routing before enabling.
pve_uci set po0_outbound_ip_report.main.probe_mode='source'
pve_uci set po0_outbound_ip_report.main.probe_dns_server='@ROUTER_LAN_IP@'
pve_delete_if_present po0_outbound_ip_report.main.router_probe_url
pve_delete_if_present po0_outbound_ip_report.main.direct_probe_resolve
pve_delete_if_present po0_outbound_ip_report.main.official_source_wan1
pve_delete_if_present po0_outbound_ip_report.main.official_source_wan2
pve_uci set po0_outbound_ip_report.main.wans='all'
pve_uci set po0_outbound_ip_report.main.enabled='0'
pve_uci commit po0_outbound_ip_report
exit 0
