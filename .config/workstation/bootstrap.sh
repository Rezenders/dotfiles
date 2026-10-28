#!/usr/bin/env bash
# Installs prerequisites and checks out dotfiles; does NOT apply the playbook.
set -euo pipefail

if (( EUID == 0 )); then
    printf 'Run as your normal user, not with sudo.\n' >&2
    exit 1
fi

# Provided by the target Ubuntu system, not part of this repository.
# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != ubuntu || "${VERSION_ID:-}" != 26.04 ]]; then
    printf 'This bootstrap currently supports Ubuntu 26.04 only.\n' >&2
    exit 1
fi

sudo apt-get update
sudo apt-get install -y git ansible-core

dotfiles_url="${DOTFILES_URL:-https://github.com/rezenders/dotfiles.git}"
config_git() {
    /usr/bin/git --git-dir="$HOME/.cfg" --work-tree="$HOME" "$@"
}

if [[ ! -e "$HOME/.cfg" ]]; then
    git clone --bare "$dotfiles_url" "$HOME/.cfg"
    # No force: stop rather than overwrite existing untracked files.
    if ! config_git checkout; then
        # Print a reusable command literally, without expanding this machine's HOME.
        # shellcheck disable=SC2016
        printf '%s\n' \
            'Dotfiles checkout stopped. Back up the conflicting files shown above,' \
            'then run: git --git-dir="$HOME/.cfg" --work-tree="$HOME" checkout' \
            'The repository was cloned; it will not be cloned again.' >&2
        exit 1
    fi
else
    if [[ "$(/usr/bin/git --git-dir="$HOME/.cfg" rev-parse --is-bare-repository)" != true ]]; then
        printf '%s\n' "$HOME/.cfg exists but is not a bare Git repository; stopping." >&2
        exit 1
    fi
    printf '%s\n' \
        'Existing ~/.cfg left untouched: no automatic pull or checkout.' \
        'If a previous checkout failed, resolve its conflicts and retry checkout manually.'
fi

config_git config --local status.showUntrackedFiles no

playbook="$HOME/.config/workstation/workstation.yml"
if [[ ! -f "$playbook" ]]; then
    printf 'Playbook not found at %s. Commit/push the workstation files first.\n' "$playbook" >&2
    exit 1
fi

printf '\nBootstrap complete. Review the configuration, then run:\n'
printf '  ansible-playbook %q --ask-become-pass --check --diff\n' "$playbook"
printf '  ansible-playbook %q --ask-become-pass\n' "$playbook"
