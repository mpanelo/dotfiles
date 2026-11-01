# Maintenance

For installation and manual checks, use the [README](../README.md).

## Edit configuration

```sh
chezmoi edit ~/.config/fish/config.fish
chezmoi diff
chezmoi apply
```

A full apply also reconciles packages, toolchains, and plugins. Use full applies
for provisioning. Review changes before committing and pushing them.

To import an intentional edit made directly to a deployed file:

```sh
chezmoi re-add ~/.config/fish/config.fish
```

Add new managed files to `manifests/config-files.tsv` for conflict checks and backups.
The standalone installer starts at a detached commit; create a branch before editing.

## Update another Mac

From a clean dotfiles checkout:

```sh
git switch main
git pull --ff-only
chezmoi diff
chezmoi apply
```

Resolve local edits before updating.

## Ownership and upgrades

| What | Source |
| --- | --- |
| Configuration | `home/`, selected by `.chezmoiroot`; deployed as regular files |
| Homebrew packages and fonts | Root `Brewfile` |
| Tool versions, installers, and checksums | `manifests/` |
| Alacritty and Tree-sitter CLI | Official binaries with pinned SHA-256 checksums |
| Neovim plugins | `home/dot_config/nvim/lazy-lock.json` |
| Fish plugins | `home/dot_config/fish/fish_plugins` |
| tmux plugins | `manifests/tmux-plugins.tsv` |

Homebrew installs missing packages without routine upgrades or cleanup. Review
version and plugin changes separately, testing on one Mac before the other.
State, credentials, caches, and plugin checkouts stay outside Git.

Go uses Homebrew with native toolchain selection; Rust uses rustup. Declared pins
provide the defaults, and project toolchain files retain control.

Language servers and formatters are installed directly, outside Mason: Go/Rust
support, Lua LS, StyLua, BasedPyright, and Ruff. fnm installs no Node versions;
BasedPyright's uv environment owns its private Python and Node runtimes.
Python and Lua support editor tooling; no frontend toolchain is provisioned.

Keep the managed Alacritty app in `~/Applications`; its CLI link is in
`~/.local/bin`. An existing Homebrew-managed app stays in `/Applications`.
First-launch approval, Git/SSH identity, and application logins remain manual.

## Logs and Homebrew caveats

Private run records are in `~/.local/state/dotfiles/runs/`, including installer
output, `brew-info.txt`, package inventories, and the prior login shell.

Fish already handles Homebrew PATH, ssh-copy-id, and fzf integration. Review other
caveats before running commands or starting services. Check logs for private data
before sharing them.

## Recovery

Review the error and [run logs](#logs-and-homebrew-caveats), then rerun
`./bootstrap.sh`. Completed stages are reconciled again. Bootstrap has no automatic
rollback; installed software can remain after a failure.

For conflicts, compare and back up the reported files before resolving ownership.
Preserve unrelated files, local edits, and any symlink targets; never bypass
ownership records or remove whole configuration directories to make setup pass.

Create a configuration backup with:

```sh
./scripts/bootstrap/backup.sh --create
```

Backups in `~/.local/state/dotfiles/backups/` contain declared files, link metadata,
checksums, and absent paths. They exclude histories, credentials, Fish universal
variables, plugins, and sessions; keep a normal system backup too.

Restore files selectively after preserving newer edits. Restore links only when
their targets exist, and remove newly created paths only if they are unchanged
migration output. Restoring configuration does not uninstall software.

## Testing

From the repository:

```sh
python3 tests/test_bootstrap.py
shellcheck -x bootstrap.sh install.sh scripts/bootstrap/*.sh tests/run-isolated.sh
tests/run-isolated.sh --smoke
```

The integration test applies only to temporary fixtures and uses copied plugin
caches. If chezmoi is missing, add `--download-chezmoi` for a checksum-verified
temporary executable. These tests do not validate fresh package installation,
live LSP attachment, or GUI rendering.

On the target Mac, check fonts/icons, bindings, clipboard, Fish integrations,
and tmux battery status only on laptops. Verify Neovim completion, diagnostics,
and formatting in Go, Rust, Lua, and Python, with BasedPyright working without
general-purpose Node. A resumed install is not a clean-Mac test.
