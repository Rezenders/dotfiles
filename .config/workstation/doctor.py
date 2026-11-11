#!/usr/bin/env python3
"""Read-only workstation checks; never source the normal Neovim configuration."""
import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


# Keep these aligned with nvim/init.lua and lua/custom/latex/lsp.lua. Resolve
# commands without loading plugins (which could install packages or use network).
LANGUAGE_SERVERS = {
    'clangd': 'clangd', 'cmake': '~/.local/bin/cmake-language-server',
    'pyright': 'pyright-langserver', 'marksman': 'marksman',
    'bashls': 'bash-language-server', 'jsonls': 'vscode-json-language-server',
    'yamlls': 'yaml-language-server', 'ansiblels': 'ansible-language-server',
    'docker_compose_language_service': 'docker-compose-langserver',
    'ruff': 'ruff', 'dockerls': 'docker-langserver', 'stylua': 'stylua',
    'lua_ls': 'lua-language-server', 'texlab': 'texlab',
    'ltex_plus': 'ltex-ls-plus',
}
REQUIRED_TOOLS = ('kitty', 'nvim', 'node', 'pi', 'git', 'make', 'unzip', 'rg', 'cc', 'fzf', 'npm')
OPTIONAL_TOOLS = (
    'fd|fdfind', 'tree-sitter', 'prettier', 'markdownlint', 'magick', 'kitten',
    'yazi', 'zoxide', 'tdf', 'claude', 'ast-grep', 'betterleaks', 'go', 'dlv',
    'file', 'ffmpeg', '7z|7zz', 'jq', 'pdftoppm', 'resvg', 'wl-copy', 'xclip',
    # Workflow-specific, never required (including on work machines).
    'latexmk', 'pdflatex', 'chktex', 'latexindent', 'zathura',
)
SAFE_TESTS = ('health.lua', 'runtime.lua', 'file_autocmds.lua')

KITTY_CHECK = '''
import json, sys
from kitty.config import load_config
bad = []
options = load_config(sys.argv[1], accumulate_bad_lines=bad)
print('WORKSTATION_KITTY=' + json.dumps({
    'font': str(options.font_family),
    'bad_lines': [str(line) for line in bad],
}))
raise SystemExit(bool(bad))
'''
LUA_CHECK = '''
local files = vim.json.decode(vim.env.WORKSTATION_LUA_FILES)
for _, path in ipairs(files) do
  local chunk, err = loadfile(path)
  if not chunk then io.stderr:write(err .. '\\n'); vim.cmd('cquit 1'); return end
end
print('Lua syntax OK: ' .. #files .. ' files (not executed)')
vim.cmd('qa!')
'''


def executable_paths(name, path):
    """Keep distinct PATH spellings, including symlinks to the same target."""
    found = []
    for directory in path.split(os.pathsep):
        candidate = Path(os.path.abspath(os.path.join(directory or '.', name)))
        if candidate.is_file() and os.access(candidate, os.X_OK) and candidate not in found:
            found.append(candidate)
    return found


@contextmanager
def isolated_environment(base):
    """Confine Neovim state, test-created files, and caches to a disposable home."""
    with tempfile.TemporaryDirectory(prefix='workstation-doctor-') as directory:
        env = dict(base)
        env['HOME'] = directory
        for key, child in (('XDG_CONFIG_HOME', 'config'), ('XDG_DATA_HOME', 'data'),
                           ('XDG_STATE_HOME', 'state'), ('XDG_CACHE_HOME', 'cache'),
                           ('XDG_RUNTIME_DIR', 'run'), ('TMPDIR', 'tmp')):
            target = Path(directory) / child
            target.mkdir(mode=0o700)
            env[key] = str(target)
        for key in ('NVIM', 'VIMINIT', 'EXINIT', 'LUA_INIT', 'LUA_PATH', 'LUA_CPATH'):
            env.pop(key, None)
        env['NVIM_APPNAME'] = 'nvim'
        env['PYTHONDONTWRITEBYTECODE'] = '1'
        yield env


