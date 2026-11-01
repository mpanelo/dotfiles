#!/bin/bash
# Sourced helpers. Only set_fish_login_shell changes the account/system registry.

account_login_shell() {
    dscl . -read "/Users/$(id -un)" UserShell | awk '$1 == "UserShell:" {print $2; exit}'
}

verify_fish_login_shell() {
    [[ $(account_login_shell) == "$BREW_PREFIX/bin/fish" ]] || die 'Account login shell is not the managed Fish executable.'
}

set_fish_login_shell() {
    local fish=$1 registry=$2 current
    [[ -x "$fish" ]] || die 'Fish must be installed before changing the login shell.'
    [[ -f "$registry" && ! -L "$registry" ]] || die 'Unsafe shell registry.'
    "$fish" --no-config -c exit
    check_fish_syntax "$fish"
    current=$(account_login_shell)
    [[ -n "$current" ]] || die 'Cannot determine the current account login shell.'
    printf 'Current account shell: %s; requested shell: %s\n' "$current" "$fish"
    if ! grep -Fxq "$fish" "$registry"; then
        log 'Registering Fish as an allowed login shell (administrator authentication may be requested)'
        printf '\n%s\n' "$fish" | sudo /usr/bin/tee -a "$registry" >/dev/null
    fi
    if [[ "$current" != "$fish" ]]; then
        log 'Changing this account to Fish (account authentication may be requested)'
        chsh -s "$fish"
    fi
    [[ $(account_login_shell) == "$fish" ]] || die 'Login shell did not change; review account restrictions and rerun bootstrap.'
    log 'Fish is the account login shell. Open a new terminal/login session to use it.'
}
