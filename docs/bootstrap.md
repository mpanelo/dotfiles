# Maintenance and testing

For installation, use the [README](../README.md#set-up-a-new-mac).

## Installation conflict checks

`./bootstrap.sh --check` checks existing configuration, symlinks, runtime paths,
app/font conflicts, and prerequisites. Missing tools are expected on a new Mac.
It does not test network access, authentication, tool behavior, or rendering.

Normal provisioning prints one initial result. Hooks and stages repeat the
checks silently so they are safe to run independently; errors always appear.
Conflicts stop provisioning. See [recovery](recovery.md) before moving files.

## Remaining clean-Mac checks

Automated checks run at the end of bootstrap. Test these interactively afterward:

- **Terminal:** Fish starts in a new session; Starship and Nerd Font icons render
  correctly. If Terminal.app forces zsh, select its default login shell setting.
- **Fish:** abbreviations, fzf bindings, direnv, zoxide, and workmux work.
- **tmux:** navigation, clipboard, saved sessions, and Alacritty shortcuts work.
  The Studio should have no battery indicator.
- **Neovim:** completion, search, parsers, bindings, LSP diagnostics, and formatting
  work in Go, Rust, Lua, and Python files. Language tools resolve outside Mason.
- **Node isolation:** fnm has no Node versions on a clean target; general-purpose
  `node`/`npm` are absent, while BasedPyright works.
- **Repeatability:** rerun bootstrap, then restart and check the environment again.

A resumed installation tests recovery; it does not replace a clean-machine test.
Keep the original MacBook setup until these checks pass. The ignored local
checklist has the detailed manual steps.

Bootstrap checks the configured font family through macOS CoreText. Installed
font files alone do not pass verification; actual rendering still needs a look.

## Applying future changes

Edit with `chezmoi edit`, review `chezmoi diff`, then run a full `chezmoi apply`.
This also reconciles core packages, toolchains, and plugins. Targeted applies
are not the supported provisioning workflow.

If you intentionally edited a deployed file, review it before importing it:

```sh
chezmoi re-add ~/.config/fish/config.fish
```

Commit and push reviewed source changes. On another Mac, fetch and review the
revision, advance its source checkout, then apply. The standalone installer
starts at a detached commit; create a branch before making source commits.
Do not reset a checkout with local changes.

To add a managed file, update `manifests/config-files.tsv` as well. Complete the
[handoff](recovery.md#existing-mac-handoff) before updating a Mac using legacy links.

## Ownership and upgrades

| What | Definition or owner |
| --- | --- |
| Configuration | `home/`, selected by `.chezmoiroot`; deployed as regular files |
| Core packages and fonts | Root `Brewfile`; Homebrew owns installation |
| Go baseline and tools | Native Go toolchain selection; `manifests/versions.json` and `manifests/go-tools.tsv` |
| Rust | rustup; version and components declared by bootstrap |
| BasedPyright and Ruff | Isolated uv tools; JSON pins and matching Python constraints |
| Alacritty and Tree-sitter CLI | Official release downloads with pinned SHA-256 values |
| Homebrew/rustup installers | `manifests/installers.tsv` |
| Plugins | `home/dot_config/nvim/lazy-lock.json`, `home/dot_config/fish/fish_plugins`, and `manifests/tmux-plugins.tsv` |

Homebrew uses `--no-upgrade` during reconciliation; it does not lock versions.
Review upgrades separately and test on one Mac before updating the other.

Alacritty's cask is disabled. The official DMG installs into `~/Applications`,
with a CLI link in `~/.local/bin`. Unknown or modified apps are refused;
upgrades need a reviewed replacement. Quarantine and Gatekeeper stay enabled.

State, caches, histories, credentials, and plugin checkouts stay outside Git.
Do not refresh ownership records manually to bypass a conflict.

## Homebrew output and follow-up instructions

Private logs live in `~/.local/state/dotfiles/runs/`. Each run includes installer
output, `brew-info.txt` caveats, package inventories, and the prior login shell.
Review them before sharing; they are not a complete rollback snapshot.

Fish already manages Homebrew PATH, keg-only ssh-copy-id, and fzf integration.
Skip recommendations to append these to zsh/bash profiles or copy example
configs. Assess any other caveats before running commands or starting services.

## Isolated tests

From the repository, run:

```sh
python3 tests/test_bootstrap.py
shellcheck -x bootstrap.sh install.sh scripts/bootstrap/*.sh tests/run-isolated.sh
tests/run-isolated.sh --download-chezmoi
```

The integration test temporarily downloads checksum-verified chezmoi and applies
only to isolated fixtures. Omit `--download-chezmoi` to use chezmoi on PATH.

Add `--smoke` to test existing Fish, tmux, and Neovim binaries using copied,
matching plugin caches. It uses a private tmux socket and does not install
packages or plugins. Keep isolation guards intact; never use live configuration.
These tests do not prove fresh provisioning, LSP attachment, or GUI rendering.
