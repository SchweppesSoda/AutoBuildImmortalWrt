# PVE first-boot failure handling — 2026-09-21

The four PVE `uci-defaults` scripts previously reached `exit 0` after failed
required UCI calls. ImmortalWrt v25.12.1's boot script removes successful
defaults, so this could hide partial configuration and remove the retry path.

All required UCI writes, package reads, commits and service defaults now check
their return status through `pve-firstboot.sh`. Missing optional keys remain
idempotent: a successful package read must establish absence before deletion
is skipped. UCI arguments and raw errors are not logged. There is no blanket
`set -e`, no new package dependency, no change to PPPoE/proxy safe defaults,
and no reporter version upgrade.

Offline validation runs the real four scripts against an in-memory UCI and
isolated init-script fixtures. Every required UCI step is failed in turn;
failure is nonzero, stops subsequent UCI operations and emits no completion
marker or injected secret. Missing helper, failed service defaults, absent
deletes and repeated application are covered. Together with the existing
input suite, 12 tests passed on Windows with Git Bash. Shell parsing passed.
These fixtures do not emulate OpenWrt's entire boot, UCI storage or BusyBox.

No ImageBuilder build, release, guest import or device command was run.
Acceptance still requires an authorized image build and isolated cloned-VM
boot/retry check. Preserve the previous image and configuration; never rerun
these defaults on a live router to test them. This change ensures failure is
visible and retryable, not that partially committed UCI packages are atomic.

Upstream contract: [ImmortalWrt v25.12.1 boot](https://github.com/immortalwrt/immortalwrt/blob/v25.12.1/package/base-files/files/etc/init.d/boot).
