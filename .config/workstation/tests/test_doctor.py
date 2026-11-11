"""Doctor unit tests: no real services, programs, normal init, or network calls."""
from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('workstation_doctor', ROOT / 'doctor.py')
assert SPEC is not None and SPEC.loader is not None
doctor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(doctor)


class DoctorTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = {'HOME': str(self.home), 'PATH': str(self.bin)}
        self.checker = doctor.Doctor(env=self.env)
        self.output = io.StringIO()
        redirect = redirect_stdout(self.output)
        redirect.__enter__()
        self.addCleanup(redirect.__exit__, None, None, None)
        self.subprocess_mock = patch.object(doctor.subprocess, 'run').start()
        self.addCleanup(patch.stopall)
        self.subprocess_mock.return_value = subprocess.CompletedProcess([], 0, '', '')

    def executable(self, name, directory=None):
        target = (self.bin if directory is None else directory) / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('#!/bin/sh\nexit 0\n')
        target.chmod(0o755)
        return target

    def configs(self):
        kitty = self.checker.config / 'kitty'
        kitty.mkdir(parents=True)
        (kitty / 'kitty.conf').write_text('font_family Test Nerd Font\n')
        # Must compile, never execute or generate a pyc file.
        (kitty / 'tab_bar.py').write_text('raise RuntimeError("must not execute")\n')
        nvim = self.checker.config / 'nvim'
        (nvim / 'lua/custom').mkdir(parents=True)
        (nvim / 'after/ftplugin').mkdir(parents=True)
        (nvim / 'init.lua').write_text('error("must not execute")\n')
        (nvim / 'lua/custom/example.lua').write_text('return {}\n')
        (nvim / 'after/ftplugin/tex.lua').write_text('return {}\n')
        self.executable('kitty')
        self.executable('nvim')
        return kitty, nvim

    def kitty_result(self, bad_lines=None, font='family="Test Nerd Font"', code=0):
        payload = {'font': font, 'bad_lines': bad_lines or []}
        return subprocess.CompletedProcess([], code, 'WORKSTATION_KITTY=' + json.dumps(payload), '')

    def test_path_order_real_targets_and_shadowed_alternatives(self):
        selected = self.executable('node')
        other = self.home / 'other'
        alternative = self.executable('node', other)
        alternative.unlink()
        alternative.symlink_to(selected)
        self.checker.env['PATH'] = os.pathsep.join((str(self.bin), str(other), str(self.bin)))
        self.assertEqual(doctor.executable_paths('node', self.checker.env['PATH']), [selected, alternative])
        self.checker.tools()
        self.assertIn(f'required node: {selected} -> {selected}', self.output.getvalue())
        self.assertIn(f'node shadowed: {alternative} -> {selected}', self.output.getvalue())
        self.subprocess_mock.assert_not_called()

    def test_path_skips_nonexecutables_directories_and_broken_symlinks(self):
        (self.bin / 'nvim').mkdir()
        (self.bin / 'node').write_text('no execute')
        (self.bin / 'pi').symlink_to(self.home / 'missing')
        for name in ('nvim', 'node', 'pi'):
            self.assertIsNone(self.checker.find(name))

    def test_empty_path_entry_means_current_directory(self):
        binary = self.executable('tool')
        with patch.object(doctor.os, 'getcwd', return_value=str(self.bin)):
            self.assertEqual(doctor.executable_paths('tool', ''), [binary])

    def test_mason_fallback_and_external_cmake_override(self):
        mason = self.executable('pyright-langserver', self.checker.mason)
        self.assertIsNone(self.checker.find('pyright-langserver'))
        self.assertEqual(self.checker.find('pyright-langserver', mason=True), mason)
        on_path = self.executable('pyright-langserver')
        self.assertEqual(self.checker.find('pyright-langserver', mason=True), on_path)
        cmake = self.executable('cmake-language-server', self.home / '.local/bin')
        self.assertEqual(self.checker.find(doctor.LANGUAGE_SERVERS['cmake'], mason=True), cmake)
        fdfind = self.executable('fdfind')
        self.assertEqual(self.checker.find('fd|fdfind'), fdfind)

    def test_required_and_optional_missing_tools_and_latex_never_required(self):
        self.checker.tools()
        self.assertIn(('FAIL', 'required kitty: not found on PATH'), self.checker.results)
        for name in ('latexmk', 'pdflatex', 'chktex', 'latexindent', 'zathura'):
            self.assertNotIn(name, doctor.REQUIRED_TOOLS)
            self.assertTrue(any(level == 'WARN' and f'optional {name}:' in message
                                for level, message in self.checker.results))
        self.assertTrue(any('optional LSP texlab' in message and level == 'WARN'
                            for level, message in self.checker.results))

    def test_subprocess_is_bounded_and_never_uses_shell(self):
        self.checker.run(['systemctl', '--user'])
        args, kwargs = self.subprocess_mock.call_args
        self.assertEqual(args[0], ['systemctl', '--user'])
        self.assertEqual(kwargs['timeout'], 10)
        self.assertTrue(kwargs['capture_output'])
        self.assertNotIn('shell', kwargs)

    def test_timeout_and_spawn_errors_become_results(self):
        for error in (subprocess.TimeoutExpired(['nvim'], 10), FileNotFoundError('absent')):
            self.subprocess_mock.side_effect = error
            result = self.checker.run(['nvim'])
            self.assertEqual(result.returncode, 124)
            self.assertTrue(result.stderr)

    def test_config_checks_compile_only_and_isolate_nvim(self):
        kitty, nvim = self.configs()
        self.subprocess_mock.side_effect = [self.kitty_result(), subprocess.CompletedProcess([], 0, '', 'Lua syntax OK')]
        font = self.checker.configs()
        self.assertEqual(font, 'family="Test Nerd Font"')
        self.assertFalse(any(level == 'FAIL' for level, _ in self.checker.results))
        kitty_call, nvim_call = self.subprocess_mock.call_args_list
        self.assertEqual(kitty_call.args[0][1], '+runpy')
        self.assertIn('accumulate_bad_lines=bad', kitty_call.args[0][2])
        self.assertEqual(kitty_call.kwargs['env']['PYTHONDONTWRITEBYTECODE'], '1')
        command = nvim_call.args[0]
        self.assertIn('--clean', command)
        self.assertIn('loadfile(path)', command[-1])
        self.assertNotIn('dofile', command[-1])
        env = nvim_call.kwargs['env']
        files = json.loads(env['WORKSTATION_LUA_FILES'])
        self.assertEqual(len(files), 3)
        self.assertIn(str(nvim / 'init.lua'), files)
        self.assertNotEqual(env['HOME'], str(self.home))
        self.assertFalse(Path(env['HOME']).exists())
        self.assertFalse((kitty / '__pycache__').exists())

    def test_kitty_accumulated_bad_lines_fail_even_with_zero_exit(self):
        self.configs()
        self.subprocess_mock.side_effect = [self.kitty_result(['line 12: invalid option']),
                                subprocess.CompletedProcess([], 0, 'syntax ok', '')]
        self.checker.configs()
        self.assertIn(('FAIL', 'Kitty invalid config lines: line 12: invalid option'), self.checker.results)

    def test_kitty_invalid_or_missing_output_fails(self):
        self.configs()
        for output in ('not json', 'WORKSTATION_KITTY={', 'WORKSTATION_KITTY={}'):
            self.checker.results.clear()
            self.subprocess_mock.side_effect = [subprocess.CompletedProcess([], 1, output, 'parser failed'),
                                    subprocess.CompletedProcess([], 0, '', '')]
            self.checker.configs()
            self.assertIn(('FAIL', 'Kitty parser: parser failed'), self.checker.results)

    def test_bad_python_and_lua_syntax_fail(self):
        kitty, _ = self.configs()
        (kitty / 'tab_bar.py').write_text('if !!!\n')
        self.subprocess_mock.side_effect = [self.kitty_result(), subprocess.CompletedProcess([], 1, '', 'syntax error')]
        self.checker.configs()
        self.assertTrue(any(level == 'FAIL' and 'tab_bar.py' in message for level, message in self.checker.results))
        self.assertIn(('FAIL', 'Neovim loadfile: syntax error'), self.checker.results)

    def test_missing_config_files_fail_without_spawning(self):
        self.checker.configs()
        self.assertEqual(sum(level == 'FAIL' for level, _ in self.checker.results), 3)
        self.subprocess_mock.assert_not_called()

    def test_fonts_use_inventory_not_fontconfig_fallback(self):
        self.executable('fc-list')
        self.subprocess_mock.return_value = subprocess.CompletedProcess([], 0, 'Test Nerd Font,Test NF\nOther\n', '')
        self.checker.fonts('family="Test Nerd Font"')
        self.assertIn(('OK', 'Kitty font family Test Nerd Font: installed'), self.checker.results)
        self.checker.fonts('Missing Nerd Font')
        self.assertIn(('WARN', 'Kitty font family Missing Nerd Font: not found; fallback may be used'), self.checker.results)
        self.assertNotIn('fc-match', self.output.getvalue())

    def test_missing_fonts_or_query_tools_are_warnings(self):
        self.checker.fonts(None)
        self.assertEqual(self.checker.results[-1][0], 'WARN')
        self.executable('fc-list')
        self.subprocess_mock.return_value = subprocess.CompletedProcess([], 0, 'Ordinary Mono\n', '')
        self.checker.fonts(None)
        self.assertIn(('WARN', 'Nerd Fonts: none found'), self.checker.results)
        self.subprocess_mock.return_value = subprocess.CompletedProcess([], 1, '', 'query failed')
        self.checker.fonts(None)
        self.assertIn(('WARN', 'Font query: query failed'), self.checker.results)

    def test_user_services_bus_unavailable_warns_but_failed_units_fail(self):
        self.executable('systemctl')
        self.subprocess_mock.return_value = subprocess.CompletedProcess([], 1, '', 'Failed to connect to bus')
        self.checker.services()
        self.assertEqual(self.checker.finish(), 0)
        self.assertEqual(self.checker.finish(strict=True), 1)
        self.checker.results.clear()
        self.subprocess_mock.return_value = subprocess.CompletedProcess([], 0, 'example.service loaded failed failed Example\n', '')
        self.checker.services()
        self.assertEqual(self.checker.finish(), 1)
        args = self.subprocess_mock.call_args.args[0]
        self.assertIn('--user', args)
        self.assertIn('--failed', args)
        self.assertIn('--type=service', args)
        self.assertNotIn('restart', args)

    def test_no_failed_services_is_ok(self):
        self.executable('systemctl')
        self.checker.services()
        self.assertEqual(self.checker.results, [('OK', 'No failed systemd --user services')])

    def test_safe_tests_use_only_allowlist_in_temporary_homes(self):
        self.executable('nvim')
        root = self.checker.config / 'nvim'
        (root / 'tests').mkdir(parents=True)
        for name in (*doctor.SAFE_TESTS, 'provision.py', 'unsafe.lua'):
            (root / 'tests' / name).write_text('')
        self.checker.tests()
        self.assertEqual(self.subprocess_mock.call_count, 3)
        for call, name in zip(self.subprocess_mock.call_args_list, doctor.SAFE_TESTS):
            self.assertEqual(call.args[0][-1], str(root / 'tests' / name))
            self.assertIn('--clean', call.args[0])
            self.assertEqual(call.kwargs['cwd'], root)
            self.assertEqual(call.kwargs['timeout'], 20)
            self.assertNotEqual(call.kwargs['env']['HOME'], str(self.home))
            self.assertFalse(Path(call.kwargs['env']['HOME']).exists())

    def test_missing_safe_tests_warn_and_failed_safe_tests_fail(self):
        self.executable('nvim')
        self.checker.tests()
        self.subprocess_mock.assert_not_called()
        self.assertEqual(len(self.checker.results), 3)
        self.assertEqual(self.checker.finish(), 0)
        test = self.checker.config / 'nvim/tests/health.lua'
        test.parent.mkdir(parents=True)
        test.write_text('')
        self.subprocess_mock.return_value = subprocess.CompletedProcess([], 1, '', 'assertion failed')
        self.checker.tests()
        self.assertIn(('FAIL', 'Safe test health.lua: assertion failed'), self.checker.results)

    def test_isolation_removes_startup_hooks_and_cleans_up(self):
        base = {**self.env, 'NVIM': 'socket', 'NVIM_APPNAME': 'other', 'LUA_INIT': 'do_bad_things()', 'VIMINIT': 'bad'}
        with doctor.isolated_environment(base) as env:
            for key in ('NVIM', 'LUA_INIT', 'VIMINIT'):
                self.assertNotIn(key, env)
            for key in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR', 'TMPDIR'):
                self.assertTrue(Path(env[key]).is_relative_to(env['HOME']))
                self.assertTrue(Path(env[key]).is_dir())
            self.assertEqual(env['NVIM_APPNAME'], 'nvim')
            temporary_home = Path(env['HOME'])
        self.assertFalse(temporary_home.exists())
        self.assertEqual(base['NVIM'], 'socket')

    def test_exit_status_and_summary(self):
        self.assertEqual(self.checker.finish(), 0)
        self.checker.report('WARN', 'optional missing')
        self.assertEqual(self.checker.finish(), 0)
        self.assertEqual(self.checker.finish(strict=True), 1)
        self.checker.report('FAIL', 'broken syntax')
        self.assertEqual(self.checker.finish(), 1)
        self.assertIn('Summary: 1 failure(s), 1 warning(s)', self.output.getvalue())

    def test_cli_help_and_safe_tests_are_opt_in(self):
        with patch.object(doctor, 'Doctor') as constructor:
            instance = constructor.return_value
            instance.finish.return_value = 0
            self.assertEqual(doctor.main([]), 0)
            instance.tests.assert_not_called()
            doctor.main(['--tests', '--strict'])
            instance.tests.assert_called_once()
            instance.finish.assert_called_with(True)
            with self.assertRaises(SystemExit) as result:
                doctor.main(['--help'])
            self.assertEqual(result.exception.code, 0)
            self.assertIn('--tests', self.output.getvalue())


if __name__ == '__main__':
    unittest.main()
