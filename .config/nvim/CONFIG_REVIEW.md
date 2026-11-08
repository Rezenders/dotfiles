# Neovim configuration review

**Overall:** this is a coherent, well-customized configuration—not just an accumulation of plugins. The load-order-sensitive LaTeX integration is organized sensibly, the custom code has meaningful regression tests, and the configuration compiles successfully under your installed Neovim 0.13-dev.

The remaining findings concern **credential handling in the Pi dock launcher, startup/subprocess robustness, and configuration maintenance**. Resolved findings have been removed.

The original review did not modify the configuration or update/install plugins. This document now lists only outstanding findings.

## Original review verification

| Check | Result |
|---|---|
| Compile all 16 Lua files using Neovim’s Lua compiler | Passed |
| Parse the custom Lua Tree-sitter textobjects query | Passed |
| `tests/line_length.lua` | Passed |
| `tests/ltex_extra.lua` | Passed |
| `tests/kitty_dock_toggle.py` | Passed |
| JavaScript syntax check for `markdown_line_length.cjs` | Passed |
| StyLua check | Style differences in all 16 Lua files under the formatter’s defaults |

I also inspected relevant **locally installed plugin and Neovim implementations**, rather than assuming older API behavior.

**Limitations:** I did not perform a full interactive startup, launch real language servers/debuggers, compile LaTeX, or manipulate your live Kitty windows. Type-aware LSP validation was unavailable; the diagnostic tool’s fallback parser reported opening-line errors inconsistent with successful compilation by Neovim itself, so I did not treat those as genuine Lua syntax failures.

---

# 1. Findings to prioritize

## 1.1 High: the Pi launcher writes your full environment to a predictable temporary file

**Location:** `init.lua:1105–1127`

`make_dock_launcher()` writes a script such as:

```text
/tmp/nvim-dock-3-pi.sh
```

It exports almost every environment variable, then makes the script owner-only **after writing it**.

### Why this matters

- Environment variables can contain API keys, access tokens, and other credentials.
- `io.open(..., 'w')` creates the file using normal creation permissions before the later `setfperm()`.
- The shell used for my checks had `umask 0002`, which permits a newly created ordinary file to be readable by other users until permissions are tightened.
- The filename is predictable, and ordinary `io.open()` does not provide exclusive, no-follow creation. The practical consequences depend on OS temporary-file protections.
- There is no cleanup of these environment snapshots.
- The executable path interpolated into `exec %s "$@"` is not shell-quoted, so a path containing spaces or shell metacharacters would break.

An existing launcher file was owner-only, which is good, but that does not fix first-creation behavior or persistence.

### Recommendation

Prefer passing only the necessary environment variables through the dock-launch mechanism. If a script remains necessary:

- Create it securely in a private directory, with restrictive permissions **at creation**.
- Use an unpredictable name and exclusive creation.
- Shell-quote the executable.
- Remove it when no longer needed.

This is the highest-priority improvement because it concerns credential handling, not just editor behavior.

---

# 2. Robustness and portability

## 2.1 Desktop appearance detection can block or abort startup

**Location:** `init.lua:383–390`

The theme detector launches `gdbus` synchronously and waits without a timeout.

You correctly handle a nonzero exit status, but:

- A missing executable can cause process creation to throw before an exit code exists.
- An unresponsive desktop portal can delay startup.
- Every editor instance pays for the query, including instances where desktop appearance is irrelevant.

`gdbus` is installed here, so I am not claiming this currently breaks your machine.

**Improvement:** use an executable check, protected process creation, a bounded timeout, and a fallback theme. An asynchronous query is another option.

## 2.2 The local Pi checkout is a hard startup dependency

**Location:** `init.lua:1275–1279`

The checkout exists on this machine, but an unavailable or incompatible `~/git/pi-nvim` causes an unconditional `require()` failure.

Using a development fork is reasonable. The improvement is to let the optional integration fail without interrupting later setup, and to document or preserve the fork revision needed to reproduce the configuration.

## 2.3 Dock subprocess failures can leave a toggle permanently busy

**Location:** `init.lua:1139–1152`

`dock_busy[kind]` is cleared for normal subprocess failures, but not if `vim.system()` itself throws—for example, if `kitten` cannot be spawned.

