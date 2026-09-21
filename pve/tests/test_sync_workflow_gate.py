"""Synthetic local Git histories; no remotes, network, credentials or push."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("gate", Path(__file__).resolve().parents[1] / "sync_workflow_gate.py")
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)


class WorkflowGateTests(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[2] / ".tmp"
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch, prefix="sync-gate-")
        self.addCleanup(self.temp.cleanup)
        self.previous = Path.cwd()
        os.chdir(self.temp.name)
        self.addCleanup(os.chdir, self.previous)
        self.git("init", "--quiet")
        self.git("config", "user.name", "Offline Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.base = self.commit("README.md", "initial\n")

    def git(self, *args):
        return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.strip()

    def commit(self, name, content):
        path = Path(name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        self.git("add", "--", name)
        self.git("commit", "--quiet", "-m", "fixture")
        return self.git("rev-parse", "HEAD")

    def test_no_change_and_ordinary_update_allow_existing_permissions(self):
        self.assertEqual([], GATE.changed_workflows(self.base, self.base))
        candidate = self.commit("pve/example.txt", "ordinary\n")
        self.assertEqual([], GATE.changed_workflows(self.base, candidate))

    def test_workflow_addition_and_deletion_require_manual_review(self):
        candidate = self.commit(".github/workflows/example.yml", "name: fixture\n")
        expected = [".github/workflows/example.yml"]
        self.assertEqual(expected, GATE.changed_workflows(self.base, candidate))
        self.assertEqual(expected, GATE.changed_workflows(candidate, self.base))

    def test_published_branch_difference_is_also_gated(self):
        published = self.commit(".github/workflows/example.yml", "name: fixture\n")
        self.assertEqual([".github/workflows/example.yml"], GATE.changed_workflows(self.base, self.base, published))

    def test_invalid_ref_fails_closed(self):
        with self.assertRaises(subprocess.CalledProcessError):
            GATE.changed_workflows("nonexistent-fixture-ref", self.base)


if __name__ == "__main__":
    unittest.main()
