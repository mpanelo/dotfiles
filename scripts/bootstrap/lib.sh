#!/bin/bash
# Shared by the macOS bootstrap scripts. Compatible with system Bash 3.2.
set -euo pipefail

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
export STATE_DIR="$HOME/.local/state/dotfiles"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_INSTALL_UPGRADE=1

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'dotfiles: %s\n' "$*" >&2; exit 1; }
sha_file() { shasum -a 256 "$1" | awk '{print $1}'; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "Required command is missing: $1"; }

require_macos() {
    [[ $(uname -s) == Darwin ]] || die 'This bootstrap supports macOS only.'
    case $(uname -m) in
        arm64) BREW_PREFIX=/opt/homebrew ;;
        x86_64)
            [[ $(sysctl -in sysctl.proc_translated 2>/dev/null || true) != 1 ]] ||
                die 'Run from a native Apple Silicon terminal, not Rosetta.'
            BREW_PREFIX=/usr/local ;;
        *) die 'Unsupported architecture.' ;;
    esac
    export BREW_PREFIX
    [[ ${XDG_CONFIG_HOME:-$HOME/.config} == "$HOME/.config" ]] ||
        die "This layout currently requires XDG_CONFIG_HOME=$HOME/.config (or unset)."
    [[ ${CARGO_HOME:-$HOME/.cargo} == "$HOME/.cargo" ]] || die 'Custom CARGO_HOME requires a reviewed migration.'
    [[ ${RUSTUP_HOME:-$HOME/.rustup} == "$HOME/.rustup" ]] || die 'Custom RUSTUP_HOME requires a reviewed migration.'
}

bootstrap_path() {
    require_macos
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$BREW_PREFIX/bin:$BREW_PREFIX/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
    export UV_TOOL_DIR="$HOME/.local/share/uv/tools" UV_TOOL_BIN_DIR="$HOME/.local/bin"
}

# Reject symlinked parents before reading/writing any managed destination.
safe_path() {
    local root=$1 relative=$2 current=$1 part
    local -a path_parts
    [[ "$root" == /* && "$relative" != /* && "$relative" != *'..'* ]] || return 1
    [[ ! -L "$root" && -d "$root" ]] || return 1
    local old_ifs=$IFS
    IFS=/ read -r -a path_parts <<< "$relative"
    IFS=$old_ifs
    for part in "${path_parts[@]}"; do
        current="$current/$part"
        [[ ! -L "$current" ]] || return 1
        if [[ "$current" != "$root/$relative" && -e "$current" && ! -d "$current" ]]; then return 1; fi
    done
}

version() { jq -er --arg key "$1" '.[$key]' "$REPO_ROOT/manifests/versions.json"; }

desired_hash() {
    local destination=$1 relative=$2 source_file=$3
    if [[ "$source_file" == *.tmpl ]]; then
        require_command chezmoi
        chezmoi --source "$REPO_ROOT" --destination "$destination" cat "$destination/$relative" |
            shasum -a 256 | awk '{print $1}'
    else
        sha_file "$REPO_ROOT/home/$source_file"
    fi
}

# Installs/checks a repository-owned plugin checkout without discarding changes.
sync_checkout() {
    local target=$1 url=$2 commit=$3 head
    [[ "$commit" =~ ^[a-f0-9]{40}$ ]] || die 'Plugin references must be full commit IDs.'
    safe_path "$HOME" "${target#"$HOME"/}" || die "Unsafe plugin destination: $target"
    if [[ -e "$target" ]]; then
        [[ -d "$target/.git" && ! -L "$target/.git" ]] || die "Not a managed Git checkout: $target"
        [[ $(git -C "$target" remote get-url origin) == "$url" ]] || die "Unexpected plugin origin: $target"
        [[ -z $(git -C "$target" status --porcelain) ]] || die "Plugin has local changes: $target"
        head=$(git -C "$target" rev-parse --verify HEAD 2>/dev/null || true)
        [[ "$head" != "$commit" ]] || return 0
    else
        mkdir -p "$target"
        git -C "$target" init --quiet
        git -C "$target" remote add origin "$url"
    fi
    git -C "$target" fetch --quiet --depth 1 origin "$commit"
    git -C "$target" checkout --quiet --detach "$commit"
}
