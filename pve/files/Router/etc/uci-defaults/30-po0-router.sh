#!/bin/sh

# Only the paired Gateway may query the Router WAN probe by default.
uci -q delete po0_wan_probe.main.allowed_source
uci add_list po0_wan_probe.main.allowed_source='@GATEWAY_LAN_IP@'
uci set po0_wan_probe.main.enabled='1'
uci commit po0_wan_probe

exit 0
