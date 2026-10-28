#!/usr/bin/env bash
# Entry point retained for existing bookmarks/workflows.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$script_dir/.config/workstation/bootstrap.sh" "$@"
