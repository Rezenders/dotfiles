"""Check profile package selection without apt, sudo, or network access."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
ZATHURA = {"zathura", "zathura-cb", "zathura-ps", "zathura-djvu"}


def load(path):
    return yaml.safe_load((ROOT / path).read_text())


class PackageProfileTests(unittest.TestCase):
    def test_desktop_packages_are_profile_specific(self):
        common = load("vars/common.yml")
        self.assertTrue(ZATHURA.isdisjoint(common["common_packages"]))
        self.assertTrue(common["install_firefox"])
        for profile in ("personal", "work"):
            self.assertTrue(ZATHURA.issubset(load(f"vars/{profile}.yml")["desktop_packages"]))
        server = load("vars/server.yml")
        self.assertEqual(server["desktop_packages"], [])
        self.assertFalse(server["install_firefox"])
        self.assertFalse(server["install_personal_apps"])

    def test_firefox_tasks_share_a_guard_and_preserve_install_order(self):
        block = load("tasks/packages.yml")[-1]
        self.assertEqual(block["when"], "install_firefox | bool")
        tasks = block["block"]
        self.assertEqual(tasks[0]["ansible.builtin.apt"]["name"], "firefox")
        self.assertTrue(tasks[0]["ansible.builtin.apt"]["allow_downgrade"])
        self.assertEqual(tasks[-1]["ansible.builtin.command"]["argv"],
                         ["/usr/bin/snap", "remove", "firefox"])

    def test_mozilla_repository_management_is_guarded(self):
        mozilla_items = 0
        mozilla_tasks = 0
        for task in load("tasks/repositories.yml"):
            for item in task.get("loop", []):
                if "mozilla" in str(item):
                    mozilla_items += 1
                    self.assertEqual(item["enabled"], "{{ install_firefox }}")
                    self.assertEqual(task["when"], "item.enabled | bool")
            if "Mozilla" in task["name"] or "Firefox" in task["name"]:
                mozilla_tasks += 1
                self.assertEqual(task["when"], "install_firefox | bool")
        self.assertEqual(mozilla_items, 2)
        self.assertEqual(mozilla_tasks, 3)

    @unittest.skipUnless(shutil.which("ansible-playbook"), "ansible-playbook is required")
    def test_server_renders_package_list_and_skips_all_firefox_tasks(self):
        tasks = load("tasks/packages.yml")
        # Replace package operations with debug; leave Firefox's block intact.
        # Its disabled condition must skip even stat/command tasks safely.
        for task in tasks:
            if "ansible.builtin.apt" in task:
                task.pop("become", None)
                task["ansible.builtin.debug"] = {"msg": task.pop("ansible.builtin.apt")["name"]}
        variables = {**load("vars/common.yml"), **load("vars/server.yml")}
        play = [{"hosts": "localhost", "gather_facts": False,
                 "connection": "local", "vars": variables, "tasks": tasks}]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "test.yml"
            path.write_text(json.dumps(play))
            result = subprocess.run(
                ["ansible-playbook", str(path), "-i", "localhost,"],
                capture_output=True, text=True,
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("changed=0", result.stdout)
        self.assertIn("skipped=6", result.stdout)
