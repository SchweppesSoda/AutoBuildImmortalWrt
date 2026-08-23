# 主路由转发性能与延迟方案

更新日期：2026-07-22

本文只讨论本仓库的 x86-64 PVE 主路由：四 vCPU、VirtIO 多队列、两条 PPPoE 和 mwan3。结论不是“把所有加速按钮打开”，而是先保证策略路由正确，再根据吞吐或延迟目标选择互斥方案。

## 1. 出厂基线

主路由镜像采用以下默认值：

| 项目 | 镜像状态 | 实际作用 |
|---|---|---|
| ImmortalWrt `autocore` | 已内置并运行 | 在 x86 上配置 RFS，并尝试开启 checksum、scatter-gather、GSO、TSO 等网卡能力 |
| Packet steering | 开启 | 让包处理可分布到多个 vCPU |
| `irqbalance` | 已安装并开启 | 在四 vCPU VM 中分散 VirtIO 网卡中断 |
| `kmod-nft-offload` | 已安装、软件 flow offload 关闭 | 可降低路由/NAT 快路径的 CPU 消耗，但必须通过 mwan3 验证后才能开启 |
| Hardware flow offload | 关闭 | VirtIO 没有可交给 OpenWrt 控制的硬件 NAT 引擎 |
| SQM/CAKE | 已安装、关闭 | 用吞吐上限换取满载时的低延迟；不是峰值吞吐加速 |
| FullCone NAT | 内核能力存在、关闭 | 改变 NAT 映射行为，可能改善游戏/P2P NAT 类型，不提高普通转发吞吐 |
| BBR | 不额外安装/启用 | 只控制本机发起或终止的 TCP；不会加速穿过路由器的 LAN 转发流量 |
| TurboACC/SFE/Shortcut-FE | 不集成 | 不是 25.12 firewall4/nftables + PVE + mwan3 的首选标准路径 |

