#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/setup-nvim.sh [--sync]

Requires macOS, Homebrew, and Xcode Command Line Tools.
Use --sync to move an existing config into a backup directory before linking
this repo's config. Otherwise, an existing config is left untouched.
EOF
}

log() {
	printf '\n==> %s\n' "$*"
}

fail() {
	printf 'setup-nvim: %s\n' "$*" >&2
	exit 1
}

(($# <= 1)) || fail "Expected at most one argument. Use --help for usage."
sync=0
case "${1:-}" in
	"") ;;
	--sync) sync=1 ;;
	-h | --help)
		usage
		exit 0
		;;
	*) fail "Unknown argument: $1. Use --help for usage." ;;
esac

[[ "$(uname -s)" == Darwin ]] || fail "This script supports macOS only."
command -v brew >/dev/null 2>&1 || fail "Install Homebrew first: https://brew.sh"
xcode-select -p >/dev/null 2>&1 || fail "Run 'xcode-select --install', then rerun this script."

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../nvim" && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

log "Installing Neovim and plugin prerequisites"
brew install neovim git tree-sitter stylua
# Blink V2 needs Cargo to build its native fuzzy matcher.
command -v cargo >/dev/null 2>&1 || brew install rust

version="$(nvim --version)"
[[ "$version" =~ ^NVIM\ v([0-9]+)\.([0-9]+) ]] || fail "Could not determine Neovim version."
major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
((major > 0 || minor >= 12)) || fail "Neovim 0.12 or newer is required; found ${major}.${minor}."

if [[ -L "$config" ]] && [[ "$(readlink "$config")" == "$source_dir" ]]; then
	log "Neovim config is already linked"
else
	if [[ -e "$config" || -L "$config" ]]; then
		((sync)) || fail "${config} already exists. Use --sync to back it up and link this repo's config."
		backup_dir="$(mktemp -d "${config}.backup.$(date +%Y%m%d%H%M%S).XXXXXX")"
		log "Backing up Neovim config to ${backup_dir}/nvim"
		mv "$config" "${backup_dir}/nvim"
	fi

	log "Linking Neovim config"
	mkdir -p "$(dirname -- "$config")"
	ln -s "$source_dir" "$config"
fi

log "Installing plugins"
nvim --headless -c 'Lazy! sync' -c 'qa!'

log "Building Blink's fuzzy matcher and installing Tree-sitter parsers"
nvim --headless \
	-c 'lua require("blink.cmp").build():pwait()' \
	-c 'lua require("nvim-treesitter").install(require("config.treesitter")):wait(300000)' \
	-c 'qa!'

missing=()
for tool in lua-language-server gopls basedpyright-langserver rust-analyzer ruff goimports gofumpt shfmt; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		missing+=("$tool")
	fi
done

if ((${#missing[@]})); then
	log "Install these configured language tools separately and ensure they are on PATH"
	printf '  %s\n' "${missing[@]}"
fi

log "Neovim setup is complete"
