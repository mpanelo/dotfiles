#!/bin/bash
# Private diagnostics and package baselines; never source credentials or profiles.

package_snapshot() {
    local label=$1
    [[ "$label" == before || "$label" == after ]] || die 'Invalid inventory label.'
    if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
        printf 'present\n' > "$DOTFILES_RUN_DIR/homebrew-$label.txt"
        "$BREW_PREFIX/bin/brew" list --formula --versions > "$DOTFILES_RUN_DIR/formulae-$label.txt" || return
        "$BREW_PREFIX/bin/brew" list --cask --versions > "$DOTFILES_RUN_DIR/casks-$label.txt" || return
        "$BREW_PREFIX/bin/brew" tap > "$DOTFILES_RUN_DIR/taps-$label.txt" || return
    else
        printf 'absent\n' > "$DOTFILES_RUN_DIR/homebrew-$label.txt"
        : > "$DOTFILES_RUN_DIR/formulae-$label.txt"
        : > "$DOTFILES_RUN_DIR/casks-$label.txt"
        : > "$DOTFILES_RUN_DIR/taps-$label.txt"
    fi
}

begin_bootstrap_run() {
    [[ ${DOTFILES_ISOLATED_TEST:-0} != 1 ]] || die 'Run logging is disabled in the isolated harness.'
    if [[ -n ${DOTFILES_RUN_DIR:-} ]]; then
        [[ "$DOTFILES_RUN_DIR" == "$STATE_DIR/runs/"* ]] || die 'Unexpected run directory.'
        safe_path "$HOME" "${DOTFILES_RUN_DIR#"$HOME"/}" || die 'Unsafe run directory.'
        [[ -d "$DOTFILES_RUN_DIR" ]] || die 'Missing run directory.'
        return
    fi
    safe_path "$HOME" '.local/state/dotfiles/runs' || die 'Unsafe diagnostics directory.'
    mkdir -p "$STATE_DIR/runs"
    DOTFILES_RUN_DIR=$(mktemp -d "$STATE_DIR/runs/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")
    export DOTFILES_RUN_DIR
    chmod 700 "$DOTFILES_RUN_DIR"
    # The directory is private even when the invoking user's umask is permissive.
    package_snapshot before
    dscl . -read "/Users/$(id -un)" UserShell > "$DOTFILES_RUN_DIR/login-shell-before.txt"
    log "Private provisioning records: $DOTFILES_RUN_DIR"
}

run_logged() {
    local label=$1 status=0
    shift
    [[ "$label" =~ ^[a-z-]+$ ]] || die 'Invalid log label.'
    begin_bootstrap_run || return
    # Capture output only: never use script(1), shell tracing, or record stdin.
    # pipefail preserves failures from the installer as well as tee failures.
    "$@" 2>&1 | tee -a "$DOTFILES_RUN_DIR/$label.log" || status=$?
    return "$status"
}

save_brew_caveats() {
    local status=0
    # Refresh on failure too: a partial Bundle run can still install packages.
    "$BREW_PREFIX/bin/brew" info --installed --verbose > "$DOTFILES_RUN_DIR/brew-info.txt" 2>&1 || status=$?
    package_snapshot after || status=$?
    printf 'Review Homebrew caveats and optional setup steps in:\n  %s\n' "$DOTFILES_RUN_DIR/brew-info.txt"
    printf 'Raw installation output is saved alongside it. Recommendations are not executed automatically.\n'
    return "$status"
}
