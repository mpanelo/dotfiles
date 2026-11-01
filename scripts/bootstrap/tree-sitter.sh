#!/bin/bash
# Source-only helpers for the pinned upstream CLI, independent of Cargo builds.

tree_sitter_asset() {
    case $(uname -m) in
        arm64) printf '%s\n' macos-arm64 ;;
        x86_64) printf '%s\n' macos-x64 ;;
        *) die 'Unsupported Tree-sitter architecture.' ;;
    esac
}

tree_sitter_is_current() {
    local pin archive binary_hash recorded_pin recorded_archive recorded_hash
    safe_path "$HOME" '.local/bin/tree-sitter' || return 1
    safe_path "$HOME" '.local/state/dotfiles/tree-sitter.release' || return 1
    [[ -f "$HOME/.local/bin/tree-sitter" && -x "$HOME/.local/bin/tree-sitter" && -f "$STATE_DIR/tree-sitter.release" ]] || return 1
    pin=$(version tree-sitter-cli)
    archive=$(version "tree-sitter-$(tree_sitter_asset)-sha256")
    read -r recorded_pin recorded_archive recorded_hash < "$STATE_DIR/tree-sitter.release" || return 1
    [[ "$recorded_pin" == "$pin" && "$recorded_archive" == "$archive" ]] || return 1
    binary_hash=$(sha_file "$HOME/.local/bin/tree-sitter") || return 1
    [[ "$binary_hash" == "$recorded_hash" ]] || return 1
    [[ $("$HOME/.local/bin/tree-sitter" --version) == "tree-sitter $pin"* ]]
}

install_tree_sitter() (
    # Subshell variables survive a nested die/exit until the EXIT trap runs.
    work=''; stage=''; pending=''
    target="$HOME/.local/bin/tree-sitter"
    record="$STATE_DIR/tree-sitter.release"
    pin=$(version tree-sitter-cli)
    asset=$(tree_sitter_asset)
    archive=$(version "tree-sitter-$asset-sha256")
    [[ "$pin" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$archive" =~ ^[a-f0-9]{64}$ ]] || die 'Invalid Tree-sitter release pin.'
    safe_path "$HOME" '.local/bin/tree-sitter' || die 'Unsafe Tree-sitter executable destination.'
    safe_path "$HOME" '.local/state/dotfiles/tree-sitter.release' || die 'Unsafe Tree-sitter ownership record.'
    if tree_sitter_is_current; then
        log "Tree-sitter CLI $pin is already installed from the upstream release"
        return
    fi
    original=''; owned=0
    if [[ -e "$target" ]]; then
        [[ -f "$target" && -x "$target" ]] || die 'Existing Tree-sitter target is not a regular executable; left intact.'
        original=$(sha_file "$target")
        if [[ -f "$record" ]]; then
            previous=''
            read -r _recorded_pin _recorded_archive previous < "$record" || true
            [[ "$original" != "$previous" ]] || owned=1
        fi
    fi
    # shellcheck disable=SC2329 # Invoked by the EXIT trap.
    cleanup_tree_sitter() {
        [[ -z "$stage" ]] || rm -f -- "$stage"
        [[ -z "$pending" ]] || rm -f -- "$pending"
        [[ -z "$work" ]] || rm -rf -- "$work"
    }
    trap cleanup_tree_sitter EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
    log "Installing Tree-sitter CLI $pin from its checksum-verified upstream binary"
    work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tree-sitter.XXXXXX")
    curl --proto '=https' --tlsv1.2 -fsSL \
        "https://github.com/tree-sitter/tree-sitter/releases/download/v$pin/tree-sitter-$asset.gz" -o "$work/tree-sitter.gz"
    [[ $(sha_file "$work/tree-sitter.gz") == "$archive" ]] || die 'Tree-sitter archive checksum mismatch; nothing was installed.'
    gzip -dc "$work/tree-sitter.gz" > "$work/tree-sitter"
    lipo -verify_arch "$(uname -m)" "$work/tree-sitter" || die 'Tree-sitter binary does not support the native architecture.'
    chmod 755 "$work/tree-sitter"
    [[ $("$work/tree-sitter" --version) == "tree-sitter $pin"* ]] || die 'Tree-sitter release version mismatch.'
    desired=$(sha_file "$work/tree-sitter")
    if [[ -n "$original" && "$original" != "$desired" ]] && ((!owned)); then
        die 'Existing Tree-sitter executable is unowned or modified; left intact.'
    fi
    mkdir -p "$HOME/.local/bin" "$STATE_DIR"
    stage=$(mktemp "$HOME/.local/bin/.tree-sitter.XXXXXX")
    cp "$work/tree-sitter" "$stage"
    chmod 755 "$stage"
    pending=$(umask 077; mktemp "$STATE_DIR/tree-sitter.XXXXXX")
    printf '%s %s %s\n' "$pin" "$archive" "$desired" > "$pending"
    safe_path "$HOME" '.local/bin/tree-sitter' || die 'Tree-sitter destination changed during installation.'
    if [[ -n "$original" ]]; then
        [[ -f "$target" && $(sha_file "$target") == "$original" ]] || die 'Tree-sitter changed during installation; left intact.'
        if [[ "$original" != "$desired" ]]; then mv -f "$stage" "$target"; fi
    else
        [[ ! -e "$target" && ! -L "$target" ]] || die 'Tree-sitter destination appeared during installation; left intact.'
        mv -n "$stage" "$target"
        [[ ! -e "$stage" ]] || die 'Tree-sitter destination appeared during installation; left intact.'
    fi
    mv "$pending" "$record"
)
