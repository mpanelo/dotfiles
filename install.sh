#!/bin/bash
# Standalone entry point for a new Mac. Defaults to main; an explicit commit
# remains optional. No Homebrew, Python, Fish, or chezmoi required.
set -euo pipefail
if (( $# > 1 )) || [[ $# == 1 && ! $1 =~ ^[a-f0-9]{40}$ ]]; then
    printf '%s\n' 'Usage: install.sh [40_CHARACTER_COMMIT] (default: main)' >&2
    exit 2
fi
revision=${1:-}
repository=https://github.com/mpanelo/dotfiles.git
[[ $(uname -s) == Darwin && $EUID != 0 ]] || { printf '%s\n' 'Use a normal macOS account.' >&2; exit 1; }
[[ ${XDG_CONFIG_HOME:-$HOME/.config} == "$HOME/.config" ]] || { printf '%s\n' 'Custom XDG_CONFIG_HOME requires a reviewed setup.' >&2; exit 1; }
checkout="$HOME/.local/share/chezmoi"
for parent in "$HOME/.local" "$HOME/.local/share" "$checkout"; do
    [[ ! -L "$parent" ]] || { printf '%s\n' 'Refusing a symlinked checkout location.' >&2; exit 1; }
done
[[ ! -L "$checkout/.git" ]] || { printf '%s\n' 'Refusing a symlinked Git directory.' >&2; exit 1; }
if [[ ! -e "$checkout" ]]; then
    for path in .config/fish .config/alacritty .config/nvim .config/tmux .config/starship.toml .tmux.conf; do
        [[ ! -e "$HOME/$path" && ! -L "$HOME/$path" ]] || {
            printf 'Existing %s requires the migration procedure; nothing was installed.\n' "$path" >&2
            exit 1
        }
    done
fi
if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install
    printf '%s\n' 'Finish the Command Line Tools dialog, then rerun this same command.' >&2
    exit 1
fi
head=''
if [[ -e "$checkout" ]]; then
    [[ -d "$checkout/.git" ]] || { printf '%s\n' 'Checkout path already exists and is not a Git repository.' >&2; exit 1; }
    [[ $(git -C "$checkout" remote get-url origin) == "$repository" ]] || {
        printf '%s\n' 'Existing checkout has an unexpected origin; review it first.' >&2; exit 1
    }
    head=$(git -C "$checkout" rev-parse --verify HEAD 2>/dev/null || true)
    [[ -z "$revision" || -z "$head" || "$head" == "$revision" ]] || {
        printf '%s\n' 'Existing checkout is at a different revision. Review it; the installer will not reset it.' >&2
        exit 1
    }
    [[ -z $(git -C "$checkout" status --porcelain) ]] || {
        printf '%s\n' 'Existing checkout has local changes; review them first.' >&2; exit 1
    }
    # Resume the selected snapshot even if main has advanced since a failed run.
    [[ -n "$revision" ]] || revision=$head
fi
if [[ -z "$revision" ]]; then
    remote=$(git ls-remote --exit-code "$repository" refs/heads/main) || {
        printf '%s\n' 'Could not resolve main; nothing was installed.' >&2
        exit 1
    }
    [[ "$remote" =~ ^([a-f0-9]{40})[[:space:]]+refs/heads/main$ ]] || {
        printf '%s\n' 'Unexpected main revision; nothing was installed.' >&2
        exit 1
    }
    revision=${BASH_REMATCH[1]}
fi
printf 'Using dotfiles revision %s\n' "$revision"
if [[ ! -e "$checkout" ]]; then
    mkdir -p "$checkout"
    git -C "$checkout" init --quiet
    git -C "$checkout" remote add origin "$repository"
fi
if [[ -z ${head:-} ]]; then
    git -C "$checkout" fetch --quiet --depth 1 origin "$revision"
    git -C "$checkout" checkout --quiet --detach "$revision"
fi
exec /bin/bash "$checkout/bootstrap.sh"
