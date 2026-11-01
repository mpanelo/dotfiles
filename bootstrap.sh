#!/bin/bash
set -euo pipefail
REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$REPO_ROOT/scripts/bootstrap/lib.sh"
# shellcheck source=scripts/bootstrap/session.sh
source "$REPO_ROOT/scripts/bootstrap/session.sh"

case ${1:-} in
    --help|-h)
        printf '%s\n' 'Usage: ./bootstrap.sh' \
            'Checks for conflicts, installs core tools, and applies configuration.'
        exit 0 ;;
    '') (($# == 0)) || die 'Unexpected argument.' ;;
    *) die 'Unknown argument. Use --help.' ;;
esac

# This check is intentionally before every installer and before chezmoi init.
bootstrap_path
/bin/bash "$REPO_ROOT/scripts/bootstrap/preflight.sh" --quiet
log 'Installation conflict check passed.'
[[ $EUID != 0 ]] || die 'Run as your normal user, not root.'
begin_bootstrap_run
if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install
    die 'Complete the Command Line Tools dialog, then rerun this same command.'
fi

if [[ ! -x "$BREW_PREFIX/bin/brew" ]]; then
    installer=$(mktemp -t dotfiles-homebrew)
    trap 'rm -f "$installer"' EXIT
    download_installer homebrew "$installer"
    run_logged homebrew-install /bin/bash "$installer"
    rm -f "$installer"
    trap - EXIT
fi
[[ -x "$BREW_PREFIX/bin/brew" ]] || die 'Homebrew did not install at its native prefix.'
if [[ ! -x "$BREW_PREFIX/bin/chezmoi" ]]; then
    run_logged chezmoi-install "$BREW_PREFIX/bin/brew" install chezmoi
fi

# Do not silently change the source of an existing chezmoi installation.
config_exists=0
for extension in toml yaml yml json jsonc; do
    config="$HOME/.config/chezmoi/chezmoi.$extension"
    [[ ! -e "$config" && ! -L "$config" ]] || config_exists=1
done
if ((config_exists)); then
    current_source=$(chezmoi source-path)
    [[ "$current_source" == "$REPO_ROOT" || "$current_source" == "$REPO_ROOT/home" ]] ||
        die 'Existing chezmoi source differs from this checkout; review it first.'
else
    chezmoi --source "$REPO_ROOT" init
fi
chezmoi --source "$REPO_ROOT" apply
