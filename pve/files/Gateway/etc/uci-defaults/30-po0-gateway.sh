#!/bin/sh

# Keep reporting disabled until the Worker URL and secret are configured in LuCI.
uci set po0_outbound_ip_report.main.router_probe_url='http://@ROUTER_LAN_IP@/cgi-bin/po0-wan-probe'
uci set po0_outbound_ip_report.main.wans='all'
uci set po0_outbound_ip_report.main.enabled='0'
uci commit po0_outbound_ip_report

exit 0
