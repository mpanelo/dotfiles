# Tooling and migration decisions

This records the agreed design. Use the [README](../README.md) for setup,
[maintenance guide](bootstrap.md) for updates, and [recovery guide](recovery.md)
for failures and existing-Mac migration.

## Core tooling

| Area | Tools | Installation |
| --- | --- | --- |
| Provisioning | Homebrew, chezmoi | Official installer, then Homebrew |
| Terminal | Fish, Alacritty, tmux, Starship | Homebrew; official Alacritty DMG |
| Font | JetBrainsMono Nerd Font | Homebrew cask; preserve configured family and size |
| Editor | Neovim, LuaRocks | Homebrew |
| Search/navigation | fd, ripgrep, fzf, zoxide | Homebrew |
| Shell/Unix | bat, eza, HTTPie, tlrc, direnv, jq | Homebrew |
| Git workflow | Git, git-delta, lazygit, ssh-copy-id, workmux | Homebrew; trust only the workmux formula |
| Go | Go, gopls, goimports, gofumpt | Homebrew base Go and native Go tooling |
| Rust | rustup, rustc, Cargo, rust-analyzer, rustfmt, Clippy, rust-src | Official rustup |
| Lua editing | Lua language server, StyLua | Homebrew |
| Python editing | BasedPyright, Ruff | Isolated uv tool environments |
| Node manager | fnm, without a Node version | Homebrew |
| Editor infrastructure | Tree-sitter CLI; pinned Fish, tmux, and Neovim plugins | Official CLI binary and repository manifests/lockfiles |

Command Line Tools provide Git and native build tools. uv supplies the Python
runtime needed by editor tooling; Python is not an additional development
language in this setup.

Language servers and formatters are managed directly, outside Mason. Preserve
existing appearance, bindings, plugins, and Fish integrations. Exclude shfmt,
tmux-sessionx, Agent Workbench, cloc, wget, and unrelated a la carte tools.
Exclusion never means uninstalling existing software.

## Node and version policy

- fnm starts with no Node version and never installs one automatically.
- BasedPyright's uv environment owns its private Node runtime. It works without
  exposing general-purpose Node/npm or depending on fnm. No frontend tooling is
  installed; existing JavaScript/TypeScript syntax viewing stays available.
- Go uses native toolchain selection and respects project requirements. Rust uses
  a pinned rustup default and respects `rust-toolchain.toml`. No extra manager.
- Pin language tools, runtimes, plugins, and official binary checksums in manifests.
  Homebrew selects packages without routine upgrades; it does not lock versions.

## Bootstrap and migration

1. Check for conflicts, install prerequisites, then initialize chezmoi.
2. Install core packages and pinned toolchains before applying configuration.
3. Restore pinned plugins, build native editor support, set Fish as the login
   shell, verify tools, and record ownership for safe retries.
4. Validate the Studio interactively, then perform a separately reviewed MacBook
   handoff. Retire legacy directories only after both Macs use the new layout.

The source lives in `home/`, selected by `.chezmoiroot`. Deploy regular files;
leave histories, credentials, caches, session data, and plugin checkouts outside
Git. The retired component directories and installers are removed; preserve an
older checkout separately while any Mac still depends on its legacy links.

Bootstrap can resume partial installation but cannot undo every installer change.
Unknown files, local edits, links, and unmanaged apps/fonts require review.
Gatekeeper, quarantine, credentials, and macOS security settings stay untouched.

## Manual setup

Account setup, administrator prompts, Command Line Tools dialogs, first Alacritty
launch approval, Git identity/authentication/signing, and application logins remain
manual. macOS preference automation is outside this bootstrap.
