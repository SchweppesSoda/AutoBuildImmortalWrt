#!/bin/sh

# Configure unused local sources and upstream WAN-only routing before enabling.
uci set po0_outbound_ip_report.main.probe_mode='source'
uci set po0_outbound_ip_report.main.probe_dns_server='@ROUTER_LAN_IP@'
uci -q delete po0_outbound_ip_report.main.router_probe_url
uci -q delete po0_outbound_ip_report.main.direct_probe_resolve
uci -q delete po0_outbound_ip_report.main.official_source_wan1
uci -q delete po0_outbound_ip_report.main.official_source_wan2
uci set po0_outbound_ip_report.main.wans='all'
uci set po0_outbound_ip_report.main.enabled='0'
uci commit po0_outbound_ip_report
exit 0
