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

Resolve local edits before updating. For legacy symlinks, complete the
[handoff](recovery.md#existing-dotfiles) first.

## Ownership and upgrades

| What | Source |
| --- | --- |
| Configuration | `home/`, selected by `.chezmoiroot`; deployed as regular files |
| Homebrew packages and fonts | Root `Brewfile` |
| Tool versions, installers, and checksums | `manifests/` |
| Neovim plugins | `home/dot_config/nvim/lazy-lock.json` |
| Fish plugins | `home/dot_config/fish/fish_plugins` |
| tmux plugins | `manifests/tmux-plugins.tsv` |

Homebrew installs missing packages without routine upgrades or cleanup. Review
version and plugin changes separately, testing on one Mac before the other.
State, credentials, caches, and plugin checkouts stay outside Git.

## Logs and Homebrew caveats

Private run records are in `~/.local/state/dotfiles/runs/`, including installer
output, `brew-info.txt`, package inventories, and the prior login shell.

Fish already handles Homebrew PATH, ssh-copy-id, and fzf integration. Review other
caveats before running commands or starting services. Check logs for private data
before sharing them.

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

On the target Mac, check the [setup checklist](../README.md#after-setup). Confirm
fzf/direnv/zoxide integrations, battery status only on laptops, and BasedPyright
working without general-purpose Node. A resumed install is not a clean-Mac test.
