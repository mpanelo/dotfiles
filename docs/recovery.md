# Recovery and migration

## Resume a failed installation

Review the error, update to a reviewed fix if needed, then rerun from the checkout:

```sh
./bootstrap.sh
```

Completed stages are checked again. A failure can leave installed software behind;
bootstrap has no automatic rollback. Keep logs in `~/.local/state/dotfiles/runs/`.

| Error | Action |
| --- | --- |
| Configuration, symlink, or app/font conflict | Compare the reported path and back it up before resolving it. No force-overwrite flag exists. |
| Alacritty falls back to Menlo | Fully quit Alacritty and restart. If it persists, check the configured family is enabled in Font Book; installed files alone do not prove availability. |
| Old Tree-sitter `rquickjs_macro` build failure | Update and rerun; bootstrap now uses an official precompiled CLI. |
| Blink `mis-aligned LINKEDIT string pool` | Update and rerun; bootstrap detects an unloadable matcher and rebuilds it with stripping disabled. |
| Old lazy.nvim assertion with an empty/truncated lockfile | Use the repair below, then rerun. |

For the known lazy.nvim lockfile failure:

```sh
./scripts/bootstrap/repair-editor-lock.sh
./bootstrap.sh
```

Repair backs up the damaged file and restores only an empty lockfile or the exact
`{` plus newline fragment. Other differences and symlinks are refused.
Do not delete plugin checkouts, Cargo caches, or configuration directories to
resolve these failures. Do not change macOS security settings.

## Back up configuration

Before an existing-Mac handoff, run:

```sh
./scripts/bootstrap/backup.sh --create
```

For legacy links, pass `--legacy-root` with the absolute path to the retained
original checkout containing their targets.

The current source no longer includes the legacy component directories. Keep
the original checkout or a private archive until the handoff and rollback review
are complete; Git history retains the retired tracked files.

The command leaves live files intact and prints a private backup directory under
`~/.local/state/dotfiles/backups/`. Review `files/`, `links/`, `files.sha256`, and
`absent.txt` before proceeding. Unknown links and unsafe paths are refused.

Only declared configuration is saved. Keep your normal system backup and preserve
the original checkout and runtime state: histories, Fish universal variables,
credentials, plugin data, and sessions are excluded.

## Existing-Mac handoff

After the Studio passes the [interactive checks](bootstrap.md#remaining-clean-mac-checks):

1. Close affected apps and handle active tmux sessions.
2. Back up configuration and compare local edits with the managed source.
3. Move only recognized legacy links into a private holding directory. Preserve
   their targets and unrelated files; never delete whole config directories.
4. Resolve unmanaged apps/fonts and executable PATH conflicts. Keep existing
   Homebrew-managed Alacritty. Font adoption requires identical cask artifacts;
   otherwise back up and review replacement. Preserve unrelated toolchains.
5. Run `./bootstrap.sh --check`. Once conflicts are resolved, run bootstrap and
   complete the interactive checks.

Complete this handoff before advancing a legacy checkout to the current layout.
Original link targets must remain available separately until migration is verified.
Bootstrap does not remove those links.

## Restore the prior configuration

Close affected apps. Preserve newer edits before moving any newly deployed files
aside. Restore old links from the holding directory or backup's `links/` tree,
restoring their original targets from the retained checkout or archive first.
Restore regular files from `files/` only after comparing them with current files.

Use `absent.txt` to identify previously missing paths; remove a new file only if
it is unchanged migration output. Check link targets and bindings afterward.
Configuration restoration does not uninstall packages or restore excluded state.

## Start fresh or remove installed software

For a truly clean test, save needed files and logs elsewhere, then use a disposable
macOS VM snapshot or, **on the test Studio only**, System Settings → General →
Transfer or Reset → Erase All Content and Settings. This erases user data and apps;
do not restore the old environment during Setup Assistant. See
[Apple's instructions](https://support.apple.com/en-us/102664).
A new account still shares Homebrew and is not a clean system.

For selective cleanup instead:

1. Restore the prior registered login shell before removing Fish. If it was zsh,
   run `chsh -s /bin/zsh` and open a new login session.
2. Compare package inventories with the private pre-install records. Remove only
   reviewed additions; uninstall casks while Homebrew still works, without `--zap`.
3. Remove Homebrew itself only if it was absent beforehand and nothing else needs
   it. Review the [official uninstaller](https://docs.brew.sh/FAQ#how-do-i-uninstall-homebrew)
   and its `--dry-run` before running it interactively against the native prefix.
4. Review remaining owned apps, tools, links, and shell changes individually. Remove
   an added Fish `/etc/shells` entry only after all accounts have switched away.

Selective cleanup is not a factory reset. Keep personal files, unrelated packages,
and Command Line Tools; never delete entire `~/.config`, `~/.cargo`, or `~/go` trees.
