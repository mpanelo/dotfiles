#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/bootstrap/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=scripts/bootstrap/alacritty.sh
source "$REPO_ROOT/scripts/bootstrap/alacritty.sh"
# shellcheck source=scripts/bootstrap/session.sh
source "$REPO_ROOT/scripts/bootstrap/session.sh"
# shellcheck source=scripts/bootstrap/login-shell.sh
source "$REPO_ROOT/scripts/bootstrap/login-shell.sh"
[[ ${DOTFILES_ISOLATED_TEST:-0} != 1 ]] || die 'Provisioning is disabled in the isolated test harness.'
bootstrap_path
[[ ${1:-} == packages ]] || require_command jq
/bin/bash "$REPO_ROOT/scripts/bootstrap/preflight.sh"
begin_bootstrap_run

install_packages() {
    log 'Reconciling core Homebrew packages (no routine upgrades or cleanup)'
    local status=0
    run_logged brew-bundle "$BREW_PREFIX/bin/brew" bundle install --no-upgrade --file="$REPO_ROOT/Brewfile" || status=$?
    # A caveat-report failure must not hide the original installation failure.
    save_brew_caveats || printf 'Could not finish Homebrew diagnostics; review the raw install log.\n' >&2
    ((status == 0)) || return "$status"
    install_alacritty
}

