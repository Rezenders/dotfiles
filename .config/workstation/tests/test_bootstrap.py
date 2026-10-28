"""Bootstrap safety tests: local Git only, no privileged operations."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BOOTSTRAP = Path(__file__).resolve().parents[1] / "bootstrap.sh"


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        if os.geteuid() == 0:
            self.skipTest("Bootstrap intentionally refuses root")
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "home"
        self.home.mkdir()
        self.bin = self.base / "bin"
        self.bin.mkdir()
        sudo = self.bin / "sudo"
        sudo.write_text("#!/bin/sh\nexit 0\n")
        sudo.chmod(0o755)
        self.source = self.base / "source"
        self.source.mkdir()
        self.git("init", "-q", str(self.source))
        playbook = self.source / ".config/workstation/workstation.yml"
        playbook.parent.mkdir(parents=True)
        playbook.write_text("# fixture\n")
        (self.source / ".test-dotfile").write_text("repository version\n")
        self.git("-C", str(self.source), "add", ".")
        self.git("-C", str(self.source), "-c", "user.name=Test",
                 "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture")
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        DOTFILES_URL=str(self.source))

    def git(self, *args):
        return subprocess.run(["/usr/bin/git", *args], check=True,
                              capture_output=True, text=True)

    def run_bootstrap(self):
        return subprocess.run(["bash", str(BOOTSTRAP)], env=self.env,
                              capture_output=True, text=True)

    def test_new_home_checks_out_files(self):
        result = self.run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / ".test-dotfile").read_text(),
                         "repository version\n")
        self.assertIn("Bootstrap complete", result.stdout)

    def test_conflict_does_not_overwrite_existing_file(self):
        existing = self.home / ".test-dotfile"
        existing.write_text("keep me\n")
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(existing.read_text(), "keep me\n")
        self.assertIn("checkout stopped", result.stderr)

    def test_rerun_preserves_local_edits(self):
        self.assertEqual(self.run_bootstrap().returncode, 0)
        existing = self.home / ".test-dotfile"
        existing.write_text("local changes\n")
        result = self.run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(existing.read_text(), "local changes\n")
        self.assertIn("left untouched", result.stdout)

    def test_non_repository_cfg_is_not_replaced(self):
        cfg = self.home / ".cfg"
        cfg.mkdir()
        sentinel = cfg / "keep"
        sentinel.write_text("keep me\n")
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sentinel.read_text(), "keep me\n")


if __name__ == "__main__":
    unittest.main()
