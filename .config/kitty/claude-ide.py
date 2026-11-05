#!/usr/bin/env python3
"""Start `claude` connected to the Neovim (claudecode.nvim) in the same kitty tab.

Lookup order:
  1. A Neovim running in a window of the current kitty tab.
  2. A Neovim whose workspace folder contains the current directory.
  3. The most recently started Neovim.
If none is found, fall back to plain `claude --ide`.
"""
import json
import os
import subprocess
from pathlib import Path

LOCK_DIR = Path.home() / ".claude" / "ide"


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except (OSError, TypeError):
        return False


def ppid(pid):
    try:
        stat = Path(f"/proc/{pid}/stat").read_text()
        return int(stat.rsplit(")", 1)[1].split()[1])
    except (OSError, ValueError, IndexError):
        return None


def ancestors(pid):
    """pid and its parents (claudecode lockfile pid is `nvim --embed`)."""
    seen = []
    while pid and pid > 1 and len(seen) < 16:
        seen.append(pid)
        pid = ppid(pid)
    return seen


def neovim_locks():
    locks = []
    for f in LOCK_DIR.glob("*.lock"):
        try:
            data = json.loads(f.read_text())
            port = int(f.stem)
        except (OSError, ValueError):
            continue
        if data.get("ideName") == "Neovim" and alive(data.get("pid")):
            locks.append((f.stat().st_mtime, port, data))
    return sorted(locks, key=lambda x: x[0], reverse=True)


def current_tab_pids():
    """Foreground process pids in the kitty tab containing this window."""
    me = os.environ.get("KITTY_WINDOW_ID")
    if not me:
        return set()
    try:
        out = subprocess.run(["kitten", "@", "ls"], capture_output=True, text=True, timeout=3).stdout
        os_windows = json.loads(out)
    except Exception:
        return set()
    for osw in os_windows:
        for tab in osw.get("tabs", []):
            windows = tab.get("windows", [])
            if any(str(w.get("id")) == me for w in windows):
                return {p["pid"] for w in windows for p in w.get("foreground_processes", [])}
    return set()


def pick_port(locks):
    if not locks:
        return None
    tab_pids = current_tab_pids()
    for _, port, data in locks:
        if tab_pids & set(ancestors(data["pid"])):
            return port
    cwd = os.path.realpath(os.getcwd())
    for _, port, data in locks:
        for ws in data.get("workspaceFolders", []):
            ws = os.path.realpath(ws)
            if cwd == ws or cwd.startswith(ws + os.sep):
                return port
    return locks[0][1]


port = pick_port(neovim_locks())
if port:
    os.environ["CLAUDE_CODE_SSE_PORT"] = str(port)
    os.environ["ENABLE_IDE_INTEGRATION"] = "true"
    os.execvp("claude", ["claude"])
os.execvp("claude", ["claude", "--ide"])
