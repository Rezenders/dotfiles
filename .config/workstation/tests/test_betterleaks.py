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
        self.hook = self.home / ".config/git/hooks/pre-commit"
        self.env = {
            **os.environ,
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": str(self.home / ".gitconfig"),
            "PATH": f"{self.home}/.local/bin:/usr/bin:/bin",
        }

        mock_bin = self.home / "betterleaks"
        mock_bin.write_text(
            '#!/bin/sh\n'
            'if [ "$1" = "version" ]; then echo "1.10.0"; exit 0; fi\n'
            'printf "%s\\n" "$*" >> "$HOME/scans.log"\n'
            'git diff --cached --name-only > "$HOME/scanned-files" || exit 2\n'
            'exit "${BETTERLEAKS_TEST_EXIT:-0}"\n'
        )
        mock_bin.chmod(0o755)
        self.archive_path = self.home / "betterleaks_1.10.0_linux_x64.tar.gz"
        with tarfile.open(self.archive_path, "w:gz") as tar:
            tar.add(mock_bin, arcname="betterleaks")
        self.checksum = f"sha256:{hashlib.sha256(self.archive_path.read_bytes()).hexdigest()}"

        tasks = self.home / "tasks.yml"
        tasks.write_text((ROOT / "tasks/betterleaks.yml").read_text().replace(
            "https://github.com/betterleaks/betterleaks/releases/download/v{{ betterleaks_version }}/betterleaks_{{ betterleaks_version }}_linux_x64.tar.gz",
            self.archive_path.as_uri(),
        ))
        self.playbook = self.home / "test.yml"
        self.playbook_vars: dict[str, str | bool] = {
            "workstation_home": str(self.home),
            "ansible_python_interpreter": sys.executable,
            "betterleaks_version": "1.10.0",
            "betterleaks_checksum": self.checksum,
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
        assert ANSIBLE is not None
        result = subprocess.run(
            [ANSIBLE, str(self.playbook), "-i", "localhost,", *args],
            env=self.env, capture_output=True, text=True,
        )
        if expect_success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def git(self, *args, cwd=None, expect_success=True, extra_env=None):
        result = subprocess.run(
            ["/usr/bin/git", *args], cwd=cwd or self.home,
            env={**self.env, **(extra_env or {})}, capture_output=True, text=True,
        )
        if expect_success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_install_and_idempotent_rerun(self):
        self.run_tasks()
        installed_bin = self.home / ".local/bin/betterleaks"
        self.assertTrue(os.access(installed_bin, os.X_OK))
        self.assertTrue(os.access(self.hook, os.X_OK))
        self.assertIn("Managed by Ansible", self.hook.read_text())
        self.assertIn("betterleaks", self.hook.read_text())
        self.assertEqual(
            self.git("config", "--global", "--get", "core.hooksPath").stdout.strip(),
            str(self.hook.parent),
        )
        result = self.run_tasks()
        self.assertIn("changed=0", result.stdout)

    def test_check_mode_does_not_install(self):
        self.run_tasks("--check")
        self.assertFalse((self.home / ".local/bin/betterleaks").exists())
        self.assertFalse(self.hook.exists())
        self.assertFalse((self.home / ".gitconfig").exists())

    def test_hook_can_be_disabled(self):
        self.playbook_vars["enable_global_git_hook"] = False
        self._write_playbook()
        self.run_tasks()
        self.assertTrue((self.home / ".local/bin/betterleaks").exists())
        self.assertFalse(self.hook.exists())
        self.assertFalse((self.home / ".gitconfig").exists())

    def test_preserves_unmanaged_existing_hook(self):
        self.hook.parent.mkdir(parents=True)
        # Merely mentioning Betterleaks does not make a hook Ansible-managed.
        content = "#!/bin/sh\n# custom betterleaks hook\nexit 0\n"
        self.hook.write_text(content)
        self.hook.chmod(0o755)
        result = self.run_tasks(expect_success=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("An unmanaged pre-commit hook exists", result.stdout + result.stderr)
        self.assertEqual(self.hook.read_text(), content)
        self.assertFalse((self.home / ".gitconfig").exists())

    def test_preserves_other_hooks_and_git_settings(self):
        self.hook.parent.mkdir(parents=True)
        pre_push = self.hook.parent / "pre-push"
        pre_push.write_text("#!/bin/sh\nexit 0\n")
        pre_push.chmod(0o755)
        self.git("config", "--global", "user.name", "Test User")
        self.git("config", "--global", "core.hooksPath", "/old/hooks")
        self.run_tasks()
        self.assertEqual(pre_push.read_text(), "#!/bin/sh\nexit 0\n")
        self.assertTrue(os.access(pre_push, os.X_OK))
        self.assertEqual(
            self.git("config", "--global", "--get", "user.name").stdout.strip(),
            "Test User",
        )
        self.assertEqual(
            self.git("config", "--global", "--get", "core.hooksPath").stdout.strip(),
            str(self.hook.parent),
        )

    def test_global_hook_takes_precedence_over_existing_includes(self):
        included = self.home / "included.gitconfig"
        included.write_text("[core]\n    hooksPath = /other/hooks\n")
        config = self.home / ".gitconfig"
        original = f"[core]\n    hooksPath = /old/hooks\n[include]\n    path = {included}\n"
        config.write_text(original)
        self.run_tasks()
        self.assertTrue(config.read_text().startswith(original))
        self.assertEqual(
            self.git("config", "--global", "--get", "core.hooksPath").stdout.strip(),
            str(self.hook.parent),
        )
        self.assertIn("changed=0", self.run_tasks().stdout)

    def test_hook_runs_for_normal_and_bare_repositories_and_blocks_failures(self):
        self.run_tasks()
        self.git("config", "--global", "user.name", "Test User")
        self.git("config", "--global", "user.email", "test@example.invalid")
        normal = self.home / "project"
        self.git("init", str(normal))
        bare = self.home / ".cfg"
        self.git("init", "--bare", str(bare))
        work_tree = self.home / "dotfiles"
        work_tree.mkdir()
        for cwd, prefix in [
            (normal, []),
            (self.home, [f"--git-dir={bare}", f"--work-tree={work_tree}"]),
        ]:
            with self.subTest(prefix=prefix):
                root = work_tree if prefix else normal
                (root / "example.txt").write_text("staged content\n")
                self.git(*prefix, "add", "example.txt", cwd=cwd)
                self.git(*prefix, "commit", "-m", "clean commit", cwd=cwd)
                self.assertEqual((self.home / "scanned-files").read_text(), "example.txt\n")
                (root / "example.txt").write_text("updated staged content\n")
                self.git(*prefix, "add", "example.txt", cwd=cwd)
                before = self.git(*prefix, "rev-parse", "HEAD", cwd=cwd).stdout
                result = self.git(
                    *prefix, "commit", "-m", "blocked commit", cwd=cwd,
                    expect_success=False, extra_env={"BETTERLEAKS_TEST_EXIT": "1"},
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.git(*prefix, "rev-parse", "HEAD", cwd=cwd).stdout, before)
        self.assertEqual((self.home / "scans.log").read_text().splitlines(),
                         ["git --pre-commit --staged --redact -v"] * 4)
