# Personal Ubuntu workstation

Ansible configuration for personal **Ubuntu 26.04 amd64** computers.

## Features

- Development tools: Git, Go, Neovim from the unstable PPA, fzf, fd-find,
  ripgrep, and Tree-sitter CLI installed with Cargo.
- tdf terminal PDF viewer, built from its upstream Git repository with Cargo.
- Kitty terminal and common GNOME desktop applications.
- Pi coding agent, ast-grep CLI, and five Pi extension packages:
  - `git:github.com/code-yeongyu/pi-ast-grep`
  - `npm:pi-web-access`
  - `git:github.com/samfoy/pi-lsp-extension`
  - `npm:pi-subagents`
  - `npm:pi-nvim`
- Docker Engine from Docker's official stable apt repository, with Compose
  and Buildx plugins.
- Mozilla's apt Firefox, replacing Firefox Snap.
- Upstream Syncthing stable-v2 and its per-user system service.
- Spotify, Claude Desktop, Zed, and Claude CLI.
- Full TeX Live and latexmk.

The bare Git repository at `~/.cfg` manages dotfiles. Ansible manages software,
apt sources, and system services. Bootstrap installs prerequisites and checks out
dotfiles; it does not apply the playbook.

Credentials, SSH keys, conversation history, browser profiles, Syncthing identities,
GNOME settings, container data, and project directories are not copied.
ROS, Bun, and hardware-specific tools are outside the scope of this configuration.

## Requirements

- Ubuntu 26.04 on amd64.
- A normal user with sudo access.
- Internet access to Ubuntu and vendor repositories, npm, and GitHub.
- Sufficient disk space for TeX Live, Docker, and their dependencies.

Other Ubuntu releases and architectures are rejected by the playbook.
Run Ansible as your normal user, not with `sudo ansible-playbook`.

## Bootstrap

