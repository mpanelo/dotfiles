# Mauricio's dotfiles

macOS development environment for Apple Silicon: Fish, Alacritty, tmux,
Neovim, Starship, Go, and Rust. chezmoi manages configuration; Homebrew
installs core packages from the [Brewfile](Brewfile).

## Set up a new Mac

Run in Bash or zsh as your normal user. Use a reviewed, published full commit hash:

```sh
revision=REVIEWED_40_CHARACTER_COMMIT
base=https://raw.githubusercontent.com/mpanelo/dotfiles
/bin/bash -c "$(curl -fsSL "$base/$revision/install.sh")" -- "$revision"
```

The installer creates `~/.local/share/chezmoi`, installs tools, applies
configuration and pinned plugins, sets Fish as the login shell, and verifies
setup. Complete installer prompts or Command Line Tools dialogs as needed.

From an existing checkout:

```sh
./bootstrap.sh
```

To check for conflicts without installing or applying:

```sh
./bootstrap.sh --check
```

This checks installation conflicts, not tool behavior. Existing dotfiles or
unmanaged apps/fonts may need a reviewed [handoff](docs/recovery.md#existing-dotfiles).

## After setup

1. Open `~/Applications/Alacritty.app` and complete any macOS approval. Keep the
   app there; add it to the Dock instead of moving it. Existing Homebrew-managed
   Alacritty stays in `/Applications`.
2. In a new terminal, check Fish, prompt/icons, shortcuts, clipboard, and tmux.
   Check Neovim completion, diagnostics, and formatting in Go, Rust, Lua, and Python.
3. Set up Git identity, SSH/GitHub authentication, and application logins.
4. Review [Homebrew caveats](docs/bootstrap.md#logs-and-homebrew-caveats), rerun
   bootstrap, then restart and confirm the environment still works.

The optional detailed checklist, `provisioning-checklist.local.md`, stays local.

## Reference

- [Maintenance, ownership, and testing](docs/bootstrap.md)
- [Conflicts, backups, and recovery](docs/recovery.md)
- [Tooling decisions](docs/macos-development-environment-plan.md)
- [Keybindings and command notes](cheatsheet.md)
