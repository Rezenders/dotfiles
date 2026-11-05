"""Exercise Yazi's font setup without sudo, network access, or system changes."""
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
class YaziTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name)
        source = self.home / "source"
        source.mkdir()
        (source / "SymbolsNerdFontMono-Regular.ttf").write_text("test font")
        (source / "LICENSE").write_text("test license")
        self.fonts = self.home / ".local/share/fonts/NerdFontsSymbolsOnly"
        self.bin = self.home / "bin"
        self.bin.mkdir()
        cache = self.bin / "fc-cache"
        cache.write_text('#!/bin/sh\nprintf "refresh\\n" >> "$HOME/cache-calls"\n')
        cache.chmod(0o755)
        tasks = self.home / "tasks.yml"
        tasks.write_text((ROOT / "tasks/yazi.yml").read_text().replace(
            "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.4.0/patched-fonts/NerdFontsSymbolsOnly",
            source.as_uri(),
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
            env={**os.environ, "HOME": str(self.home),
                 "PATH": str(self.bin) + os.pathsep + os.environ["PATH"]},
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_install_and_idempotent_rerun(self):
        self.run_tasks()
        result = self.run_tasks()
        self.assertEqual((self.fonts / "SymbolsNerdFontMono-Regular.ttf").read_text(), "test font")
        self.assertEqual((self.fonts / "LICENSE").read_text(), "test license")
        self.assertEqual((self.home / "cache-calls").read_text(), "refresh\n")
        self.assertIn("changed=0", result.stdout)

    def test_check_mode_does_not_download_or_refresh(self):
        self.run_tasks("--check")
        self.assertFalse(self.fonts.exists())
        self.assertFalse((self.home / "cache-calls").exists())