Obtain `bootstrap.sh` from the
[dotfiles repository](https://github.com/rezenders/dotfiles) and run:

```bash
bash bootstrap.sh
```

If the dotfiles are already checked out, the wrapper is also available:

```bash
bash ~/setup_ubuntu.sh
```

Bootstrap uses sudo to install Git and ansible-core, then clones the public
dotfiles repository over HTTPS. Set `DOTFILES_URL` to use another repository;
private repositories require authentication.

Checkout never uses `--force`. If existing files conflict, back them up and retry:

```bash
git --git-dir="$HOME/.cfg" --work-tree="$HOME" checkout
```

An existing `~/.cfg` is left untouched: bootstrap does not automatically pull or
check it out. Shell aliases are not configured by bootstrap. The repository hides
untracked home files from status; explicit `config add PATH` still works.

## Configure

Edit `vars.yml` or supply Ansible extra variables.

| Variable | Default | Purpose |
| --- | --- | --- |
| `install_latex` | `true` | Install the TeX Live package set |
| `install_personal_apps` | `true` | Install Spotify, Claude Desktop, Zed, and Claude CLI |
| `enable_syncthing` | `true` | Install Syncthing and enable its service |
| `install_tdf` | `true` | Build and install the tdf terminal PDF viewer with Cargo |
| `install_pi` | `true` | Install Node.js, npm, Pi, ast-grep, and Pi extensions |
| `install_docker` | `true` | Install Docker CE and enable its system service |
| `docker_add_user_to_group` | `false` | Grant the invoking user root-equivalent Docker access |
| `package_state` | `latest` | Upgrade managed apt packages; use `present` for missing packages only |
| `update_vendor_apps` | `false` | Rerun Zed and Claude CLI installers |
| `update_pi` | `false` | Reinstall/update the managed Pi and ast-grep npm packages |
| `update_pi_extensions` | `false` | Reconcile/update all declared personal Pi packages |

Kitty, fzf, fd-find, and ripgrep are part of the base desktop/development package
lists. Neovim's fzf-lua pickers require `fzf`; `ripgrep` supplies `rg` for live grep
and the configuration-file picker. `fd-find` is an optional faster file finder;
Ubuntu names its binary `fdfind`, which fzf-lua detects automatically. The default
Neovim previewer does not require `bat`.
Disabling an option skips management; it does not uninstall software, remove
repositories, revoke existing Docker group membership, or stop existing services.
Removing entries from package lists does not uninstall them.

Example without LaTeX or personal applications:

```bash
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --ask-become-pass -e '{"install_latex": false, "install_personal_apps": false}'
```

## Preview and apply

```bash
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, --syntax-check

ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --ask-become-pass --check --diff

ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --ask-become-pass
```

Check mode cannot fully simulate a fresh installation. New apt sources cannot be
refreshed, so their packages may not be found. npm installations, Pi package
commands, vendor installers, and service changes are skipped. Pi setup is deferred
when Node.js or npm is absent. Diffs can expose configuration; do not publish
sensitive output.

Task tags are `repositories`, `packages`, `applications`, `tree_sitter`, `tdf`, `pi`,
`docker`, and `services`. Docker requires its apt source to be configured first:

```bash
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --ask-become-pass --tags repositories,docker

ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --ask-become-pass --tags pi
```

## Tree-sitter CLI

The `tree_sitter` tasks install Ubuntu's Cargo and native build tools, then run
`cargo install --locked tree-sitter-cli` as the normal user. The CLI is installed
under `~/.cargo/bin` and skipped if `~/.cargo/bin/tree-sitter` already exists.
An existing Cargo installation in `~/.cargo/bin` takes precedence over system Cargo.
The Cargo installation step is skipped in check mode.

The playbook adds this line to `~/.profile` for future login shells. To use the CLI
in your current shell immediately, also run:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
tree-sitter --version
```

Shells that do not read `~/.profile` need the same export in their startup file.
To install just these tools:

```bash
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --ask-become-pass --tags tree_sitter
```

`--locked` uses the crate's lockfile but does not pin the CLI release. Existing
installations are not automatically upgraded; rerun the Cargo install command
manually to request an update.

## tdf terminal PDF viewer

The `tdf` tasks install Git, curl, CA certificates, build-essential, Clang,
Fontconfig development headers, and pkg-config. Ubuntu's apt Rust/Cargo may be
older than tdf requires, so these tasks install rustup as the normal user when
missing and update its stable toolchain before building a missing tdf binary.
The build explicitly runs `~/.cargo/bin/cargo +stable install --git
https://github.com/itsjunetime/tdf.git`, avoiding system Cargo and any older
default toolchain. Existing rustup defaults are not changed.

The rustup installer is downloaded from `https://sh.rustup.rs` and cached under
`~/.cache/workstation/installers`; it runs without sudo.

The binary is installed under `~/.cargo/bin`, which is added to `~/.profile`.
For the current shell, run `export PATH="$HOME/.cargo/bin:$PATH"`.
Installation is skipped if `~/.cargo/bin/tdf` exists, and in check mode.

```bash
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --ask-become-pass --tags tdf
```

The Git source is unpinned and builds third-party code. Existing installations
are not automatically upgraded. To update manually, run `rustup update stable`
and `cargo +stable install --git https://github.com/itsjunetime/tdf.git`.

## Pi and extensions

Pi and ast-grep are installed as the normal user with npm under `~/.local`.
The playbook installs Ubuntu's Node.js and npm and requires Node.js 22.19 or newer.
It uses explicit system executable paths rather than loading an interactive NVM
environment. Override `pi_node_executable` and `pi_npm_executable` if needed.

Add `~/.local/bin` to your shell's `PATH`, ahead of other Pi installations:

```bash
export PATH="$HOME/.local/bin:$PATH"
pi --version
ast-grep --version
rg --version
```

Existing NVM, Snap, or manually installed tools are not removed. The managed
installation may coexist with them. On Linux, use `ast-grep` rather than `sg`,
which is also the name of an unrelated system command.

Extension sources are declared in `pi_packages`. Missing declarations are added
using `pi install`, preserving other settings and packages in
`~/.pi/agent/settings.json`. Existing declarations are reconciled when Pi is
first installed by the playbook or when `update_pi_extensions=true`.
Pi commands use the personal `~/.pi/agent` directory, not project-local settings.

Pi and ast-grep install only when missing unless `update_pi=true`.
For version pinning, set `pi_npm_package` or `ast_grep_npm_package` to an npm
specification with a version, and use versioned npm sources or Git refs in
`pi_packages`. Changing an already installed CLI specification requires an
explicit update. Defaults are unpinned.

Pi authentication is configured separately through `/login` or provider API keys.
Language servers used by the LSP extension must be installed separately.
No credentials or session data are managed by this playbook.

## Docker

The playbook installs `docker-ce`, `docker-ce-cli`, `containerd.io`,
`docker-buildx-plugin`, and `docker-compose-plugin`. It enables and starts
`docker.service` without changing daemon settings or managing containers.

Existing distro Docker/containerd packages cause a failure with migration
instructions instead of being automatically removed. Other custom Docker apt
source definitions may require manual reconciliation.

By default, use Docker with sudo. To grant your user access:

```bash
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --ask-become-pass --tags repositories,docker -e docker_add_user_to_group=true
```

**Docker group membership is root-equivalent.** Log out and back in after adding
the group. Docker-published container ports can bypass UFW rules; review
[Docker's firewall documentation](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
before exposing services.

Verify the installation:

```bash
sudo docker version
sudo docker compose version
sudo docker buildx version
# Optional: downloads and runs a test container.
sudo docker run --rm hello-world
```

## Updates

With the `config` alias configured for the dotfiles repository:

```bash
config status
# Resolve local changes before pulling.
config pull --ff-only
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, --ask-become-pass
```

Only managed apt packages are upgraded, although dependencies may also change.
Normal Ubuntu system updates remain separate. Docker upgrades may restart its
daemon and affect running containers.

To update Pi, ast-grep, and all declared Pi packages explicitly:

```bash
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --ask-become-pass --tags pi -e update_pi=true -e update_pi_extensions=true
```

To rerun the Zed and Claude CLI installers:

```bash
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
  --tags applications -e update_vendor_apps=true
```

Vendor installers run as the normal user and are cached under
`~/.cache/workstation/installers`. They are not pinned or sandboxed.
Pi extensions and npm lifecycle scripts also execute third-party code;
review package sources before installing.

## Service and repository behavior

- Known apt source files are managed and may be overwritten; unrelated sources
  are left alone.
- Firefox's apt replacement is installed before removing its Snap. Browser
  profile migration is not automated.
- Syncthing runs as `syncthing@YOUR_USER.service`. Pair devices separately and do
  not run another Syncthing instance on the same data.

## Tests

```bash
bash -n ~/setup_ubuntu.sh ~/.config/workstation/bootstrap.sh
python3 -m unittest discover -s ~/.config/workstation/tests -v
ansible-playbook ~/.config/workstation/workstation.yml -i localhost, --syntax-check
```

Tests use temporary homes and stub privileged operations and package commands.
The Pi task tests require `ansible-playbook` on `PATH`. A disposable Ubuntu VM
is recommended for end-to-end installation testing.
