#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
NVIM_CONFIG_SOURCE="${REPO_ROOT}/nvim"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
NVIM_CONFIG_TARGET="${CONFIG_HOME}/nvim"
SYNC_EXISTING=0

usage() {
	cat <<'EOF'
Usage: scripts/setup-nvim.sh [--sync]

Without --sync, an existing Neovim config is left untouched and causes setup to stop.
With --sync, an existing config is moved to a timestamped backup before this repo's
Neovim config is linked in its place. Plugin and parser setup then runs as usual.
EOF
}

case "${1:-}" in
	"") ;;
	--sync) SYNC_EXISTING=1 ;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
esac

log() {
	printf '\n==> %s\n' "$*"
}

fail() {
	printf 'setup-nvim: %s\n' "$*" >&2
	exit 1
}

install_system_packages() {
	case "$(uname -s)" in
		Darwin)
			command -v brew >/dev/null 2>&1 || fail "Install Homebrew first: https://brew.sh"
			if ! xcode-select -p >/dev/null 2>&1; then
				fail "Xcode Command Line Tools are required. Run 'xcode-select --install', then rerun this script."
			fi
			log "Installing Neovim and system prerequisites with Homebrew"
			brew install neovim git go python node rust stylua
			;;
		Linux)
			if command -v apt-get >/dev/null 2>&1; then
				log "Installing Neovim and system prerequisites with apt"
				sudo apt-get update
				sudo apt-get install -y neovim git curl tar unzip build-essential python3 python3-venv golang-go nodejs npm rustc cargo pkg-config libssl-dev
			elif command -v dnf >/dev/null 2>&1; then
				log "Installing Neovim and system prerequisites with dnf"
				sudo dnf install -y neovim git curl tar unzip make gcc gcc-c++ python3 golang nodejs npm rust cargo pkgconf-pkg-config openssl-devel
			elif command -v pacman >/dev/null 2>&1; then
				log "Installing Neovim and system prerequisites with pacman"
				sudo pacman -Syu --needed --noconfirm neovim git curl tar unzip base-devel python go nodejs npm rust pkgconf
			else
				fail "Unsupported Linux package manager. Install Neovim 0.12+, Git, Go, Python 3, Node.js/npm, Rust/Cargo, curl, tar, unzip, and a C compiler, then rerun."
			fi
			;;
		*)
			fail "Unsupported operating system. This script supports macOS with Homebrew and Linux with apt, dnf, or pacman (including WSL)."
			;;
	esac
}

check_neovim_version() {
	command -v nvim >/dev/null 2>&1 || fail "Neovim was not installed or is not on PATH."
	if ! nvim --headless -u NONE -i NONE -c 'lua local version = vim.version(); if version.major == 0 and version.minor < 12 then vim.api.nvim_err_writeln("Neovim 0.12 or newer is required; found " .. version.major .. "." .. version.minor); vim.cmd("cquit 1") end' -c 'qa!'; then
		fail "Neovim 0.12 or newer is required. Your package manager may provide an older release."
	fi
}

link_config() {
	if [[ -L "$NVIM_CONFIG_TARGET" ]] && [[ "$(readlink "$NVIM_CONFIG_TARGET")" == "$NVIM_CONFIG_SOURCE" ]]; then
		log "Neovim config symlink is already correct"
		return
	fi

	if [[ -e "$NVIM_CONFIG_TARGET" || -L "$NVIM_CONFIG_TARGET" ]]; then
		if ((SYNC_EXISTING == 0)); then
			fail "${NVIM_CONFIG_TARGET} already exists and is not this repository's config. Rerun with --sync to preserve it as a backup and link this repo's config."
		fi

		local backup_target
		backup_target="${NVIM_CONFIG_TARGET}.backup.$(date '+%Y%m%d%H%M%S')"
		local suffix=1
		while [[ -e "$backup_target" || -L "$backup_target" ]]; do
			backup_target="${NVIM_CONFIG_TARGET}.backup.$(date '+%Y%m%d%H%M%S').${suffix}"
			suffix=$((suffix + 1))
		done

		log "Preserving existing Neovim config at ${backup_target}"
		mv "$NVIM_CONFIG_TARGET" "$backup_target"
	fi

	log "Linking Neovim config"
	mkdir -p "$CONFIG_HOME"
	ln -s "$NVIM_CONFIG_SOURCE" "$NVIM_CONFIG_TARGET"
}

install_neovim_dependencies() {
	export PATH="${CARGO_HOME:-${HOME}/.cargo}/bin:${PATH}"
	if ! command -v tree-sitter >/dev/null 2>&1; then
		command -v cargo >/dev/null 2>&1 || fail "Cargo is required to install tree-sitter-cli."
		log "Installing tree-sitter-cli with Cargo"
		cargo install --locked tree-sitter-cli
	fi

	if ! command -v stylua >/dev/null 2>&1; then
		command -v cargo >/dev/null 2>&1 || fail "Cargo is required to install stylua."
		log "Installing stylua with Cargo"
		cargo install --locked stylua
	fi

	log "Installing plugins"
	nvim --headless -c 'Lazy! sync' -c 'qa!'

	log "Installing Tree-sitter parsers"
	nvim --headless \
		-c 'lua require("nvim-treesitter").install(require("config.treesitter")):wait(300000)' \
		-c 'qa!'
}

report_missing_tools() {
	local missing=()
	local tool
	for tool in lua-language-server gopls basedpyright-langserver rust-analyzer stylua ruff goimports gofumpt alejandra shfmt; do
		if ! command -v "$tool" >/dev/null 2>&1; then
			missing+=("$tool")
		fi
	done

	if ((${#missing[@]})); then
		log "Install these configured language tools separately and ensure they are on PATH"
		printf '  %s\n' "${missing[@]}"
	fi
}

install_system_packages
check_neovim_version
link_config
install_neovim_dependencies
report_missing_tools

log "Neovim setup is complete"
