"""Exercise Betterleaks tasks with a local archive, without sudo or network access."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ANSIBLE = shutil.which("ansible-playbook")


@unittest.skipUnless(ANSIBLE, "ansible-playbook is required")
class BetterleaksTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name)

        # Create a mock betterleaks binary
        self.mock_bin_dir = self.home / "mock_src"
        self.mock_bin_dir.mkdir(parents=True)
        mock_bin = self.mock_bin_dir / "betterleaks"
        mock_bin.write_text('#!/bin/sh\nif [ "$1" = "version" ]; then echo "1.10.0"; exit 0; fi\n')
        mock_bin.chmod(0o755)

        # Create a mock tar.gz containing betterleaks
        self.archive_path = self.home / "betterleaks_1.10.0_linux_x64.tar.gz"
        with tarfile.open(self.archive_path, "w:gz") as tar:
            tar.add(mock_bin, arcname="betterleaks")

        archive_bytes = self.archive_path.read_bytes()
        self.checksum = f"sha256:{hashlib.sha256(archive_bytes).hexdigest()}"

        # Mock tide_cfg bare repository
        self.tide_cfg = self.home / ".tide_cfg"
        (self.tide_cfg / "hooks").mkdir(parents=True)

        tasks = self.home / "tasks.yml"
        tasks.write_text((ROOT / "tasks/betterleaks.yml").read_text().replace(
            "https://github.com/betterleaks/betterleaks/releases/download/v{{ betterleaks_version }}/betterleaks_{{ betterleaks_version }}_linux_x64.tar.gz",
            self.archive_path.as_uri(),
        ))

        self.playbook = self.home / "test.yml"
        self.playbook_vars = {
            "workstation_home": str(self.home),
            "ansible_python_interpreter": sys.executable,
            "install_betterleaks": True,
            "betterleaks_version": "1.10.0",
            "betterleaks_checksum": self.checksum,
            "enable_tide_cfg_hook": True,
            "tide_git_dir": str(self.tide_cfg),
            "tide_work_tree": str(self.home / "rock_local_ws"),
        }
        self._write_playbook()

    def _write_playbook(self):
        self.playbook.write_text(json.dumps([{
            "hosts": "localhost",
            "connection": "local",
            "gather_facts": False,
            "vars": self.playbook_vars,
            "tasks": [{"ansible.builtin.import_tasks": str(self.home / "tasks.yml")}],
        }]))

    def run_tasks(self, *args, expect_success=True):
        result = subprocess.run(
            [ANSIBLE, str(self.playbook), "-i", "localhost,", *args],
            env={**os.environ, "HOME": str(self.home)},
            capture_output=True, text=True,
        )
        if expect_success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_install_and_idempotent_rerun(self):
        self.run_tasks()
        installed_bin = self.home / ".local/bin/betterleaks"
        self.assertTrue(installed_bin.exists())
        self.assertTrue(os.access(installed_bin, os.X_OK))

        hook = self.tide_cfg / "hooks/pre-commit"
        self.assertTrue(hook.exists())
        self.assertTrue(os.access(hook, os.X_OK))
        self.assertIn("Managed by Ansible", hook.read_text())
        self.assertIn("betterleaks", hook.read_text())

        # Second run should be idempotent
        result = self.run_tasks()
        self.assertIn("changed=0", result.stdout)

    def test_check_mode_does_not_install(self):
        self.run_tasks("--check")
        self.assertFalse((self.home / ".local/bin/betterleaks").exists())
        self.assertFalse((self.tide_cfg / "hooks/pre-commit").exists())

    def test_hook_disabled_when_not_work_persona(self):
        self.playbook_vars["enable_tide_cfg_hook"] = False
        self._write_playbook()
        self.run_tasks()
        self.assertTrue((self.home / ".local/bin/betterleaks").exists())
        self.assertFalse((self.tide_cfg / "hooks/pre-commit").exists())

    def test_preserves_unmanaged_existing_hook(self):
        hook = self.tide_cfg / "hooks/pre-commit"
        hook.write_text("#!/bin/sh\n# custom pre-commit hook\nexit 0\n")
        hook.chmod(0o755)

        result = self.run_tasks(expect_success=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("An unmanaged pre-commit hook exists", result.stdout + result.stderr)
        # Ensure it was not overwritten
        self.assertEqual(hook.read_text(), "#!/bin/sh\n# custom pre-commit hook\nexit 0\n")
