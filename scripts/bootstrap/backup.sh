#!/bin/bash
# Saves only the declared configuration and directory-link metadata. Does not
# change live paths, traverse plugin directories, or inspect universal variables.
set -euo pipefail
# shellcheck source=scripts/bootstrap/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
[[ ${1:-} == --create ]] || die 'Usage: backup.sh --create [--legacy-root PATH]'
shift
legacy_root=$REPO_ROOT
if (($#)); then
    [[ $# == 2 && $1 == --legacy-root ]] || die 'Usage: backup.sh --create [--legacy-root PATH]'
    legacy_root=$2
fi
[[ "$legacy_root" == /* && -d "$legacy_root" && ! -L "$legacy_root" ]] || die 'Legacy root must be an existing absolute directory, not a symlink.'
legacy_root=$(CDPATH='' cd -- "$legacy_root" && pwd -P)
safe_path "$HOME" '.config' || die 'Unsafe configuration parent; no files were backed up.'
safe_path "$HOME" '.local/state/dotfiles/backups' || die 'Unsafe backup location.'
umask 077
mkdir -p "$STATE_DIR/backups"
backup=$(mktemp -d "$STATE_DIR/backups/config.XXXXXXXX")
mkdir "$backup/files" "$backup/links"
: > "$backup/files.sha256"
: > "$backup/absent.txt"
for relative in .config/fish .config/alacritty .config/nvim .config/tmux; do
    if [[ -L "$HOME/$relative" ]]; then
        mkdir -p "$backup/links/$(dirname "$relative")"
        cp -P "$HOME/$relative" "$backup/links/$relative"
    fi
done
while read -r relative _source_file; do
    [[ -n "$relative" && "$relative" != \#* ]] || continue
    copy_source="$HOME/$relative"
    if ! safe_path "$HOME" "$relative"; then
        component=''; legacy=''
        case "$relative" in
            .config/fish/*|.config/alacritty/*|.config/nvim/*|.config/tmux/*)
                component=${relative#.config/}; component=${component%%/*}
                legacy="$component/${relative#".config/$component/"}" ;;
            .config/starship.toml) legacy=starship.toml ;;
        esac
        if [[ -z "$legacy" ]] || ! safe_path "$legacy_root" "$legacy"; then
            die "Unsafe link at $relative; incomplete backup remains private at $backup"
        fi
        # Compare identities before reading anything through a live link. Copy
        # only from the explicitly selected, symlink-free legacy source path.
        if [[ -f "$copy_source" && "$copy_source" -ef "$legacy_root/$legacy" ]]; then
            copy_source="$legacy_root/$legacy"
        elif [[ ! -e "$copy_source" && ! -L "$copy_source" && -n "$component" && "$HOME/.config/$component" -ef "$legacy_root/$component" ]]; then
            copy_source="$legacy_root/$legacy"
        else die "Unrecognized link at $relative; incomplete backup remains private at $backup"
        fi
    fi
    if [[ -f "$copy_source" ]]; then
        original=$(sha_file "$copy_source")
        mkdir -p "$backup/files/$(dirname "$relative")"
        cp -pP "$copy_source" "$backup/files/$relative"
        [[ ! -L "$backup/files/$relative" ]] || die 'Source changed to a symlink during backup; refusing to read it.'
        checksum=$(sha_file "$backup/files/$relative")
        [[ "$checksum" == "$original" ]] || die "Source changed during backup: $relative; incomplete backup remains private at $backup"
        printf '%s  %s\n' "$checksum" "$relative" >> "$backup/files.sha256"
        if [[ -L "$HOME/$relative" ]]; then
            safe_path "$backup/links" "$relative" || die 'Unsafe link metadata destination.'
            mkdir -p "$backup/links/$(dirname "$relative")"
            cp -P "$HOME/$relative" "$backup/links/$relative"
        fi
    elif [[ -e "$HOME/$relative" || -L "$HOME/$relative" ]]; then
        die "Unexpected type at $relative; incomplete backup remains private at $backup"
    else
        printf '%s\n' "$relative" >> "$backup/absent.txt"
    fi
done < "$REPO_ROOT/manifests/config-files.tsv"
printf '%s\n' "$backup"
