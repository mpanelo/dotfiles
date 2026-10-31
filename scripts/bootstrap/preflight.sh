#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/bootstrap/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

destination=$HOME
files_only=0
while (($#)); do
    case $1 in
        --destination) (($# >= 2)) || die '--destination needs an absolute directory.'; destination=$2; shift 2 ;;
        --files-only) files_only=1; shift ;;
        *) die "Unknown preflight argument: $1" ;;
    esac
done
[[ -d "$destination" && "$destination" == /* ]] || die 'Destination must be an existing absolute directory.'
((files_only)) || require_macos

# New source files must enter the conflict/backup inventory before deployment.
while IFS= read -r source_path; do
    source_relative=${source_path#"$REPO_ROOT/home"/}
    case "$source_relative" in .chezmoi*|run_*) continue ;; esac
    awk -v source="$source_relative" '$2 == source {found=1} END {exit !found}' "$REPO_ROOT/manifests/config-files.tsv" ||
        die "Source file is missing from the safety inventory: $source_relative"
done < <(find "$REPO_ROOT/home" -type f | LC_ALL=C sort)

conflicts=0
conflict() { printf 'CONFLICT: %s\n' "$*" >&2; conflicts=$((conflicts + 1)); }
baseline="$destination/.local/state/dotfiles/managed.sha256"
safe_path "$destination" '.local/state/dotfiles/managed.sha256' || die 'Unsafe state directory or ownership manifest.'

while read -r relative source_file; do
    [[ -n "$relative" && "$relative" != \#* ]] || continue
    target="$destination/$relative"
    if ! safe_path "$destination" "$relative"; then
        conflict "$relative has a symlink or non-directory parent; leave it intact and use the migration procedure."
        continue
    fi
    [[ -e "$target" ]] || continue
    if [[ ! -f "$target" ]]; then conflict "$relative is not a regular file."; continue; fi
    actual=$(sha_file "$target")
    previous=''
    if [[ -f "$baseline" ]]; then previous=$(awk -v path="$relative" '$2 == path {print $1; exit}' "$baseline"); fi
    if [[ -n "$previous" && "$actual" == "$previous" ]]; then continue; fi
    desired=''
    if [[ "$source_file" != *.tmpl ]] || command -v chezmoi >/dev/null 2>&1; then
        # Rendering desired content does not apply files or execute run scripts.
        desired=$(desired_hash "$destination" "$relative" "$source_file")
    fi
    [[ "$actual" == "$desired" ]] || conflict "$relative differs from both the desired content and the last applied version."
done < "$REPO_ROOT/manifests/config-files.tsv"

for relative in .local/bin .local/share/uv .local/share/nvim .local/share/dotfiles .cargo .rustup .config/tmux/plugins .config/chezmoi; do
    safe_path "$destination" "$relative" || conflict "Unsafe runtime directory: $relative"
    [[ ! -e "$destination/$relative" || -d "$destination/$relative" ]] || conflict "Runtime path is not a directory: $relative"
done
[[ ! -e "$destination/.tmux.conf" && ! -L "$destination/.tmux.conf" ]] ||
    conflict 'Existing ~/.tmux.conf could shadow the XDG configuration.'

if ((!files_only)); then
    # Stop before installing packages over manually installed cask artifacts.
    if [[ -e /Applications/Alacritty.app && ! -d "$BREW_PREFIX/Caskroom/alacritty" ]]; then
        conflict 'Alacritty.app is unmanaged. Review cask adoption before provisioning.'
    fi
    if [[ ! -d "$BREW_PREFIX/Caskroom/font-jetbrains-mono-nerd-font" ]]; then
        for font_dir in "$HOME/Library/Fonts" /Library/Fonts; do
            for font in "$font_dir"/*JetBrains*"Nerd"*; do
                [[ -e "$font" ]] || continue
                conflict 'JetBrains Nerd Fonts are unmanaged. Review identical-artifact adoption or a backed-up handoff.'
                break 2
            done
        done
    fi
fi

((conflicts == 0)) || die "$conflicts conflict(s); no installation or configuration changes were made by preflight. See docs/recovery.md."
log 'Preflight passed. No destination files were changed.'
