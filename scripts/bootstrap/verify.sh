#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/bootstrap/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=scripts/bootstrap/alacritty.sh
source "$REPO_ROOT/scripts/bootstrap/alacritty.sh"
# shellcheck source=scripts/bootstrap/login-shell.sh
source "$REPO_ROOT/scripts/bootstrap/login-shell.sh"
bootstrap_path
require_command jq

editor_check() {
    export DOTFILES_REPO_ROOT="$REPO_ROOT"
    DOTFILES_VERIFY_ONLY=1 nvim --headless -c 'lua local ok, err = pcall(dofile, vim.env.DOTFILES_REPO_ROOT .. "/scripts/bootstrap/verify-editor.lua"); if not ok then io.stderr:write(tostring(err) .. "\n"); vim.cmd("cquit 1") end' -c 'qa!'
}
if [[ ${1:-} == --editor-only ]]; then editor_check; exit; fi
[[ $# == 0 ]] || die 'Usage: verify.sh [--editor-only]'

log 'Checking core executable ownership and versions'
for tool in chezmoi fish tmux starship nvim git delta lazygit ssh-copy-id bat eza fd rg fzf zoxide direnv http tldr jq uv fnm workmux lua-language-server stylua luarocks; do
    require_command "$tool"
    resolved=$(command -v "$tool")
    [[ "$resolved" == "$BREW_PREFIX/"* ]] || die "Unexpected owner for $tool: $resolved"
done
for tool in gopls goimports gofumpt; do
    [[ $(command -v "$tool") == "$HOME/go/bin/$tool" ]] || die "Unexpected owner for $tool"
done
for tool in rustup rustc cargo rust-analyzer rustfmt cargo-clippy tree-sitter; do
    [[ $(command -v "$tool") == "$HOME/.cargo/bin/$tool" ]] || die "Unexpected owner for $tool"
done
for tool in basedpyright basedpyright-langserver ruff; do
    [[ $(command -v "$tool") == "$HOME/.local/bin/$tool" ]] || die "Unexpected owner for $tool"
done
[[ $(GOTOOLCHAIN="go$(version go)" "$BREW_PREFIX/bin/go" version) == "go version go$(version go) darwin/"* ]] || die 'Go baseline mismatch.'
[[ $(rustc --version) == "rustc $(version rust) "* ]] || die 'Rust version mismatch.'
[[ $(tree-sitter --version) == "tree-sitter $(version tree-sitter-cli)"* ]] || die 'Tree-sitter CLI mismatch.'
while read -r tool _module pin; do
    [[ -n "$tool" && "$tool" != \#* ]] || continue
    [[ $(GOTOOLCHAIN=local "$BREW_PREFIX/bin/go" version -m "$HOME/go/bin/$tool" | awk '$1 == "mod" {print $3; exit}') == "$pin" ]] || die "$tool version mismatch."
done < "$REPO_ROOT/manifests/go-tools.tsv"
for tool in basedpyright ruff; do
    actual=$("$UV_TOOL_DIR/$tool/bin/python" -I -c 'import importlib.metadata as m,sys; print(m.version(sys.argv[1]))' "$tool")
    [[ "$actual" == "$(version "$tool")" ]] || die "$tool version mismatch."
done
actual=$("$UV_TOOL_DIR/basedpyright/bin/python" -I -c 'import importlib.metadata as m; print(m.version("nodejs-wheel-binaries"))')
[[ "$actual" == "$(version nodejs-wheel-binaries)" ]] || die 'BasedPyright private Node mismatch.'
# Hide Homebrew/fnm Node to prove that the language server's private runtime works.
PATH=/usr/bin:/bin "$HOME/.local/bin/basedpyright" --version

log 'Checking package declarations, font/application presence and shell syntax'
"$BREW_PREFIX/bin/brew" bundle check --file="$REPO_ROOT/Brewfile"
app=$(alacritty_app)
[[ -d "$app" ]] || die 'Alacritty application is missing.'
if [[ "$app" != /Applications/Alacritty.app ]]; then
    alacritty_is_managed || die 'Alacritty application differs from its ownership record.'
    [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist") == "$(version alacritty)" ]] || die 'Alacritty version mismatch.'
    [[ -L "$HOME/.local/bin/alacritty" && $(readlink "$HOME/.local/bin/alacritty") == "$app/Contents/MacOS/alacritty" ]] || die 'Alacritty CLI link is missing or redirected.'
fi
for entry in alacritty alacritty-direct; do
    infocmp "$entry" >/dev/null 2>&1 || die "Missing terminfo: $entry"
done
font_found=0
for font in "$HOME/Library/Fonts/"*JetBrains*"Nerd"*.ttf; do
    [[ ! -f "$font" ]] || font_found=1
done
((font_found)) || die 'JetBrainsMono Nerd Font was not found.'
while IFS= read -r file; do fish --no-config --no-execute "$file"; done < <(find "$HOME/.config/fish" -name '*.fish' -type f)
editor_check
verify_fish_login_shell
log 'Core checks passed. Complete the visual and interactive checks in docs/bootstrap.md.'
