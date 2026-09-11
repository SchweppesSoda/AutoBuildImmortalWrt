from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


PVE = Path(__file__).resolve().parents[1]
BASH = os.environ.get("PVE_TEST_BASH") or shutil.which("bash")


@unittest.skipUnless(BASH, "Bash is required for input validation tests")
class BuildInputTests(unittest.TestCase):
    def run_input(self, overrides):
        # Reaching versions.env proves that all preflight passed. Exit there so
        # this fixture never downloads packages, runs Docker, or builds an image.
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "pve").mkdir()
            shutil.copyfile(PVE / "validate-inputs.sh", root / "pve/validate-inputs.sh")
            (root / "pve/versions.env").write_text("echo PREFLIGHT_PASSED; exit 0\n", encoding="utf-8")
            script = root / "build.sh"
            script.write_bytes((PVE / "build.sh").read_bytes().replace(b"\r\n", b"\n"))
            env = {**os.environ, "IMAGEBUILDER_ROOT": root.as_posix(),
                   "ROOTFS_PARTSIZE": "2048", "ROUTER_LAN_IP": "192.168.100.1",
                   "GATEWAY_LAN_IP": "192.168.100.2", "LAN_NETMASK": "255.255.255.0", **overrides}
            return subprocess.run([BASH, str(script), "Router"], env=env,
                                  text=True, capture_output=True, timeout=10)

    def test_valid_boundaries_reach_build_preflight(self):
        for value in ("1024", "2048", "8192"):
            with self.subTest(size=value):
                result = self.run_input({"ROOTFS_PARTSIZE": value})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("PREFLIGHT_PASSED", result.stdout)

    def test_rejects_non_decimal_and_out_of_range_sizes(self):
        for value in ("1023", "8193", "0", "08", "02048", "18446744073709553664", "1+2048", "2048\n1"):
            with self.subTest(size=value):
                result = self.run_input({"ROOTFS_PARTSIZE": value})
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertNotIn("PREFLIGHT_PASSED", result.stdout)

    def test_rejects_incomplete_padded_and_multiline_ipv4(self):
        for name in ("ROUTER_LAN_IP", "GATEWAY_LAN_IP", "LAN_NETMASK"):
            for value in ("1.2.3.4.", "1.2.3", "1.2.3.256", "01.2.3.4", "1.2.3.4\n5", "1..2.3", "1.2.3.4 "):
                with self.subTest(name=name, address=value):
                    result = self.run_input({name: value})
                    self.assertEqual(result.returncode, 2, result.stderr)
                    self.assertNotIn("PREFLIGHT_PASSED", result.stdout)

    def test_rejects_duplicate_role_addresses(self):
        result = self.run_input({"GATEWAY_LAN_IP": "192.168.100.1"})
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("must be different", result.stderr)


if __name__ == "__main__":
    unittest.main()
