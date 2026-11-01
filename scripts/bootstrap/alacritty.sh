#!/bin/bash
# Sourced by reconciliation, preflight and verification; never installs on source.

alacritty_fingerprint() (
    local app=$1 file links files checksum mode
    [[ -d "$app" && ! -L "$app" ]] || return 1
    # Refuse links before reading files, including links to unrelated user data.
    links=$(find "$app" -type l -print -quit) || return 1
    [[ -z "$links" ]] || return 1
    cd "$app" || return 1
    files=$(find . -type f | LC_ALL=C sort) || return 1
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        checksum=$(sha_file "$file") || return 1
        mode=$(stat -f '%Lp' "$file") || return 1
        printf '%s  %s  %s\n' "$checksum" "$mode" "$file"
    done <<< "$files" | shasum -a 256 | awk '{print $1}'
)

alacritty_is_managed() {
    local fingerprint
    safe_path "$HOME" 'Applications/Alacritty.app' || return 1
    safe_path "$HOME" '.local/state/dotfiles/alacritty.sha256' || return 1
    [[ -f "$STATE_DIR/alacritty.sha256" ]] || return 1
    fingerprint=$(alacritty_fingerprint "$HOME/Applications/Alacritty.app") || return 1
    [[ $(cat "$STATE_DIR/alacritty.sha256") == "$fingerprint" ]]
}

alacritty_app() {
    if [[ -d "$BREW_PREFIX/Caskroom/alacritty" && -d /Applications/Alacritty.app ]]; then
        printf '%s\n' /Applications/Alacritty.app
    else
        printf '%s\n' "$HOME/Applications/Alacritty.app"
    fi
}

install_alacritty() (
    # Subshell variables survive a nested die/exit until the EXIT trap runs.
    app="$HOME/Applications/Alacritty.app"; pin=''; checksum=''; work=''; stage=''; mounted=0
    binary="$HOME/.local/bin/alacritty"; fingerprint=''
    terminfo="$HOME/.terminfo"
    pin=$(version alacritty)
    checksum=$(version alacritty-dmg-sha256)
    [[ "$pin" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$checksum" =~ ^[a-f0-9]{64}$ ]] || die 'Invalid Alacritty release pin.'
    if [[ $(alacritty_app) == /Applications/Alacritty.app ]]; then
        log 'Keeping the existing Homebrew-managed Alacritty application'
        return
    fi
    safe_path "$HOME" 'Applications/Alacritty.app' || die 'Unsafe Alacritty destination.'
    safe_path "$HOME" '.local/state/dotfiles/alacritty.sha256' || die 'Unsafe Alacritty ownership record.'
    safe_path "$HOME" '.local/bin' || die 'Unsafe local executable directory.'
    safe_path "$HOME" '.terminfo' || die 'Unsafe terminfo directory.'
    [[ ! -e "$binary" && ! -L "$binary" ]] ||
        [[ -L "$binary" && $(readlink "$binary") == "$app/Contents/MacOS/alacritty" ]] ||
        die 'Existing ~/.local/bin/alacritty is not the managed application link.'

    # shellcheck disable=SC2329 # Invoked by the EXIT trap.
    cleanup_alacritty() {
        if ((mounted)) && ! hdiutil detach "$work/mount" >/dev/null; then
            printf 'Could not unmount %s; temporary files were retained.\n' "$work/mount" >&2
            return
        fi
        [[ -z "$stage" ]] || rm -rf -- "$stage"
        [[ -z "$work" ]] || rm -rf -- "$work"
    }
    trap cleanup_alacritty EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP

    if [[ -e "$app" ]]; then
        alacritty_is_managed || die 'Existing ~/Applications/Alacritty.app is unowned or modified; it was left intact.'
        [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist") == "$pin" ]] ||
            die 'Alacritty version changed in the manifest; review replacement of the existing app before upgrading.'
        log "Alacritty $pin is already installed from the upstream release"
    else
        log "Installing Alacritty $pin from its checksum-verified upstream DMG"
        work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-alacritty.XXXXXX")
        curl -q --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
            "https://github.com/alacritty/alacritty/releases/download/v$pin/Alacritty-v$pin.dmg" -o "$work/alacritty.dmg"
        [[ $(sha_file "$work/alacritty.dmg") == "$checksum" ]] || die 'Alacritty DMG checksum mismatch; nothing was installed.'
        mkdir "$work/mount"
        hdiutil attach -readonly -nobrowse -mountpoint "$work/mount" "$work/alacritty.dmg" >/dev/null
        mounted=1
        local source="$work/mount/Alacritty.app"
        [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source/Contents/Info.plist") == org.alacritty ]] || die 'Unexpected app bundle identifier.'
        [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source/Contents/Info.plist") == "$pin" ]] || die 'Unexpected Alacritty version.'
        [[ -x "$source/Contents/MacOS/alacritty" ]] || die 'Alacritty app executable is missing or not executable.'
        lipo -verify_arch "$(uname -m)" "$source/Contents/MacOS/alacritty" || die 'Alacritty does not support the native architecture.'
        mkdir -p "$HOME/Applications" "$STATE_DIR"
        stage=$(mktemp -d "$HOME/Applications/.dotfiles-alacritty.XXXXXX")
        # Preserve bundle metadata. Never remove quarantine or re-sign the app.
        ditto "$source" "$stage/Alacritty.app"
        fingerprint=$(alacritty_fingerprint "$stage/Alacritty.app") || die 'Unexpected links in the Alacritty app bundle.'
        # Record before the atomic move: interruption leaves either no app or an
        # app with a valid ownership record, so retry never needs force/adoption.
        (umask 077; printf '%s\n' "$fingerprint" > "$STATE_DIR/alacritty.sha256")
        [[ ! -e "$app" && ! -L "$app" ]] || die 'Alacritty destination appeared during installation; left intact.'
        mv -n "$stage/Alacritty.app" "$app"
        [[ ! -e "$stage/Alacritty.app" ]] || die 'Alacritty destination appeared during installation; left intact.'
    fi

    mkdir -p "$HOME/.local/bin" "$terminfo"
    [[ -L "$binary" ]] || ln -s "$app/Contents/MacOS/alacritty" "$binary"
    # The upstream bundle includes compiled terminfo. Preserve any definition
    # already available, and install missing definitions only in the user's DB.
    local entry bucket
    for entry in alacritty alacritty-direct; do
        if infocmp "$entry" >/dev/null 2>&1; then continue; fi
        for bucket in 61 a; do
            safe_path "$HOME" ".terminfo/$bucket/$entry" || die 'Unsafe Alacritty terminfo destination.'
            [[ ! -e "$terminfo/$bucket/$entry" ]] || die 'Existing Alacritty terminfo could not be read; left intact.'
        done
        infocmp -x -A "$app/Contents/Resources" "$entry" | tic -x -o "$terminfo" -
    done
    printf 'Alacritty is installed in ~/Applications. First launch and any macOS\n'
    printf 'app approval remain manual; bootstrap does not change security settings.\n'
)
