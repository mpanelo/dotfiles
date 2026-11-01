# Mauricio's dotfiles

A macOS development environment managed with chezmoi and Homebrew,
primarily for Apple Silicon. Fish, Alacritty, tmux, Neovim, and Starship
provide the terminal workflow; Go and Rust are the development
toolchains.

The bootstrap and configuration have passed isolated tests on the
reference MacBook. Full provisioning on clean macOS, live
language-server attachment, and visual acceptance checks remain to be
completed.

## Set up a new Mac

Use a normal macOS account with internet access. Homebrew installation
may request administrator authentication; do not run bootstrap with
sudo.

Choose a reviewed, published commit and run this in Bash or zsh:

```sh
revision=REVIEWED_40_CHARACTER_COMMIT
base=https://raw.githubusercontent.com/mpanelo/dotfiles
/bin/bash -c "$(curl -fsSL "$base/$revision/install.sh")" -- "$revision"
```

Replace the placeholder with the full commit hash. The launcher checks
out that revision under `~/.local/share/chezmoi`, installs Homebrew and
chezmoi when needed, and runs the provisioning stages. If Command Line
Tools need a system dialog, finish it and rerun the same command.

From an existing checkout, check for installation conflicts:

```sh
./bootstrap.sh --check
```

The check reports platform/path compatibility, existing configuration
and symlink conflicts, and unmanaged app/font installations. It also
reports whether Command Line Tools, Homebrew, and chezmoi are present.
A pass means no blocking conflicts were found; tools can still be
missing. It does not verify installed versions, LSPs, or network access.

To install the core tools and apply the configuration:

```sh
./bootstrap.sh
```

Alacritty installs from a pinned, checksum-verified official GitHub DMG
into `~/Applications/Alacritty.app`, with a CLI link in `~/.local/bin`.
Homebrew's Alacritty cask is disabled; an existing Homebrew-managed app
is kept. Bootstrap preserves quarantine and macOS security settings.
macOS may require manual app approval on first launch.

After the configuration and plugins are installed, bootstrap registers
Homebrew Fish in `/etc/shells` if needed and uses `chsh` to make it the
current account's login shell. Authentication may be requested. Open a
new terminal/login session to use it; existing sessions keep running.
Git identity, authentication, and application logins remain manual.

Homebrew output, caveats, package inventories, and the prior login shell
are saved privately in `~/.local/state/dotfiles/runs/`.
Review optional package setup instructions there; bootstrap does not
blindly append recommendations to shell configuration. See the
[recovery guide](docs/recovery.md) for cleanup and clean-machine resets.

## Existing Macs

Preflight refuses unexpected files, symlinks, local edits, and unmanaged
Alacritty or font installations. Follow the [recovery and migration
guide](docs/recovery.md) to compare and back up existing configuration
before a handoff.

The original `fish/`, `alacritty/`, `tmux/`, and `nvim/` directories
remain intact during migration. Do not rename or delete them while live
links point into them. The old component installers and
`macos/brew/Brewfile` are legacy paths; the new bootstrap uses the root
`Brewfile` and `home/`.

## Core environment

| Area | Tools |
| --- | --- |
| Provisioning | chezmoi, Homebrew |
| Terminal | Fish, Alacritty, tmux, Starship |
| Font | JetBrainsMono Nerd Font, managed as a Homebrew cask |
| Search and navigation | fd, ripgrep, fzf, zoxide |
| Unix commands | bat, eza, HTTPie, tlrc, jq, direnv |
| Git workflow | Git, git-delta, lazygit, ssh-copy-id, workmux |
| Go | Go, gopls, goimports, gofumpt |
| Rust | rustup, Cargo, rust-analyzer, rustfmt, Clippy, rust-src |
| Lua editing | lua-language-server, StyLua |
| Python editing | BasedPyright, Ruff, isolated through uv |
| Editor support | Tree-sitter CLI, LuaRocks, pinned plugins |
| Node manager | fnm, without an installed Node version |

See the [Brewfile](Brewfile) for the package list and [version
manifest](manifests/versions.json) for pinned tool versions. Language
servers and formatters are installed directly by the bootstrap, outside
Mason.

BasedPyright's uv environment includes its private Node runtime. It does
not provide general-purpose Node or npm on PATH. fnm is available for
future on-demand use, without automatic Node installation. No frontend
toolchain is provisioned; existing JavaScript/TypeScript syntax viewing
in Neovim is retained. shfmt and tmux-sessionx are excluded from the new
managed configuration.

## Repository layout

```text
.chezmoiroot          Selects home/ as the chezmoi source state
Brewfile             Core Homebrew formulae, casks, and taps
bootstrap.sh         Provisioning entry point for a local checkout
install.sh           Standalone launcher for a reviewed commit
home/                Managed configuration and ordered chezmoi scripts
manifests/           Tool versions, plugin pins, and file inventory
scripts/bootstrap/   Preflight, installation, backup, and verification
tests/               Offline checks and isolated application tests
docs/                Setup, design decisions, and recovery guidance
```

chezmoi deploys regular files into the home directory. Plugin checkouts,
caches, histories, Fish universal variables, session snapshots, and
credentials stay outside the managed source.

## Maintain and sync changes

Edit a managed configuration, review the diff, and apply it:

```sh
chezmoi edit ~/.config/fish/config.fish
chezmoi diff
chezmoi apply
```

A full apply also reconciles declared packages, toolchains, and plugins.
For an intentional live edit, use `chezmoi re-add` on that specific file
after reviewing it. When adding a managed file, update
`manifests/config-files.tsv` so conflict detection and backups cover it.

Commit and push reviewed source changes. On another Mac, fetch and
review the intended revision before advancing its source checkout and
applying. The standalone launcher starts at a detached commit; create a
branch before making source commits. Automatic commits and pushes are
disabled.

Routine reconciliation restores pinned tool/plugin versions and uses
Homebrew's `--no-upgrade` mode. Deliberate upgrades are separate changes
to validate on one Mac before propagating to another. Homebrew remains a
rolling package manager; a Brewfile does not lock application versions.
Bootstrap does not automatically uninstall packages, clean up unrelated
files, or change macOS security settings.

## Test without changing live configuration

Run the offline safety and source checks:

```sh
python3 tests/test_bootstrap.py
```

Run real chezmoi deployment checks in temporary directories:

```sh
tests/run-isolated.sh --download-chezmoi
```

Add `--smoke` to test existing Fish, tmux, and Neovim binaries with
copies of their cached, pinned plugins. This requires matching plugin
caches:

```sh
tests/run-isolated.sh --download-chezmoi --smoke
```

The download option obtains a pinned, checksum-verified test executable
and removes it afterward. Use `--chezmoi /path/to/chezmoi` instead to
avoid downloading. The harness isolates source, HOME, destination,
cache, and state; provisioning hooks are disabled and installers are
blocked. tmux runs on a private socket with session restore/save
disabled.

These checks cover configuration deployment and application behavior.
Full package installation, LSP attachment, fonts, clipboard integration,
and session persistence still need acceptance testing on clean macOS.

## Further reading

- [Bootstrap and maintenance](docs/bootstrap.md)
- [Conflict handling and recovery](docs/recovery.md)
- [Migration plan](docs/macos-development-environment-plan.md)
- [Keybindings and command notes](cheatsheet.md)
