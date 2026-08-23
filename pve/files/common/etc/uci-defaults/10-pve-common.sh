#!/bin/sh

LOG_FILE="/root/pve-firstboot.log"
exec >>"${LOG_FILE}" 2>&1
echo "[$(date)] applying common PVE image defaults"

# Use Argon as the default LuCI theme.
uci -q set luci.main.lang='zh_cn'
uci -q set luci.main.mediaurlbase='/luci-static/argon'

# Management daemons must not bind to a WAN network.  uhttpd is protected by
# the role firewall; SSH and ttyd are additionally tied to the LAN interface.
uci -q set 'dropbear.@dropbear[0].Interface=lan'
uci -q set 'ttyd.@ttyd[0].interface=@lan'

uci -q commit luci
uci -q commit dropbear
uci -q commit ttyd

if [ -x /etc/init.d/qemu-ga ]; then
  /etc/init.d/qemu-ga enable
fi

echo "[$(date)] common PVE image defaults complete"
exit 0
