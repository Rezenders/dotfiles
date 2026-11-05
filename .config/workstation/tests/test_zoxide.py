"""Exercise zoxide tasks with a local installer, without sudo or network access."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ANSIBLE = shutil.which("ansible-playbook")


@unittest.skipUnless(ANSIBLE, "ansible-playbook is required")
class ZoxideTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name)
        installer = self.home / "install.sh"
        installer.write_text('''#!/bin/sh
set -eu
printf 'install\\n' >> "$HOME/calls"
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\\necho "# zoxide initialized"\\n' > "$HOME/.local/bin/zoxide"
chmod +x "$HOME/.local/bin/zoxide"
''')
        tasks = self.home / "tasks.yml"
        tasks.write_text((ROOT / "tasks/zoxide.yml").read_text().replace(
            "https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh",
            installer.as_uri(),
        ))
        self.playbook = self.home / "test.yml"
        self.playbook.write_text(json.dumps([{
            "hosts": "localhost",
            "connection": "local",
            "gather_facts": False,
            "vars": {
                "workstation_home": str(self.home),
                "ansible_python_interpreter": sys.executable,
            },
            "tasks": [{"ansible.builtin.import_tasks": str(tasks)}],
        }]))

    def run_tasks(self, *args):
        result = subprocess.run(
            [ANSIBLE, str(self.playbook), "-i", "localhost,", "--skip-tags", "packages", *args],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_install_and_idempotent_rerun(self):
        bashrc = self.home / ".bashrc"
        bashrc.write_text("# existing Bash configuration\n")
        self.run_tasks()
        result = self.run_tasks()
        self.assertIn("changed=0", result.stdout)
        self.assertEqual((self.home / "calls").read_text(), "install\n")
        content = bashrc.read_text()
        self.assertTrue(content.startswith("# existing Bash configuration\n"))
        self.assertEqual(content.count('eval "$(zoxide init bash)"'), 1)
        self.assertLess(content.index('export PATH='), content.index('eval '))
        shell = subprocess.run(
            ["bash", "--noprofile", "--norc", "-c", 'source "$HOME/.bashrc"; command -v zoxide'],
            env={**os.environ, "HOME": str(self.home)}, capture_output=True, text=True,
        )
        self.assertEqual(shell.returncode, 0, shell.stderr)
        self.assertEqual(shell.stdout.strip(), str(self.home / ".local/bin/zoxide"))

    def test_check_mode_does_not_install(self):
        self.run_tasks("--check")
        self.assertFalse((self.home / "calls").exists())
        self.assertFalse((self.home / ".local/bin/zoxide").exists())
        self.assertFalse((self.home / ".bashrc").exists())

    def test_existing_installation_is_preserved(self):
        binary = self.home / ".local/bin/zoxide"
        binary.parent.mkdir(parents=True)
        binary.write_text("existing")
        self.run_tasks()
        self.assertFalse((self.home / "calls").exists())
        self.assertEqual(binary.read_text(), "existing")
        self.assertIn('eval "$(zoxide init bash)"', (self.home / ".bashrc").read_text())
