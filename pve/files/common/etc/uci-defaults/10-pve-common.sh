#!/bin/sh

[ -r /usr/libexec/pve-firstboot.sh ] || exit 1
. /usr/libexec/pve-firstboot.sh || exit 1

LOG_FILE="/root/pve-firstboot.log"
exec >>"${LOG_FILE}" 2>&1 || exit 1
echo "[$(date)] applying common PVE image defaults"

# Use Argon as the default LuCI theme.
pve_uci -q set luci.main.lang='zh_cn'
pve_uci -q set luci.main.mediaurlbase='/luci-static/argon'

# Management daemons must not bind to a WAN network.  uhttpd is protected by
# the role firewall; SSH and ttyd are additionally tied to the LAN interface.
pve_uci -q set 'dropbear.@dropbear[0].Interface=lan'
pve_uci -q set 'ttyd.@ttyd[0].interface=@lan'

pve_uci -q commit luci
pve_uci -q commit dropbear
pve_uci -q commit ttyd

pve_service /etc/init.d/qemu-ga enable

echo "[$(date)] common PVE image defaults complete"
exit 0