install_toolchains() {
    local go_pin rust_pin tree_pin tool module pin actual installer python_pin
    local nvim_version
    nvim_version=$(nvim --version)
    [[ "$nvim_version" =~ ^NVIM\ v([0-9]+)\.([0-9]+) ]] || die 'Could not determine the Neovim version.'
    ((BASH_REMATCH[1] > 0 || BASH_REMATCH[2] >= 12)) ||
        die 'This configuration needs Neovim 0.12 or newer; review an explicit Homebrew upgrade.'
    go_pin=$(version go); rust_pin=$(version rust); tree_pin=$(version tree-sitter-cli)
    python_pin=$(version python)
    export GOTOOLCHAIN="go$go_pin" GOBIN="$HOME/go/bin"
    log "Ensuring Go $go_pin and pinned Go tools"
    "$BREW_PREFIX/bin/go" version
    mkdir -p "$GOBIN"
    while read -r tool module pin; do
        [[ -n "$tool" && "$tool" != \#* ]] || continue
        actual=''
        if [[ -f "$GOBIN/$tool" ]]; then
            [[ $("$BREW_PREFIX/bin/go" version -m "$GOBIN/$tool" | awk '$1 == "path" {print $2; exit}') == "$module" ]] ||
                die "Existing $tool is not the declared Go module; review it before installation."
            actual=$("$BREW_PREFIX/bin/go" version -m "$GOBIN/$tool" | awk '$1 == "mod" {print $3; exit}')
        fi
        if [[ "$actual" != "$pin" ]]; then "$BREW_PREFIX/bin/go" install "$module@$pin"; fi
    done < "$REPO_ROOT/manifests/go-tools.tsv"

    log "Ensuring rustup and Rust $rust_pin components"
    if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
        installer=$(mktemp -t dotfiles-rustup)
        curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs -o "$installer"
        /bin/sh "$installer" -y --no-modify-path --default-toolchain none --profile minimal
        rm -f "$installer"
    fi
    if ! rustup toolchain list | grep -q "^$rust_pin-"; then
        rustup toolchain install "$rust_pin" --profile minimal --component rust-analyzer,rustfmt,clippy,rust-src --no-self-update
    fi
    for component in rust-analyzer rustfmt clippy rust-src; do
        if ! rustup component list --toolchain "$rust_pin" --installed | grep -q "^$component\(-\|$\)"; then
            rustup component add --toolchain "$rust_pin" "$component"
        fi
    done
    if [[ $(rustup toolchain list | awk '/\(.*default/ {print $1}') != "$rust_pin-$(rustc +"$rust_pin" -vV | awk '/^host:/ {print $2}')" ]]; then
        rustup default "$rust_pin"
    fi
    if [[ ! -x "$HOME/.cargo/bin/tree-sitter" ]] ||
        [[ $("$HOME/.cargo/bin/tree-sitter" --version) != "tree-sitter $tree_pin"* ]]; then
        cargo +"$rust_pin" install --root "$HOME/.cargo" --locked --version "$tree_pin" tree-sitter-cli
    fi

    log 'Ensuring uv-isolated BasedPyright/Node and Ruff (fnm installs no Node)'
    for tool in basedpyright ruff; do
        pin=$(version "$tool")
        actual=''
        if [[ -x "$UV_TOOL_DIR/$tool/bin/python" ]]; then
            actual=$("$UV_TOOL_DIR/$tool/bin/python" -I -c \
                'import importlib.metadata as m,sys; print(m.version(sys.argv[1]))' "$tool" 2>/dev/null || true)
            if [[ "$tool" == basedpyright ]]; then
                local node_actual
                node_actual=$("$UV_TOOL_DIR/$tool/bin/python" -I -c \
                    'import importlib.metadata as m; print(m.version("nodejs-wheel-binaries"))' 2>/dev/null || true)
                [[ "$node_actual" == "$(version nodejs-wheel-binaries)" ]] || actual=''
            fi
            [[ $("$UV_TOOL_DIR/$tool/bin/python" -I -c 'import platform; print(platform.python_version())') == "$python_pin" ]] || actual=''
            # A deleted or redirected entry point must also trigger repair.
            [[ -L "$UV_TOOL_BIN_DIR/$tool" && "$UV_TOOL_BIN_DIR/$tool" -ef "$UV_TOOL_DIR/$tool/bin/$tool" ]] || actual=''
        fi
        if [[ "$actual" != "$pin" ]]; then
            uv --no-config tool install --managed-python --python "$python_pin" \
                --no-build --constraints "$REPO_ROOT/manifests/python-tools.constraints.txt" \
                --reinstall "$tool==$pin"
        fi
    done
}

install_fish_plugins() {
    local spec name commit checkout fisher_source='' changed=0 file relative previous actual
    local cache="$HOME/.local/share/dotfiles/fish-plugins"
    local inventory="$STATE_DIR/fish-plugin-files.sha256"
    local pending
    mkdir -p "$cache" "$STATE_DIR"
    pending=$(mktemp "$STATE_DIR/fish-files.XXXXXX")
    while IFS= read -r spec; do
        [[ -n "$spec" && "$spec" != \#* ]] || continue
        name=${spec%@*}; commit=${spec##*@}; checkout="$cache/${name##*/}"
        sync_checkout "$checkout" "https://github.com/$name.git" "$commit"
        [[ "$name" != jorgebucaran/fisher ]] || fisher_source="$checkout/functions/fisher.fish"
        for directory in functions completions conf.d; do
            [[ -d "$checkout/$directory" ]] || continue
            while IFS= read -r file; do
                relative=".config/fish/${file#"$checkout"/}"
                safe_path "$HOME" "$relative" || die "Unsafe Fish plugin file: $relative"
                actual=$(sha_file "$file")
                if [[ -e "$HOME/$relative" ]]; then
                    previous=''
                    if [[ -f "$inventory" ]]; then previous=$(awk -v path="$relative" '$2 == path {print $1; exit}' "$inventory"); fi
                    if [[ $(sha_file "$HOME/$relative") != "$actual" && $(sha_file "$HOME/$relative") != "$previous" ]]; then
                        die "Fish plugin file has local changes: $relative"
                    fi
                else changed=1
                fi
                printf '%s  %s\n' "$actual" "$relative" >> "$pending"
            done < <(find "$checkout/$directory" -type f | LC_ALL=C sort)
        done
    done < "$HOME/.config/fish/fish_plugins"
    [[ -n "$fisher_source" ]] || die 'Fisher pin is missing.'
    if [[ ! -f "$inventory" ]] || ! cmp -s "$inventory" "$pending"; then changed=1; fi
    if ((changed)); then
        # --no-config prevents prompt, direnv, fnm, and plugin startup side effects.
        # shellcheck disable=SC2016 # Fish, not Bash, expands argv.
        fish --no-config -c 'source "$argv[1]"; fisher update' "$fisher_source" </dev/null
        while read -r actual relative; do
            [[ -f "$HOME/$relative" && $(sha_file "$HOME/$relative") == "$actual" ]] || die "Fish plugin installation differs from its pin: $relative"
        done < "$pending"
    fi
    chmod 600 "$pending"
    mv "$pending" "$inventory"
}

install_plugins() {
    local name url commit before after fingerprint previous='' missing=0
    log 'Reconciling pinned Fish and tmux plugins'
    install_fish_plugins
    while read -r name url commit; do
        [[ -n "$name" && "$name" != \#* ]] || continue
        sync_checkout "$HOME/.config/tmux/plugins/$name" "$url" "$commit"
    done < "$REPO_ROOT/manifests/tmux-plugins.tsv"

    log 'Restoring Neovim plugin commits from lazy-lock.json'
    local lock="$HOME/.config/nvim/lazy-lock.json"
    before=$(sha_file "$lock")
    while read -r name url; do
        [[ -n "$name" && "$name" != \#* ]] || continue
        commit=$(jq -er --arg name "$name" '.[$name].commit' "$lock")
        sync_checkout "$HOME/.local/share/nvim/lazy/$name" "$url" "$commit"
    done < "$REPO_ROOT/manifests/nvim-plugins.tsv"
    fingerprint=$(cat "$lock" "$REPO_ROOT/manifests/versions.json" \
        "$HOME/.config/nvim/lua/config/treesitter.lua" "$REPO_ROOT/scripts/bootstrap/install-editor.lua" | shasum -a 256 | awk '{print $1}')
    [[ ! -f "$STATE_DIR/editor.sha256" ]] || previous=$(cat "$STATE_DIR/editor.sha256")
    # A successful manifest stamp cannot hide subsequently deleted build artifacts.
    [[ -f "$HOME/.local/share/nvim/lazy/telescope-fzf-native.nvim/build/libfzf.so" ]] || missing=1
    if [[ "$fingerprint" != "$previous" ]] ||
        ! /bin/bash "$REPO_ROOT/scripts/bootstrap/verify.sh" --editor-only >/dev/null 2>&1; then missing=1; fi
    if ((missing)); then
        export DOTFILES_REPO_ROOT="$REPO_ROOT" RUSTUP_TOOLCHAIN
        RUSTUP_TOOLCHAIN=$(version rust)
        DOTFILES_PROVISIONING=1 nvim --headless -c 'lua dofile(vim.env.DOTFILES_REPO_ROOT .. "/scripts/bootstrap/install-editor.lua")'
        after=$(sha_file "$lock")
        [[ "$before" == "$after" ]] || die 'Plugin restoration changed lazy-lock.json; inspect it before proceeding.'
        printf '%s\n' "$fingerprint" > "$STATE_DIR/editor.sha256"
    fi
}

case ${1:-} in
    packages) install_packages ;;
    toolchains) install_toolchains ;;
    plugins) install_plugins ;;
    shell) set_fish_login_shell "$BREW_PREFIX/bin/fish" /etc/shells ;;
    finish)
        /bin/bash "$REPO_ROOT/scripts/bootstrap/verify.sh"
        /bin/bash "$REPO_ROOT/scripts/bootstrap/record-state.sh" ;;
    *) die 'Usage: reconcile.sh packages|toolchains|plugins|shell|finish' ;;
esac
