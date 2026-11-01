# Mauricio's dotfiles

A macOS development environment for Apple Silicon: Fish, Alacritty, tmux,
Neovim, Starship, Go, and Rust. chezmoi manages configuration; Homebrew
installs the core packages.

## Set up a new Mac

Use a normal account, without sudo. In Bash or zsh, replace the placeholder
with a reviewed, published 40-character commit hash:

```sh
revision=REVIEWED_40_CHARACTER_COMMIT
base=https://raw.githubusercontent.com/mpanelo/dotfiles
/bin/bash -c "$(curl -fsSL "$base/$revision/install.sh")" -- "$revision"
```

This creates the source checkout at `~/.local/share/chezmoi` and provisions
the environment. Complete any Command Line Tools dialog, then rerun the command.

From an existing checkout, run:

```sh
./bootstrap.sh
```

Bootstrap installs missing tools, applies configuration and pinned plugins,
makes Fish the account's login shell, and runs automated checks. It stops on
conflicting files rather than overwriting them. To check conflicts without
installing or applying anything:

```sh
./bootstrap.sh --check
```

A passing `--check` means installation is safe to attempt, not that tools work.
For an existing Mac, follow the [migration guide](docs/recovery.md#existing-mac-handoff)
first. Keep the MacBook's original configuration until the Studio passes testing.

## After bootstrap succeeds

1. Open `~/Applications/Alacritty.app` and complete any macOS app approval.
   An existing Homebrew-managed Alacritty is kept in `/Applications`.
2. Use a new terminal session to pick up Fish. Check the prompt, font,
   shortcuts, clipboard, and tmux sessions.
3. Test completion, diagnostics, and formatting in Neovim with Go, Rust, Lua,
   and Python files. See [interactive checks](docs/bootstrap.md#remaining-clean-mac-checks).
4. Set up Git identity, SSH/GitHub authentication, and application logins.
5. Review [Homebrew caveats](docs/bootstrap.md#homebrew-output-and-follow-up-instructions),
   rerun bootstrap, and restart the Mac to confirm everything still works.

The detailed `provisioning-checklist.local.md` is intentionally ignored by Git;
copy it separately to the Studio if needed.

## Installed tools

- Terminal: Fish, Alacritty, tmux, Starship, JetBrainsMono Nerd Font.
- Development: Neovim, Go, rustup, and directly managed language servers and
  formatters for Go, Rust, Lua, and Python. No Mason installation.
- CLI tools: the curated [Brewfile](Brewfile), including Fish integrations.
- Node: fnm is installed **without Node**. BasedPyright uses a private Node
  runtime in its uv environment. No frontend toolchain is installed.

See the [tooling decisions](docs/macos-development-environment-plan.md) for
scope and ownership. Versions and plugin revisions live in [manifests](manifests/).

## Maintain your configuration

```sh
chezmoi edit ~/.config/fish/config.fish
chezmoi diff
chezmoi apply
```

A full apply also reconciles packages, toolchains, and plugins. Review and commit
source changes, then fetch, review, and apply them on the other Mac. Updates
never commit or push automatically. See [maintenance](docs/bootstrap.md#applying-future-changes).

## Reference

- [Maintenance, logs, and testing](docs/bootstrap.md)
- [Failures, backups, and migration](docs/recovery.md)
- [Keybindings and command notes](cheatsheet.md)