class Doctor:
    def __init__(self, home=None, env=None):
        self.env = dict(os.environ if env is None else env)
        self.home = Path(home if home is not None else self.env.get('HOME', str(Path.home())))
        self.config = Path(self.env.get('XDG_CONFIG_HOME', str(self.home / '.config')))
        self.data = Path(self.env.get('XDG_DATA_HOME', str(self.home / '.local/share')))
        self.mason = self.data / 'nvim/mason/bin'
        self.results = []

    def report(self, level, message):
        self.results.append((level, message))
        print(f'{level}: {message}')

    def run(self, args, *, env=None, cwd=None, timeout=10):
        try:
            return subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                                  env=self.env if env is None else env, cwd=cwd,
                                  errors='replace')
        except (OSError, subprocess.TimeoutExpired) as error:
            return subprocess.CompletedProcess(args, 124, '', str(error))

    def find(self, name, mason=False):
        if name.startswith('~/'):
            candidate = self.home / name[2:]
            return candidate if candidate.is_file() and os.access(candidate, os.X_OK) else None
        for alternative in name.split('|'):
            matches = executable_paths(alternative, self.env.get('PATH', os.defpath))
            if matches:
                return matches[0]
            candidate = self.mason / alternative
            if mason and candidate.is_file() and os.access(candidate, os.X_OK):
                return candidate
        return None

    def tools(self):
        print('\nExecutable selection (required core; optional workflow tools and servers)')
        for name in REQUIRED_TOOLS:
            selected = self.find(name)
            if selected:
                self.report('OK', f'required {name}: {selected} -> {selected.resolve()}')
                if name in ('kitty', 'nvim', 'node', 'pi'):
                    for shadowed in executable_paths(name, self.env.get('PATH', os.defpath))[1:]:
                        self.report('INFO', f'{name} shadowed: {shadowed} -> {shadowed.resolve()}')
            else:
                self.report('FAIL', f'required {name}: not found on PATH')
        for name in OPTIONAL_TOOLS:
            selected = self.find(name, mason=True)
            self.report('OK' if selected else 'WARN',
                        f'optional {name}: {selected or "not found (PATH or Mason)"}')
        for server, command in LANGUAGE_SERVERS.items():
            selected = self.find(command, mason=True)
            self.report('OK' if selected else 'WARN',
                        f'optional LSP {server} ({command}): {selected or "not found (PATH or Mason)"}')

    @staticmethod
    def detail(result):
        return (result.stderr.strip() or result.stdout.strip() or f'exit {result.returncode}')[:3000]

    def configs(self):
        print('\nConfiguration syntax (no normal Neovim startup)')
        kitty_config = self.config / 'kitty/kitty.conf'
        font = None
        kitty = self.find('kitty')
        if not kitty_config.is_file():
            self.report('FAIL', f'missing Kitty config: {kitty_config}')
        elif not kitty:
            self.report('WARN', 'Kitty syntax skipped: kitty unavailable')
        else:
            result = self.run([str(kitty), '+runpy', KITTY_CHECK, str(kitty_config)],
                              env={**self.env, 'PYTHONDONTWRITEBYTECODE': '1'})
            try:
                line = next(line for line in result.stdout.splitlines() if line.startswith('WORKSTATION_KITTY='))
                payload = json.loads(line.split('=', 1)[1])
                font = payload['font']
                if payload['bad_lines']:
                    self.report('FAIL', 'Kitty invalid config lines: ' + '; '.join(payload['bad_lines']))
                elif result.returncode:
                    self.report('FAIL', 'Kitty parser: ' + self.detail(result))
                else:
                    self.report('OK', f'Kitty load_config: {kitty_config}; configured font: {font}')
            except (StopIteration, KeyError, ValueError, TypeError):
                self.report('FAIL', 'Kitty parser: ' + self.detail(result))
        tab_bar = self.config / 'kitty/tab_bar.py'
        try:
            compile(tab_bar.read_bytes(), str(tab_bar), 'exec')
            self.report('OK', 'Kitty tab_bar.py compiles (not executed; no bytecode written)')
        except (OSError, SyntaxError, ValueError) as error:
            self.report('FAIL', f'Kitty tab_bar.py: {error}')
        nvim_root = self.config / 'nvim'
        init = nvim_root / 'init.lua'
        files = [init]
        for subdirectory in ('lua', 'after'):
            files.extend(sorted((nvim_root / subdirectory).rglob('*.lua')))
        nvim = self.find('nvim')
        if not init.is_file():
            self.report('FAIL', f'missing Neovim init: {init}')
        elif not nvim:
            self.report('WARN', 'Lua syntax skipped: nvim unavailable')
        else:
            with isolated_environment(self.env) as env:
                env['WORKSTATION_LUA_FILES'] = json.dumps([str(file) for file in files])
                result = self.run([str(nvim), '--headless', '--clean', '-n', '-i', 'NONE',
                                   '--cmd', 'lua ' + LUA_CHECK], env=env)
            self.report('FAIL' if result.returncode else 'OK', 'Neovim loadfile: ' + self.detail(result))
        return font

    def fonts(self, configured_font):
        fc_list = self.find('fc-list')
        if not fc_list:
            self.report('WARN', 'Font availability skipped: fc-list missing')
            return
        result = self.run([str(fc_list), '--format=%{family}\\n'])
        if result.returncode:
            self.report('WARN', 'Font query: ' + self.detail(result))
            return
        families = {family.strip() for line in result.stdout.splitlines() for family in line.split(',')}
        nerd = sorted(family for family in families if 'nerd' in family.lower())
        self.report('OK' if nerd else 'WARN', 'Nerd Fonts: ' + (', '.join(nerd) or 'none found'))
        if not configured_font:
            self.report('WARN', 'Kitty configured font availability unknown (parser did not return a font)')
            return
        # Kitty 0.40+ returns a FontSpec string; older releases return the family.
        match = re.search(r'family=[\"\']([^\"\']+)[\"\']', configured_font)
        family = match.group(1) if match else configured_font
        if family == 'auto':
            self.report('INFO', 'Kitty font is auto; Fontconfig selects the monospace default')
        else:
            present = family.casefold() in {item.casefold() for item in families}
            self.report('OK' if present else 'WARN',
                        f'Kitty font family {family}: {"installed" if present else "not found; fallback may be used"}')

    def services(self):
        systemctl = self.find('systemctl')
        if not systemctl:
            self.report('WARN', 'User services skipped: systemctl unavailable')
            return
        result = self.run([str(systemctl), '--user', '--failed', '--type=service',
                           '--no-legend', '--plain', '--no-pager'],
                          env={**self.env, 'SYSTEMD_COLORS': '0', 'SYSTEMD_PAGER': 'cat'})
        if result.returncode:
            self.report('WARN', 'User services unavailable (user bus/session may be absent): ' + self.detail(result))
        elif result.stdout.strip():
            self.report('FAIL', 'Failed systemd --user services:\n' + result.stdout.strip())
        else:
            self.report('OK', 'No failed systemd --user services')

    def tests(self):
        """Explicit allowlist only: workstation provisioning tests are not safe here."""
        nvim = self.find('nvim')
        if not nvim:
            self.report('WARN', 'Safe tests skipped: nvim unavailable')
            return
        root = self.config / 'nvim'
        for name in SAFE_TESTS:
            script = root / 'tests' / name
            if not script.is_file():
                self.report('WARN', f'Safe test missing: {script}')
                continue
            with isolated_environment(self.env) as env:
                result = self.run([str(nvim), '--clean', '--headless', '-n', '-i', 'NONE',
                                   '-l', str(script)], env=env, cwd=root, timeout=20)
            self.report('FAIL' if result.returncode else 'OK', f'Safe test {name}: ' + self.detail(result))

    def finish(self, strict=False):
        failures = sum(level == 'FAIL' for level, _ in self.results)
        warnings = sum(level == 'WARN' for level, _ in self.results)
        print(f'\nSummary: {failures} failure(s), {warnings} warning(s)' + (' (strict)' if strict else ''))
        return int(bool(failures or (strict and warnings)))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--strict', action='store_true', help='exit nonzero for warnings as well as failures')
    parser.add_argument('--tests', action='store_true', help='also run only safe Neovim health/runtime/file-autocmd tests in temporary homes')
    args = parser.parse_args(argv)
    doctor = Doctor()
    doctor.tools()
    doctor.fonts(doctor.configs())
    doctor.services()
    if args.tests:
        doctor.tests()
    return doctor.finish(args.strict)


if __name__ == '__main__':
    raise SystemExit(main())
