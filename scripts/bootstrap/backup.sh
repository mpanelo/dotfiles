#!/bin/bash
# Saves only the declared configuration and directory-link metadata. Does not
# change live paths, traverse plugin directories, or inspect universal variables.
set -euo pipefail
# shellcheck source=scripts/bootstrap/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
[[ ${1:-} == --create && $# == 1 ]] || die 'Usage: backup.sh --create (private backup only; no live changes)'
safe_path "$HOME" '.local/state/dotfiles/backups' || die 'Unsafe backup location.'
umask 077
mkdir -p "$STATE_DIR/backups"
backup=$(mktemp -d "$STATE_DIR/backups/config.XXXXXXXX")
mkdir "$backup/files" "$backup/links"
for relative in .config/fish .config/alacritty .config/nvim .config/tmux; do
    if [[ -L "$HOME/$relative" ]]; then
        mkdir -p "$backup/links/$(dirname "$relative")"
        cp -P "$HOME/$relative" "$backup/links/$relative"
    fi
done
while read -r relative _source_file; do
    [[ -n "$relative" && "$relative" != \#* ]] || continue
    if [[ -f "$HOME/$relative" ]]; then
        mkdir -p "$backup/files/$(dirname "$relative")"
        cp -pL "$HOME/$relative" "$backup/files/$relative"
        printf '%s  %s\n' "$(sha_file "$backup/files/$relative")" "$relative" >> "$backup/files.sha256"
    elif [[ -e "$HOME/$relative" || -L "$HOME/$relative" ]]; then
        die "Unexpected type at $relative; incomplete backup remains private at $backup"
    else
        printf '%s\n' "$relative" >> "$backup/absent.txt"
    fi
done < "$REPO_ROOT/manifests/config-files.tsv"
printf '%s\n' "$backup"
