# Personal Ubuntu workstation

Ansible configuration for personal **Ubuntu 26.04 amd64** computers.
The current machine reports 26.04.1 LTS / resolute, not 26.06.
Other releases and ARM computers are intentionally rejected for now
(Spotify's apt repository does not provide an ARM64 client).

## Ownership

- The existing bare Git repository at ~/.cfg manages dotfiles.
- Ansible manages packages, apt repositories and the Syncthing service.
- Bootstrap installs prerequisites and checks out a new dotfiles clone.
- No secrets, SSH keys, Syncthing identities, browser profiles, GNOME settings,
  project directories or personal data are copied.
- No background synchronization or unattended system changes are configured.

## First review

Read vars.yml and the task files. Defaults include:
- Neovim unstable PPA.
- Upstream Syncthing stable-v2 (matches the existing machine).
- Mozilla's apt Firefox, replacing Firefox Snap.
- Spotify and Claude Desktop upstream apt sources.
- Zed and Claude CLI vendor installers, run WITHOUT sudo.
- Full TeX Live plus latexmk. This is a large download and disk allocation.
- Packages are upgraded to the latest candidate from the configured apt sources.

gnome-browser-connector replaces the obsolete chrome-gnome-shell package.
Repositories and keys are downloaded over HTTPS; apt verifies repository signatures.
Vendor shell installers are not pinned or sandboxed. Review their downloaded scripts
under ~/.cache/workstation/installers if that trust model is unsuitable.

This is not a complete inventory of the existing machine: Docker, ROS, Kitty,
Node/Bun, pi, and hardware-specific tools are not installed by this first version.
Existing unrelated apt sources are left alone.

## Bootstrap a new machine

First commit and push these files using your existing config Git workflow.
The bootstrap cannot retrieve uncommitted local files from another computer.

Obtain bootstrap.sh from that repository and run it as your normal user:

    bash bootstrap.sh

Or, if the files are already present:

    bash ~/setup_ubuntu.sh

Bootstrap uses sudo to install git and ansible-core. It clones the public dotfiles
repository over HTTPS by default; override DOTFILES_URL for another repository.
A private repository requires authentication first.

Checkout never uses --force. If existing files conflict, back them up, then retry:

    git --git-dir="$HOME/.cfg" --work-tree="$HOME" checkout

Bootstrap does not automatically pull or check out an existing ~/.cfg, so it cannot
discard your local changes. It does not configure shell aliases: .bash_aliases must
be reviewed for private/machine-specific content before tracking it in Git.
The repository config hides untracked home files from status, but explicit
"config add PATH" still works.

## Preview and apply

Run as your normal user, not "sudo ansible-playbook":

    ansible-playbook ~/.config/workstation/workstation.yml -i localhost, --syntax-check

    ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
      --ask-become-pass --check --diff

    ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
      --ask-become-pass

Check mode is not a complete simulation. On a fresh computer, new repositories
cannot be refreshed and their packages may not be found. Vendor installers and
service changes are skipped in check mode. get_url may report predicted changes.
Diffs can reveal configuration; do not publish sensitive output.

Full application has NOT been performed during initial implementation.
Review a full privileged dry run before applying.

## Update a stale machine

    config status
    # Resolve/commit local changes before pulling.
    config pull --ff-only
    ansible-playbook ~/.config/workstation/workstation.yml -i localhost, --ask-become-pass

This upgrades only managed apt packages, not every OS package. Dependencies may
also be upgraded by apt. Normal Ubuntu system updates remain a separate task.
Removing a package from vars.yml does not uninstall it.
Setting an install/enable option to false skips management; it does not uninstall
existing applications, remove their repositories, or stop existing services.

Zed and Claude CLI installers run only when missing, unless explicitly requested:

    ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
      --tags applications -e update_vendor_apps=true

Already-installed vendor apps can also use their own update mechanisms.
Running a vendor installer again is not guaranteed to produce zero changes.

To install missing apt packages without requesting upgrades:

    ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
      --ask-become-pass -e package_state=present

For a future professional-machine profile:

    ansible-playbook ~/.config/workstation/workstation.yml -i localhost, \
      --ask-become-pass -e '{"install_latex": false, "install_personal_apps": false}'

This is only an override example, not a fully developed work profile. Firefox,
the Neovim PPA, common desktop packages and Syncthing are still managed.

## Important behavior

- The old Mozilla .list file from setup_ubuntu.sh is replaced by mozilla.sources.
- Known source files are managed, so manual edits to them will be overwritten.
- Other custom duplicate source definitions may need manual reconciliation.
- Firefox's apt replacement is installed before removing its Snap. Browser profile
  migration is not automated; back up your browser data before the first apply.
- A Neovim deb822 PPA already created by Ubuntu's add-apt-repository is reused.
- Syncthing runs via syncthing@YOUR_USER.service. Devices must be paired separately.
  Do not also run a separate user-level Syncthing instance on the same data.
- Upstream package/key URL changes can require repository task updates.

## Verification

    bash -n ~/setup_ubuntu.sh ~/.config/workstation/bootstrap.sh
    python3 ~/.config/workstation/tests/test_bootstrap.py

The bootstrap tests use temporary homes and a local test Git repository.
They stub sudo, so no system packages are installed.
A disposable Ubuntu VM is still recommended for a full fresh-machine test.
