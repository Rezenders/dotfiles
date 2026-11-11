 ### 2. File-aware opening actions — useful for
 development logs

 Their open-actions.conf opens:

 - Text files in Neovim.
 - Images in a Kitty image overlay.
 - Directories in a new terminal.
 - Log files with tail -f.

 For you, I’d extend this concept to open
 path/to/file.cpp:42 references directly in Neovim at
 the indicated line. Your Kitty config already contains
 documentation for this, but it isn’t enabled.

 That could be especially useful for compiler errors
 and Python tracebacks. We should implement it with
 proper path quoting rather than copy their macOS/Zsh
 commands.

 Source: config/kitty/open-actions.conf

 ### 3. Named project sessions — optional

 A Kitty session can launch a repeatable workspace:
 editor, shell, build terminal, and monitoring
 terminal, each in its project directory.

 This could suit your ROS workspaces. However, I would
 use Kitty’s supported session features rather than
 copy their sessioner.py: that script uses internal
 APIs, hardcodes an fzf path, and closes the current OS
 window during switching.

 Keep your existing scrollback and pane navigation.
 Your kitty-scrollback.nvim integration and
 Neovim-aware navigation already cover those needs
 well.



 Neovim

 Your setup already has substantial functionality:
 vim.pack, fzf-lua, native LSP, completion, formatting,
 debugging, Gitsigns, Diffview, and Kitty integration.
 These are the additions with the clearest benefit:

 ┌─────────────────┬───────────────────────┬──────────┐
 │ Addition        │ Benefit for you       │ Priority │
 ├─────────────────┼───────────────────────┼──────────┤
 │ grug-far.nvim   │ Interactive           │ High     │
 │                 │ search-and-replace    │          │
 │                 │ across multiple files │          │
 ├─────────────────┼───────────────────────┼──────────┤
 │ Restore last    │ Reopen a file where   │ High; no │
 │ cursor position │ you last edited it    │ plugin   │
 │                 │                       │ needed   │
 ├─────────────────┼───────────────────────┼──────────┤
 │ Create missing  │ Save a new nested     │ Medium;  │
 │ parent          │ path without manually │ no       │
 │ directories on  │ creating directories  │ plugin   │
 │ save            │ first                 │ needed   │
 ├─────────────────┼───────────────────────┼──────────┤
 │ treesj          │ Toggle arguments,     │ Medium   │
 │                 │ lists, and objects    │          │
 │                 │ between single-line   │          │
 │                 │ and multiline forms   │          │
 ├─────────────────┼───────────────────────┼──────────┤
 │ Explicit        │ Restore Neovim tabs   │ Optional │
 │ project         │ and splits for a      │          │
 │ sessions        │ project               │          │
 └────────────

 ### 1. grug-far is the strongest addition

 You already have excellent searching through fzf-lua,
 but I found no equivalent multi-file replacement
 interface.

 This would help with renaming configuration keys,
 changing repeated LaTeX text, or updating identifiers
 across a project. It complements fzf-lua rather than
 replacing it.

 Source: lua/plugins/grug_far.lua

 ### 2. Two small autocmd improvements

 Their configuration restores the last editing position
 and offers to create missing parent directories when
 saving.

 Both can be added without another dependency. I’d
 adapt them carefully:

 - Cursor restoration should not override an explicit
   nvim file:line-style jump.
 - Directory creation should apply only to real file
   buffers, not plugin buffers or remote URIs.
 - Automated/headless saves should not encounter
   interactive prompts.

 Source: plugin/autocmds.lua

 ### 3. treesj for structured editing

 For example:

 ```lua
   some_function(first, second, third)
 ```

 could become:

 ```lua
   some_function(
     first,
     second,
     third
   )
 ```

 It is syntax-aware, unlike ordinary line joining. This
 is potentially useful for your Lua, Python, and other
 programming work—not a strong LaTeX recommendation.

 Their configuration has duplicate mappings and some
 personal JavaScript transformations, so I’d start with
 the plugin’s defaults.

 Source: lua/plugins/treesj.lua

 Compatibility note: their configuration uses
 lazy.nvim; yours uses vim.pack and targets Neovim
 development builds. These features need to be
 translated into your existing structure, not copied as
 Lazy plugin specifications.


 Workstation and shell

 ### 1. Enable shell-level fzf integration — easiest
 immediate win

 You already have fzf installed, but I found no
 initialization for its shell keybindings in the Bash
 startup files I inspected.

 That would give you:

 - Ctrl-R: fuzzy command-history search.
 - Ctrl-T: insert selected file paths into a command.
 - Alt-C: fuzzy directory selection.

 This is independent of fzf-lua inside Neovim. I would
 enable this before installing more shell tools.

 Their preview configuration has useful ideas, but
 depends on a custom preview command and macOS pbcopy,
 so it should not be copied unchanged.

 Sources: config/fzf/fzfrc, config/zsh/zshrc

 ### 3. Atuin for richer history — optional upgrade
 after fzf

 Their Atuin configuration provides persistent,
 searchable history scoped to the current Git
 workspace.

 Your Bash configuration currently sets:

 ```bash
   HISTSIZE=1000
   HISTFILESIZE=2000
 ```

 Atuin would be useful for recovering commands from
 older ROS, Docker, and LaTeX sessions. Their defaults
 are sensible: sync disabled, background update checks
 disabled, and secret filtering enabled.

 I’d retain local-only storage initially and consider
 making Enter select a command for review rather than
 immediately executing it. Secret filters reduce risk
 but cannot guarantee that sensitive commands won’t be
 stored.

 Source: config/atuin/config.toml

 ### 4. A few Git improvements — small, worthwhile
 changes

 Their Git configuration includes several options
 absent from your inspected global config:

 ```gitconfig
   [merge]
       conflictStyle = zdiff3

   [rerere]
       enabled = true

   [rebase]
       autoSquash = true
 ```

 - zdiff3: shows base-version context during conflict
   resolution.
 - rerere: remembers conflict resolutions for reuse.
 - autoSquash: recognizes fixup! commits during
   interactive rebasing.

 I’d initially leave rerere.autoupdate disabled so
 reused resolutions can be reviewed before staging.

 Delta is another useful optional addition for readable
 terminal diffs. Unlike their hardcoded dark-mode
 configuration, yours should accommodate your
 light/dark theme switching.

 Source: config/git/config



 ### 5. A workstation doctor command — good fit for
 your two-machine setup

 They expose a single health-check command. The
 implementation is macOS-specific, but the pattern fits
 your Ansible-managed workstation well.

 Your version could check:

 - Which kitty, nvim, node, and pi executables are
   actually selected.
 - Required external tools and language servers.
 - Nerd Font availability.
 - Failed user services.
 - Configuration parsing and selected existing tests.

 You already have provisioning and tests; this would
 add a convenient check of the running machine,
 especially where NVM, system packages, and manually
 installed tools coexist.

 Source: mise/scripts/check-system