That dock kind then remains busy for the rest of the session.

**Improvement:** protect process creation and clear the busy state on every failure path. A timeout would also prevent a hung remote-control command from blocking future toggles indefinitely.

# 3. Possible improvements

## 3.1 Markdown formatting and lint policy can disagree

**Locations:**

- Formatting policy: `init.lua:794`
- Dynamic lint-policy guide: `lua/custom/line_length.lua`

The guide follows project MD013 settings, but Prettier is explicitly forced to wrap at 80 columns.

That can be intentional. However:

- A project limit below 80 can produce formatting that still violates MD013.
- A project limit above 80 gets narrower wrapping than its policy requires.
- The formatter’s CLI arguments override project Prettier settings.

Consider either respecting project formatting configuration or clearly treating 80-column formatting as your personal override.

## 3.2 Choose one devicons provider

**Locations:** `init.lua:491`, `init.lua:984`

You install and mock `nvim-web-devicons` through `mini.icons`, then also explicitly add the real `nvim-web-devicons` plugin.

This is redundant rather than a confirmed failure.

Choose either the MiniIcons compatibility layer or the real provider to simplify ownership and debugging. Choose real provider if possible.

## 3.3 Define your StyLua style explicitly

StyLua’s default check reports changes in every Lua file. The configuration mixes indentation, quoting, and layout conventions, and has no local StyLua configuration.

This is not a correctness problem, but enabling routine formatting could create large, distracting diffs.

Add an explicit formatter configuration matching your intended style before performing a broad formatting pass.

## 3.4 Trim the lockfile’s historical plugin inventory

`nvim-pack-lock.json` still contains plugins no longer requested by the active configuration, including Telescope components, several themes, the packaged Pi plugin, and `yazi.nvim`.

These entries do **not** imply that all those plugins are currently loaded. However, your installed `vim.pack` synchronizes plugins recorded in the lockfile, including installing missing entries on a fresh machine.

Reviewing inactive entries would make clean-machine reproduction leaner and more representative of the active setup.

## 3.5 Expand the health check

**Location:** `lua/kickstart/health.lua`

The check currently covers a minimum Neovim version and a few basic executables. Your actual environment depends on considerably more.

Useful additions would include:

- `fzf`, Node, and the Markdown tools.
- ImageMagick.
- Kitty/`kitten` and remote-control availability.
- LaTeX utilities and Zathura.
- The local Pi checkout.
- Executables for configured language servers.

This would turn environment failures into actionable warnings instead of later surprises.

---

# 4. What is already good

Several choices are worth preserving:

- **Correct attention to load order:** LaTeX servers, completion compatibility, Blink, LuaSnip, and VimTeX are connected at sensible points.
- **Modern Neovim APIs:** `vim.pack`, `vim.lsp.config`, `vim.lsp.enable`, and `vim.system` fit the installed version.
- **Useful regression tests:** the existing suites cover real historical failure modes, not merely module loading.
- **Conservative Markdown policy resolution:** the JavaScript helper closely follows the installed CLI’s configuration-reading behavior.
- **Appropriate formatting separation:** manual Markdown formatting and TexLab-filtered LaTeX formatting avoid competing formatters.
- **Whitespace exclusions:** excluding Markdown, diffs, and commit messages avoids common save-hook damage.
- **Remote image downloads disabled:** a sensible default.
- **Scoped sections and extracted custom modules:** the large `init.lua` is still navigable; no wholesale rewrite is necessary.
- **Compatibility fixes kept outside plugin checkouts:** this improves reproducibility and makes updates easier to reason about.

One additional caution: generic trailing-whitespace removal can still change meaningful content inside multiline strings, templates, or LaTeX verbatim environments. A per-buffer opt-out would make this behavior safer without abandoning it.

---

# Recommended order of work

1. **Secure the Pi launcher’s temporary environment script.**
2. Improve startup/subprocess failure handling.
3. Make the local Pi integration optional when its checkout is unavailable.
4. Choose a single devicons provider.
5. Clarify Markdown formatting policy, define formatter style, trim historical lockfile entries, and expand the health check.

**Bottom line:** the configuration’s foundation is sound. The best next step is not adding more plugins or reorganizing everything—it is securing the launcher, hardening failure handling, and simplifying configuration ownership.
