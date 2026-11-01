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

download_installer() {
    local requested=$1 destination=$2 name url checksum
    while read -r name url checksum; do
        [[ "$name" == "$requested" ]] || continue
        [[ "$url" == https://* && "$checksum" =~ ^[a-f0-9]{64}$ ]] || die 'Invalid installer declaration.'
        # -q prevents curl from sourcing personal configuration or credentials.
        curl -q --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL "$url" -o "$destination" || return
        [[ $(sha_file "$destination") == "$checksum" ]] || die "$requested installer checksum mismatch; refusing to execute it."
        return
    done < "$REPO_ROOT/manifests/installers.tsv"
    die "No pinned installer is declared for $requested."
}

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
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$BREW_PREFIX/opt/ssh-copy-id/bin:$BREW_PREFIX/bin:$BREW_PREFIX/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
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

check_fish_syntax() {
    local fish=${1:-fish} relative source_file checksum
    while read -r relative source_file; do
        case "$relative" in
            .config/fish/*.fish)
                safe_path "$HOME" "$relative" || die "Unsafe managed Fish file: $relative"
                [[ -f "$HOME/$relative" ]] || die "Missing managed Fish file: $relative"
                "$fish" --no-config --no-execute "$HOME/$relative" || return ;;
        esac
    done < "$REPO_ROOT/manifests/config-files.tsv"
    safe_path "$HOME" '.local/state/dotfiles/fish-plugin-files.sha256' || die 'Unsafe Fish plugin inventory.'
    if [[ -f "$STATE_DIR/fish-plugin-files.sha256" ]]; then
        while read -r checksum relative; do
            case "$relative" in
                .config/fish/functions/*.fish|.config/fish/conf.d/*.fish|.config/fish/completions/*.fish)
                    safe_path "$HOME" "$relative" || die "Unsafe Fish plugin file: $relative"
                    [[ -f "$HOME/$relative" ]] || die "Missing Fish plugin file: $relative"
                    "$fish" --no-config --no-execute "$HOME/$relative" || return ;;
            esac
        done < "$STATE_DIR/fish-plugin-files.sha256"
    fi
}

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
    local target=$1 url=$2 commit=$3 branch=${4:-} head=''
    [[ "$commit" =~ ^[a-f0-9]{40}$ ]] || die 'Plugin references must be full commit IDs.'
    if [[ -n "$branch" ]]; then
        git check-ref-format "refs/heads/$branch" >/dev/null || die 'Invalid plugin branch.'
    fi
    safe_path "$HOME" "${target#"$HOME"/}" || die "Unsafe plugin destination: $target"
    if [[ -e "$target" ]]; then
        [[ -d "$target/.git" && ! -L "$target/.git" ]] || die "Not a managed Git checkout: $target"
        [[ $(git -C "$target" remote get-url origin) == "$url" ]] || die "Unexpected plugin origin: $target"
        [[ -z $(git -C "$target" status --porcelain) ]] || die "Plugin has local changes: $target"
        head=$(git -C "$target" rev-parse --verify HEAD 2>/dev/null || true)
    else
        mkdir -p "$target"
        git -C "$target" init --quiet
        git -C "$target" remote add origin "$url"
    fi
    if [[ "$head" != "$commit" ]]; then
        git -C "$target" fetch --quiet --depth 1 origin "$commit"
        git -C "$target" checkout --quiet --detach "$commit"
    fi
    if [[ -n "$branch" ]]; then
        # lazy.nvim needs a branch even when HEAD is detached at a lockfile pin.
        # Backfill only missing metadata; retain refs from later upstream fetches.
        if ! git -C "$target" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            git -C "$target" update-ref "refs/remotes/origin/$branch" "$commit"
        fi
        if ! git -C "$target" symbolic-ref --quiet refs/remotes/origin/HEAD >/dev/null; then
            git -C "$target" symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$branch"
        fi
    fi
}
