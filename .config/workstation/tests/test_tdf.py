"""Exercise tdf tasks with stub Cargo, without sudo or network access."""
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
class TdfTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name)
        cargo_bin = self.home / ".cargo/bin"
        cargo_bin.mkdir(parents=True)
        cargo = cargo_bin / "cargo"
        cargo.write_text(f"#!{sys.executable}\n" + '''
import os
from pathlib import Path
import sys
home = Path(os.environ["HOME"])
assert os.environ["CARGO_HOME"] == str(home / ".cargo")
assert os.environ["RUSTUP_HOME"] == str(home / ".rustup")
assert sys.argv[1:] == ["+stable", "install", "--git", "https://github.com/itsjunetime/tdf.git"]
with (home / "calls").open("a") as log:
    log.write("install\\n")
(home / ".cargo/bin/tdf").touch()
''')
        cargo.chmod(0o755)
        rustup = cargo_bin / "rustup"
        rustup.write_text(f"#!{sys.executable}\n" + '''
import os
from pathlib import Path
import sys
home = Path(os.environ["HOME"])
assert os.environ["RUSTUP_HOME"] == str(home / ".rustup")
assert sys.argv[1:] == ["update", "stable", "--no-self-update"]
with (home / "calls").open("a") as log:
    log.write("rustup update stable\\n")
''')
        rustup.chmod(0o755)
        self.playbook = self.home / "test.yml"
        self.playbook.write_text(json.dumps([{
            "hosts": "localhost",
            "connection": "local",
            "gather_facts": False,
            "vars": {
                "workstation_home": str(self.home),
                "ansible_env": {"PATH": os.environ["PATH"]},
                "ansible_python_interpreter": sys.executable,
            },
            "tasks": [{"ansible.builtin.import_tasks": str(ROOT / "tasks/tdf.yml")}],
        }]))

    def run_tasks(self, *args):
        result = subprocess.run(
            [ANSIBLE, str(self.playbook), "-i", "localhost,", "--skip-tags", "packages", *args],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_install_and_idempotent_rerun(self):
        self.run_tasks()
        self.run_tasks()
        self.assertEqual((self.home / "calls").read_text(), "rustup update stable\ninstall\n")
        self.assertEqual((self.home / ".profile").read_text(),
                         'export PATH="$HOME/.cargo/bin:$PATH"\n')

    def test_check_mode_does_not_install(self):
        self.run_tasks("--check")
        self.assertFalse((self.home / "calls").exists())
        self.assertFalse((self.home / ".cargo/bin/tdf").exists())

    def test_existing_installation_is_preserved(self):
        binary = self.home / ".cargo/bin/tdf"
        binary.write_text("existing")
        self.run_tasks()
        self.assertFalse((self.home / "calls").exists())
        self.assertEqual(binary.read_text(), "existing")
