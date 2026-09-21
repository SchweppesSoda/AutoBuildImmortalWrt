"""Run real defaults with an in-memory UCI double; never touch host UCI/init."""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PVE = Path(__file__).resolve().parents[1]
BASH = os.environ.get("PVE_TEST_BASH") or shutil.which("bash")
FILES = (
    "common/etc/uci-defaults/10-pve-common.sh",
    "Router/etc/uci-defaults/20-router.sh",
    "Gateway/etc/uci-defaults/20-gateway.sh",
    "Gateway/etc/uci-defaults/30-po0-gateway.sh",
)
HARNESS = r'''
export PATH=/usr/bin:/bin:$PATH
declare -A values=(
 [network.wan]=interface [network.wan6]=interface [network.wan2_6]=interface
 [network.globals]=globals [network.br_lan.ports]=old
 [network.lan.dns]=old [network.lan.ip6assign]=64
 [firewall.@zone\[0\].name]=lan [firewall.@zone\[0\].network]=old
 [firewall.@zone\[1\].name]=wan [firewall.@zone\[1\].network]=old
 [sqm.@queue\[0\]]=queue [po0_outbound_ip_report.main]=po0
 [po0_outbound_ip_report.main.router_probe_url]=synthetic
)
if [[ -f $STATE ]]; then source "$STATE"; fi
canonical_state() {
  for item in "${!values[@]}"; do printf '%s\t%s\n' "$item" "${values[$item]}"; done | sort > "$CANONICAL"
}
trap canonical_state EXIT
uci() {
  [[ ${1:-} != -q ]] || shift
  local action=$1 key=${2:-} package count=0 item
  [[ ! -f $COUNTER ]] || read -r count < "$COUNTER"
  count=$((count + 1)); printf '%s\n' "$count" > "$COUNTER"
  printf '%s|%s|%s\n' "$count" "$action" "${key%%=*}" >> "$TRACE"
  if [[ $count == "$FAIL_AT" ]]; then echo secret-marker >&2; return 42; fi
  case $action in
    show)
      case $key in luci|dropbear|ttyd|system|network|dhcp|firewall|irqbalance|sqm|po0_outbound_ip_report) ;; *) return 43 ;; esac
      for item in "${!values[@]}"; do
        [[ $item != "$key" && $item != "$key."* ]] || printf "%s='%s'\n" "$item" "${values[$item]}"
      done ;;
    get) [[ -v values[$key] ]] || return 1; printf '%s\n' "${values[$key]}" ;;
    set) values[${key%%=*}]=${key#*=} ;;
    add_list)
      item=${key%%=*}; values[$item]="${values[$item]:-}${values[$item]:+ }${key#*=}" ;;
    delete) [[ -v values[$key] ]] || return 1; unset 'values[$key]' ;;
    commit) ;;
    *) return 99 ;;
  esac
  declare -p values > "$STATE"
  return 0
}
source "$1"
'''


@unittest.skipUnless(BASH, "Bash is required for offline UCI fixtures")
class FirstBootTests(unittest.TestCase):
    def setUp(self):
        scratch = PVE.parent / ".tmp"
        scratch.mkdir(exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(prefix="firstboot-", dir=scratch)
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.helper = self.root / "pve-firstboot.sh"
        self.helper.write_text((PVE / "files/common/usr/libexec/pve-firstboot.sh").read_text(), newline="\n")
        (self.root / "init").mkdir()
        (self.root / "net").mkdir()
        for iface in ("eth0", "eth1", "eth2"):
            (self.root / "net" / iface).touch()
        for service in ("qemu-ga", "irqbalance", "openclash"):
            path = self.root / "init" / service
            path.write_text('#!/bin/sh\n[ "${FAIL_SERVICE:-0}" != 1 ]\n', newline="\n")
            path.chmod(0o755)

    def run_script(self, relative, fail_at=0, fail_service=False, reuse=False):
        if not reuse:
            (self.root / "state").unlink(missing_ok=True)
        for name in ("counter", "trace", "log"):
            (self.root / name).unlink(missing_ok=True)
        text = (PVE / "files" / relative).read_text()
        text = text.replace("/usr/libexec/pve-firstboot.sh", self.helper.as_posix())
        text = text.replace("/root/pve-firstboot.log", (self.root / "log").as_posix())
        text = text.replace("/etc/init.d/", (self.root / "init").as_posix() + "/")
        text = text.replace("/sys/class/net/", (self.root / "net").as_posix() + "/")
        script = self.root / "defaults.sh"
        script.write_text(text, newline="\n")
        result = subprocess.run([BASH, "--noprofile", "--norc", "-c", HARNESS, "firstboot-test", script.as_posix()],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "COUNTER": (self.root / "counter").as_posix(),
                 "STATE": (self.root / "state").as_posix(), "TRACE": (self.root / "trace").as_posix(),
                 "CANONICAL": (self.root / "canonical").as_posix(),
                 "FAIL_AT": str(fail_at), "FAIL_SERVICE": str(int(fail_service))})
        log = (self.root / "log").read_text() if (self.root / "log").exists() else ""
        trace = (self.root / "trace").read_text().splitlines() if (self.root / "trace").exists() else []
        return result, log, trace

    def test_required_uci_failure_at_every_step_preserves_retry(self):
        for script in FILES:
            result, log, trace = self.run_script(script)
            self.assertEqual(0, result.returncode, result.stderr + log)
            for entry in trace:
                step, action, _ = entry.split("|", 2)
                with self.subTest(script=script, step=step, action=action):
                    result, log, failed_trace = self.run_script(script, fail_at=step)
                    self.assertNotEqual(0, result.returncode, log)
                    self.assertNotIn("defaults complete", log)
                    self.assertNotIn("secret-marker", log + result.stderr + result.stdout)
                    self.assertEqual(step, failed_trace[-1].split("|", 1)[0])

    def test_absent_deletes_and_repeated_application_keep_the_same_values(self):
        for script in FILES:
            with self.subTest(script=script):
                result, log, _ = self.run_script(script)
                self.assertEqual(0, result.returncode, result.stderr + log)
                first = (self.root / "canonical").read_bytes()
                result, log, _ = self.run_script(script, reuse=True)
                self.assertEqual(0, result.returncode, result.stderr + log)
                self.assertEqual(first, (self.root / "canonical").read_bytes())

    def test_required_service_default_failure_is_not_success(self):
        for script in FILES[:3]:
            with self.subTest(script=script):
                result, log, _ = self.run_script(script, fail_service=True)
                self.assertNotEqual(0, result.returncode)
                self.assertIn("PVE_FIRSTBOOT_FAILED", log)
                self.assertNotIn("defaults complete", log)

    def test_missing_helper_is_rejected_before_any_uci(self):
        self.helper.unlink()
        result, _, trace = self.run_script(FILES[3])
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([], trace)


if __name__ == "__main__":
    unittest.main()
