#!/usr/bin/env bash

# remote_root is intentionally expanded into commands executed remotely.
# shellcheck disable=SC2029

set -euo pipefail

usage() {
	echo "Usage: $0 user@host [remote-dotfiles-directory]" >&2
	echo "Example: $0 user@example.com ~/dotfiles" >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	usage
	exit 2
fi

for command in ssh tar; do
	if ! command -v "$command" >/dev/null 2>&1; then
		echo "tmux deploy: missing required command: $command" >&2
		exit 1
	fi
done

script_dir="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(CDPATH='' cd "$script_dir/.." && pwd -P)"
remote="$1"
remote_root="${2:-~/dotfiles}"

printf 'Preparing %s...\n' "$remote"
ssh "$remote" "mkdir -p -- $remote_root/tmux"

printf 'Copying tmux configuration files...\n'
tar -C "$repo_dir" \
	--exclude='tmux/plugins' \
	--exclude='tmux/.git' \
	-cf - tmux |
	ssh "$remote" "tar -xf - -C $remote_root"

printf '\nCopied tmux files to %s:%s/tmux\n' "$remote" "$remote_root"
printf 'After SSHing into the server, run:\n\n'
printf '  cd %s\n' "$remote_root"
printf '  ./tmux/setup.sh\n'
