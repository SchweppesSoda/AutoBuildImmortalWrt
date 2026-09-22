"""Offline APK staging checks; synthetic metadata, no installs or network."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("reporter_stage", ROOT / "shell/stage-reporter-apk.py")
stager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stager)


class ReporterStagingTests(unittest.TestCase):
    def setUp(self):
        scratch = ROOT / ".tmp"
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="reporter-stage-", dir=scratch)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.package = self.root / "po0-outbound-ip-report.apk"
        self.package.write_bytes(b"synthetic checked package")
        self.destination = self.root / "packages"

    def stage(self, document):
        with patch.object(stager.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, json.dumps(document))) as run:
            result = stager.stage(Path("host-apk"), self.package, self.destination)
        self.assertEqual(run.call_args.args[0], ["host-apk", "adbdump", "--format", "json", str(self.package)])
        return result

    def test_internal_revision_names_index_member_and_preserves_bytes(self):
        target = self.stage({"info": {"name": "po0-outbound-ip-report", "version": "2026.09.05-r4"}})
        self.assertEqual(target.name, "po0-outbound-ip-report-2026.09.05-r4.apk")
        self.assertEqual(target.read_bytes(), self.package.read_bytes())
        self.assertEqual(list(self.destination.iterdir()), [target])

    def test_invalid_or_missing_identity_never_stages(self):
        for info in ({}, {"name": "other", "version": "1-r1"},
                     {"name": "po0-outbound-ip-report", "version": "../../escape"},
                     {"name": "po0-outbound-ip-report", "version": 123}):
            with self.subTest(info=info), self.assertRaises((KeyError, ValueError)):
                self.stage({"info": info})
            self.assertFalse(self.destination.exists())

    def test_bad_metadata_or_reader_failure_never_stages(self):
        for output in ("broken json", "{}"):
            with patch.object(stager.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, output)):
                with self.assertRaises((ValueError, KeyError)):
                    stager.stage(Path("host-apk"), self.package, self.destination)
        with patch.object(stager.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "apk")):
            with self.assertRaises(subprocess.CalledProcessError):
                stager.stage(Path("host-apk"), self.package, self.destination)
        self.assertFalse(self.destination.exists())

    def test_existing_package_is_preserved(self):
        document = {"info": {"name": "po0-outbound-ip-report", "version": "1-r1"}}
        target = self.stage(document)
        target.write_bytes(b"existing package")
        with self.assertRaises(ValueError):
            self.stage(document)
        self.assertEqual(target.read_bytes(), b"existing package")


if __name__ == "__main__":
    unittest.main()
