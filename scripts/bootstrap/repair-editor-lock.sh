#!/bin/bash
# Explicit recovery for the empty/{\n lockfile left by a failed Lazy restore.
set -euo pipefail
# shellcheck source=scripts/bootstrap/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
[[ $# == 0 ]] || die 'Usage: repair-editor-lock.sh'
target="$HOME/.config/nvim/lazy-lock.json"
source_file="$REPO_ROOT/home/dot_config/nvim/lazy-lock.json"
safe_path "$HOME" '.config/nvim/lazy-lock.json' || die 'Unsafe lockfile path; left intact.'
if [[ ! -e "$target" ]]; then log 'No deployed lockfile to repair; bootstrap will create it.'; exit 0; fi
[[ -f "$target" ]] || die 'Lockfile is not a regular file; left intact.'
if cmp -s "$source_file" "$target"; then log 'Lockfile already matches the repository; nothing to repair.'; exit 0; fi
if [[ -s "$target" ]] && ! cmp -s <(printf '{\n') "$target"; then
    die 'Lockfile is not the known truncated Lazy output; left intact. Compare it with the repository manually.'
fi
safe_path "$HOME" '.local/state/dotfiles/backups' || die 'Unsafe backup directory.'
original=$(sha_file "$target")
mkdir -p "$STATE_DIR/backups"
backup=$(mktemp -d "$STATE_DIR/backups/editor-lock.XXXXXX")
chmod 700 "$backup"
cp -p "$target" "$backup/lazy-lock.json"
chmod 600 "$backup/lazy-lock.json"
pending=$(mktemp "$HOME/.config/nvim/.lazy-lock.XXXXXX")
trap 'rm -f "$pending"' EXIT
cp "$source_file" "$pending"
chmod 644 "$pending"
safe_path "$HOME" '.config/nvim/lazy-lock.json' || die 'Lockfile path changed during repair; left intact.'
[[ $(sha_file "$target") == "$original" ]] || die 'Lockfile changed during repair; left intact.'
mv "$pending" "$target"
log "Restored the repository lockfile. Damaged file preserved in $backup"
