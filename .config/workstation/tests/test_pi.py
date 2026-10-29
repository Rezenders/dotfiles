"""Exercise the real Pi Ansible tasks with temporary homes and stub CLIs.

The apt task is excluded using its packages tag; no sudo or network is used.
"""
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
class PiTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "home"
        self.home.mkdir()
        self.bin = self.home / ".local/bin"
        self.settings = self.home / ".pi/agent/settings.json"
        self.log = self.home / "commands.jsonl"
        self.node = self.base / "node"
        self.node.write_text("#!/bin/sh\nprintf 'v22.22.1\\n'\n")
        self.node.chmod(0o755)
        self.pi_template = self.base / "pi-template"
        self.pi_template.write_text(f"#!{sys.executable}\n" + '''
import json
import os
from pathlib import Path
import sys
home = Path(os.environ["HOME"])
assert os.environ["PI_CODING_AGENT_DIR"] == str(home / ".pi/agent")
args = sys.argv[1:]
with (home / "commands.jsonl").open("a") as log:
    log.write(json.dumps(["pi", *args]) + "\\n")
if args[0] == "install":
    path = home / ".pi/agent/settings.json"
    settings = json.loads(path.read_text()) if path.exists() else {}
    settings.setdefault("packages", []).append(args[1])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(settings))
''')
        self.pi_template.chmod(0o755)
        self.npm = self.base / "npm"
        self.npm.write_text(f"#!{sys.executable}\n" + '''
import json
import os
from pathlib import Path
import shutil
import sys
home = Path(os.environ["HOME"])
args = sys.argv[1:]
assert args[:3] == ["install", "--global", "--prefix"]
assert args[3] == str(home / ".local")
with (home / "commands.jsonl").open("a") as log:
    log.write(json.dumps(["npm", *args]) + "\\n")
bin_dir = home / ".local/bin"
bin_dir.mkdir(parents=True, exist_ok=True)
if args[-1].startswith("@earendil-works/pi-coding-agent"):
    assert "--ignore-scripts" in args
    shutil.copy2(home.parent / "pi-template", bin_dir / "pi")
else:
    assert args[-1].startswith("@ast-grep/cli")
    assert "--ignore-scripts" not in args
    path = bin_dir / "ast-grep"
    path.write_text("#!/bin/sh\\nexit 0\\n")
    path.chmod(0o755)
''')
        self.npm.chmod(0o755)
        self.playbook = self.base / "test.yml"
        self.playbook.write_text(json.dumps([{
            "name": "Test Pi tasks without system changes",
            "hosts": "localhost",
            "connection": "local",
            "gather_facts": False,
            "vars_files": [str(ROOT / "vars.yml")],
            "vars": {
                "workstation_home": str(self.home),
                "pi_node_executable": str(self.node),
                "pi_npm_executable": str(self.npm),
                "ansible_env": {"PATH": os.environ["PATH"]},
            },
            "tasks": [{"ansible.builtin.import_tasks": str(ROOT / "tasks/pi.yml")}],
        }]))

    def run_tasks(self, *args, success=True):
        result = subprocess.run(
            [ANSIBLE, str(self.playbook), "-i", "localhost,", "--skip-tags", "packages",
             "-e", json.dumps({
                 "ansible_python_interpreter": sys.executable,
                 "pi_node_executable": str(self.node),
                 "pi_npm_executable": str(self.npm),
             }), *args],
            env=dict(os.environ, ANSIBLE_NOCOLOR="1"),
            capture_output=True, text=True,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def save_settings(self, packages):
        self.settings.parent.mkdir(parents=True)
        self.settings.write_text(json.dumps({"theme": "keep-me", "packages": packages}))

    def test_fresh_install_and_idempotent_rerun(self):
        self.run_tasks()
        commands = self.commands()
        self.assertEqual(sum(c[0] == "npm" for c in commands), 2)
        self.assertEqual(sum(c[:2] == ["pi", "install"] for c in commands), 5)
        self.assertEqual(commands[-1], ["pi", "update", "--extensions"])
        self.run_tasks()
        self.assertEqual(self.commands(), commands)

    def test_preserve_settings_and_object_declarations(self):
        existing = {"source": "npm:pi-subagents", "skills": []}
        self.save_settings([existing, "npm:unrelated-package"])
        self.run_tasks()
        settings = json.loads(self.settings.read_text())
        self.assertEqual(settings["theme"], "keep-me")
        self.assertIn(existing, settings["packages"])
        self.assertIn("npm:unrelated-package", settings["packages"])
        self.assertNotIn(["pi", "install", "npm:pi-subagents"], self.commands())
        # A new managed Pi reconciles declarations restored from dotfiles.
        self.assertEqual(self.commands()[-1], ["pi", "update", "--extensions"])

    def test_explicit_updates(self):
        self.run_tasks()
        count = len(self.commands())
        self.run_tasks("-e", "update_pi=true", "-e", "update_pi_extensions=true")
        commands = self.commands()[count:]
        self.assertEqual(sum(c[0] == "npm" for c in commands), 2)
        self.assertEqual(commands[-1], ["pi", "update", "--extensions"])
        self.assertFalse(any(c[:2] == ["pi", "install"] for c in commands))

    def test_check_mode_executes_no_installers(self):
        self.run_tasks("--check")
        self.assertEqual(self.commands(), [])
        self.assertFalse(self.settings.exists())
        self.assertFalse(self.bin.exists())

    def test_missing_runtime_is_deferred_in_check_mode(self):
        self.npm.unlink()
        result = self.run_tasks("--check")
        self.assertIn("deferred until apply", result.stdout)
        self.assertEqual(self.commands(), [])

    def test_unsupported_node_fails_before_installing(self):
        self.node.write_text("#!/bin/sh\nprintf 'v20.0.0\\n'\n")
        self.run_tasks(success=False)
        self.assertEqual(self.commands(), [])

    def test_invalid_settings_are_not_overwritten(self):
        self.settings.parent.mkdir(parents=True)
        self.settings.write_text("not json")
        self.run_tasks(success=False)
        self.assertEqual(self.settings.read_text(), "not json")
        self.assertFalse(any(c[0] == "pi" for c in self.commands()))


if __name__ == "__main__":
    unittest.main()
