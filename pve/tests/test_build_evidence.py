"""Exercise real build metadata with fake downloads/make in a disposable tree."""
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

PVE = Path(__file__).resolve().parents[1]
BASH = os.environ.get("PVE_TEST_BASH") or shutil.which("bash")


@unittest.skipUnless(BASH, "Bash required")
class BuildEvidenceTests(unittest.TestCase):
    def run_build(self, mismatched=False):
        scratch = PVE.parent / ".tmp"
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="build-evidence-", dir=scratch) as temporary:
            root = Path(temporary)
            pve = root / "pve"
            pve.mkdir()
            for leaf in ("build.sh", "validate-inputs.sh"):
                (pve / leaf).write_text((PVE / leaf).read_text(), newline="\n")
            shutil.copytree(PVE / "files", pve / "files")
            shutil.copytree(PVE / "packages", pve / "packages")
            versions = (PVE / "versions.env").read_text()
            empty_hash = hashlib.sha256(b"").hexdigest()
            versions = re.sub(r'(?m)^(ARGON_\w+_SHA256)="[a-f0-9]+"$', lambda m: f'{m[1]}="{empty_hash}"', versions)
            (pve / "versions.env").write_text(versions, newline="\n")
            (pve / "vendor-packages.lock").write_text("# synthetic empty vendor set\n")
            fake = root / "fake-bin"
            fake.mkdir()
            # These two are the only external build/download commands in the Router path.
            for leaf, body in {
                "curl": '#!/bin/sh\nprintf download >> "$TRACE"\nwhile [ "$#" -gt 0 ]; do if [ "$1" = --output ]; then shift; : > "$1"; exit 0; fi; shift; done\nexit 99\n',
                "make": '#!/bin/sh\nprintf make >> "$TRACE"\nexit 0\n',
            }.items():
                path = fake / leaf
                path.write_text(body, newline="\n")
                path.chmod(0o755)
            image = re.search(r'^IMAGEBUILDER_IMAGE="(.+)"$', versions, re.M)[1]
            env = {**os.environ, "IMAGEBUILDER_ROOT": root.as_posix(), "FIXBIN": fake.as_posix(),
                   "TRACE": (root / "trace").as_posix(), "IMAGEBUILDER_USED": image + ("bad" if mismatched else ""),
                   "SOURCE_COMMIT": "a" * 40, "ROOTFS_PARTSIZE": "2048", "ROUTER_LAN_IP": "192.168.100.1",
                   "GATEWAY_LAN_IP": "192.168.100.2", "LAN_NETMASK": "255.255.255.0"}
            result = subprocess.run([BASH, "--noprofile", "--norc", "-c",
                'export PATH="$(cd "$FIXBIN" && pwd):/usr/bin:/bin"; exec /bin/bash "$1" Router', "fixture", (pve / "build.sh").as_posix()],
                capture_output=True, text=True, env=env, timeout=20)
            trace = (root / "trace").read_text() if (root / "trace").exists() else ""
            metadata = {p.name: p.read_text() for p in (root / "bin/pve-meta").glob("*")} if (root / "bin/pve-meta").exists() else {}
            return result, trace, metadata, image, empty_hash

    def test_actual_inputs_and_source_are_recorded(self):
        result, trace, metadata, image, digest = self.run_build()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("downloaddownloaddownloadmake", trace)
        info = metadata["build-info-Router.txt"]
        self.assertIn("imagebuilder_used=" + image, info)
        self.assertIn("source_commit=" + "a" * 40, info)
        hashes = metadata["apk-inputs-Router.sha256"].splitlines()
        self.assertEqual(3, len(hashes))
        self.assertTrue(all(line.startswith(digest) and line[64:].strip().lstrip("*").startswith("./") for line in hashes), hashes)
        self.assertIn("versions-Router.env", metadata)
        self.assertIn("vendor-packages-Router.lock", metadata)
        self.assertIn("package-request-Router.txt", metadata)

    def test_mismatched_builder_stops_before_download_or_make(self):
        result, trace, metadata, _, _ = self.run_build(mismatched=True)
        self.assertEqual(2, result.returncode)
        self.assertEqual("", trace)
        self.assertEqual({}, metadata)


if __name__ == "__main__":
    unittest.main()