ImmortalWrt 25.12.1 的 `autocore` 源码明确会设置 RFS 以及网卡 checksum/GSO/TSO 等功能；它已经是 x86 默认包，无需再找一个同名“加速 APK”。参考 [ImmortalWrt autocore Makefile](https://github.com/immortalwrt/immortalwrt/blob/v25.12.1/package/emortal/autocore/Makefile) 和 [autocore 启动脚本](https://github.com/immortalwrt/immortalwrt/blob/v25.12.1/package/emortal/autocore/files/autocore)。

## 2. 为什么 flow offload 不默认开启

OpenWrt LuCI 把软件 flow offload 定义为路由/NAT 的软件快路径，同时明确提示它与 QoS/SQM 不完全兼容。参见 [LuCI firewall offloading 设置实现](https://github.com/openwrt/luci/blob/master/applications/luci-app-firewall/htdocs/luci-static/resources/view/firewall/zones.js)。

mwan3 依赖连接跟踪、fwmark 和策略路由。OpenWrt 已有确认问题显示，flow offload 在存在额外路由表和包标记时可能跳过部分规则路径，导致流量走错下一跳；PPPoE flowtable 也曾出现设备选择问题。参见 [策略路由与 flow offload 问题](https://github.com/openwrt/openwrt/issues/18471) 和 [PPPoE flow offload 问题](https://github.com/openwrt/openwrt/issues/14365)。这些报告不等于 25.12 必然失败，但足以说明它必须在你的双线配置上实测，而不能作为未经验证的出厂默认值。

因此默认“兼容模式”为：

```sh
uci set 'firewall.@defaults[0].flow_offloading=0'
uci set 'firewall.@defaults[0].flow_offloading_hw=0'
uci commit firewall
/etc/init.d/firewall restart
```

## 3. 吞吐优先的试验模式

只有在两条 PPPoE、mwan3、端口映射和固定出口规则全部正常后，才试验软件 flow offload：

```sh
uci set 'firewall.@defaults[0].flow_offloading=1'
uci set 'firewall.@defaults[0].flow_offloading_hw=0'
uci commit firewall
/etc/init.d/firewall restart
nft list flowtable inet fw4 ft
```

开启后必须逐项验证：

1. WAN1、WAN2 分别测速，观察单核是否打满。
2. 拔掉 WAN1，再恢复；随后对 WAN2 重复，检查 mwan3 故障切换和恢复。
3. 验证 `wan1_only`、`wan2_only`、sticky 和默认 balanced 策略。
4. 验证 Lucky DDNS、端口映射、入站回包和需要稳定公网 IP 的业务。
5. 验证选择旁路由的客户端和直连客户端。
6. 连续运行至少一天，检查连接异常、路由漂移和 CPU softirq。

如果任一策略异常，立即回到兼容模式。正常工作的 offload 会绕过一部分常规网络栈，抓包也可能看不到全部数据，排障时应先关闭 offload。

PVE 虚拟机不要开启 hardware flow offload。它要求设备拥有受支持的硬件 NAT/flow engine；VirtIO vNIC 并不提供这类由来宾 OpenWrt 管理的硬件通路。

## 4. 延迟优先的 SQM 模式

SQM 解决的是 Bufferbloat：宽带跑满时队列过长，导致网页、语音、视频会议和游戏延迟升高。它在 CPU 上整形，通常把速率限制在实测带宽的约 90% 至 95%，所以峰值测速会下降。OpenWrt 官方说明见 [SQM 文档](https://openwrt.org/docs/guide-user/network/traffic-shaping/sqm)。

使用原则：

- 先关闭软件和硬件 flow offload。
- 分别测量 WAN1、WAN2 的稳定上下行，不直接照抄运营商标称值。
- 分别给运行时 PPPoE 设备配置 SQM，通常是 `pppoe-wan1` 与 `pppoe-wan2`。
- 首选 CAKE，并按 PPPoE/VLAN 实际封装设置 overhead。
- 每改一次只测试一条线，再测试 mwan3 负载均衡与切换。

镜像只预装 `luci-app-sqm`/`sqm-scripts`，不会猜测你的带宽或自动启用整形。

## 5. VirtIO、多队列和 CPU

这部分往往比增加第三方 APK 更有效：

- 主路由 VM 使用四 vCPU，CPU 类型 `host`。
- `net0`、`net1`、`net2` 都使用 VirtIO，并在 PVE 中设置四队列（Multiqueue/Queues = 4）。
- 不要给两条 WAN 建共享 bridge；每个 WAN bridge 只挂一个物理口和一个主路由 vNIC。
- 主路由内已启用 packet steering 和 irqbalance。
- 不要一开始就做 CPU pinning；先用实际负载查看 `/proc/interrupts` 和 softirq，再决定是否绑定。

常用检查：

```sh
cat /proc/interrupts
cat /proc/softirqs
ethtool -l eth0
ethtool -k eth0
top
```

OpenWrt 官方 `irqbalance` 配置默认是关闭的；本镜像仅针对推荐的四 vCPU 主路由将其开启。上游默认值见 [irqbalance 配置](https://github.com/openwrt/packages/blob/master/utils/irqbalance/files/irqbalance.config)。

## 6. 不作为“转发加速”的功能

### BBR

BBR 是 TCP 拥塞控制算法。LAN 客户端经过 NAT 转发时，TCP 两端是客户端与互联网服务器，主路由不是 TCP 端点，因此给路由器启用 BBR不会提高这些连接的转发速度。它只可能影响 Lucky 等直接在路由器上终止或发起的 TCP，需单独测试后再考虑。

### FullCone

FullCone 可能让部分游戏、语音和 P2P 更容易获得开放 NAT，但也扩大入站映射行为。它不是吞吐优化，默认关闭；只有明确需要 NAT 类型且理解安全影响时再启用。

### AppFilter/行为管理

`luci-app-appfilter` 在 25.12 APK 仓库中存在，但深度包识别、记录和分类会增加 CPU、存储与隐私成本，也可能与加密 DNS/QUIC、OpenClash 和 flow offload 的可见性冲突。因此不放进基础镜像。确有家长控制或审计需求时，再独立安装、定义保存周期和告知家庭成员。

### TurboACC/SFE

旧版仓库文档中的 TurboACC/SFE/Shortcut-FE 面向较早的 OpenWrt/iptables 或特定补丁树。本方案使用 25.12 的 firewall4/nftables 标准能力，并且主路由还有 mwan3；不引入难以审计的第二套快路径。

## 7. 推荐验收指标

每种模式至少记录：

- 每条宽带单独的下载、上传、空载延迟和满载延迟。
- 双线同时有流量时的总 CPU、单 vCPU softirq 和丢包。
- mwan3 切换时间、旧连接行为和新连接出口。
- OpenClash 测试客户端与直连客户端的 DNS、出口 IP 和延迟。
- 24 小时稳定性。

保留默认兼容模式的 PVE 备份。任何“加速”调整都应一次只改一个变量，并在主路由 VM 控制台和 PVE 救援口可用时进行。
