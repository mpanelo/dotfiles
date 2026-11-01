#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/bootstrap/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
safe_path "$HOME" '.local/state/dotfiles/managed.sha256' || die 'Unsafe state destination.'
mkdir -p "$STATE_DIR"
umask 077
pending=$(mktemp "$STATE_DIR/managed.XXXXXX")
while read -r relative source_file; do
    [[ -n "$relative" && "$relative" != \#* ]] || continue
    safe_path "$HOME" "$relative" || die "Unsafe managed file: $relative"
    [[ -f "$HOME/$relative" ]] || die "Missing managed file: $relative"
    actual=$(sha_file "$HOME/$relative")
    [[ "$actual" == "$(desired_hash "$HOME" "$relative" "$source_file")" ]] ||
        die "Config changed during provisioning; refusing to claim ownership: $relative"
    printf '%s  %s\n' "$actual" "$relative" >> "$pending"
done < "$REPO_ROOT/manifests/config-files.tsv"
mv "$pending" "$STATE_DIR/managed.sha256"
log 'Recorded configuration ownership for safe future updates.'
