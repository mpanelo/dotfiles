# Mauricio's dotfiles

macOS development environment for Apple Silicon: Fish, Alacritty, tmux,
Neovim, Starship, Go, and Rust. chezmoi manages configuration; Homebrew
installs core packages from the [Brewfile](Brewfile).

## Set up a new Mac

Run in Bash or zsh as your normal user. Use a reviewed, published full commit hash:

```sh
revision=REVIEWED_40_CHARACTER_COMMIT
/bin/bash -c "$(curl -fsSL "https://raw.githubusercontent.com/mpanelo/dotfiles/$revision/install.sh")" -- "$revision"
```

The installer checks out that revision at `~/.local/share/chezmoi` and prepares
Command Line Tools, Homebrew, and Homebrew-managed chezmoi. Bootstrap installs
tools, applies configuration and pinned plugins, sets Fish as the login shell,
and verifies setup. Complete dialogs and rerun when instructed.

From an existing checkout:

```sh
./bootstrap.sh
```

Bootstrap checks for conflicts before installing or applying. For existing
dotfiles or unmanaged apps/fonts, see [recovery](docs/bootstrap.md#recovery).

## Reference

- [Maintenance, recovery, and testing](docs/bootstrap.md)
- [Keybindings and command notes](cheatsheet.md)
