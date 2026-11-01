# Conflicts, backups, and the existing-Mac handoff

The current Mac's original source directories must remain intact: Fish,
Alacritty, and Neovim currently link directly into them. The new `home/` directory
does not replace those sources until a separately reviewed handoff.

## Reading a preflight failure

Preflight lists paths and conflict reasons without printing configuration values.
It never changes a destination. A directory symlink, dangling symlink, unexpected
file type, local edit, legacy `~/.tmux.conf`, or unmanaged application/font
requires a comparison and an intentional resolution. There is no force flag.

If a previous provisioning run failed after applying some files, rerun the same
bootstrap. Files already identical to the desired source are safe to adopt.
Missing tools and artifacts are rechecked rather than trusting completion stamps.
Review any genuinely divergent file; do not blindly rerun with overwrite flags.

### Recovery from the lazy.nvim lock assertion

An earlier bootstrap seeded detached plugin commits without branch metadata,
then called `Lazy restore`. lazy.nvim expected a branch and could assert after
opening the deployed lockfile for writing. The current bootstrap backfills that
metadata and validates the seeded commits without calling restore.

After pulling the fix, run:

```sh
./scripts/bootstrap/repair-editor-lock.sh
./bootstrap.sh
```

The repair command only replaces an empty deployed lockfile or the exact
`{` plus newline fragment produced by this failure. It first preserves the
damaged file in a private `~/.local/state/dotfiles/backups/editor-lock.*`
directory, then restores the repository's lockfile. Matching files are a no-op;
other differing files and symlinks are refused for manual comparison. It does
not reset plugin repositories, discard valid lockfile changes, or apply other
configuration. A clean-machine reset is unnecessary to resume this failure.

## Failed provisioning, cleanup, and a truly fresh target

Bootstrap is staged, not transactional. A failed `brew bundle` can leave
successfully installed formulae, dependencies and casks behind. There is no
`chezmoi destroy` or generic uninstall command that safely reverses all of it.
Resuming after fixing a failure is supported and tests recovery, but it is not
another clean-machine test.

For a genuinely fresh Mac Studio test, first copy anything you want to keep,
including the uncommitted checklist and failure logs, off the Mac. On the Studio
only, use **System Settings > General > Transfer or Reset > Erase All Content
and Settings** and complete Setup Assistant without restoring the previous apps
or home directory. This erases user data, settings and applications while
retaining the installed macOS version. Follow Apple's
[Erase Assistant instructions](https://support.apple.com/en-us/102664).
For repeated tests, a disposable macOS VM with a pre-provisioning snapshot is
another option. A new user account shares Homebrew and is not a fresh target.
No erase or uninstall operation is performed by bootstrap.

For a narrower development cleanup, when Homebrew was absent before the run and
you have no other Homebrew software to preserve:

1. Switch the account back to its prior registered shell before removing Fish.
   For a new account whose previous shell was zsh, run `chsh -s /bin/zsh` and
   open a new login session. Do not rely on `$SHELL` in an old session to verify
   the account setting; use `dscl . -read "/Users/$(id -un)" UserShell`.
2. Review `/opt/homebrew/bin/brew list --cask --versions`. Uninstall each cask
   known to have been introduced by this run while Homebrew still works. For
   the reported package-stage failure, the installed cask was the Nerd Font:
   `/opt/homebrew/bin/brew uninstall --cask font-jetbrains-mono-nerd-font`.
   This removes its registered font artifacts outside the Homebrew prefix.
   Do not use `--zap`, remove unrelated casks, or delete font directories.
3. Download and review Homebrew's official uninstaller. Run its `--dry-run`
   first, then, only after reviewing the proposed removals, run it interactively
   against the native prefix. Do not force an unattended uninstall:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh -o /tmp/homebrew-uninstall.sh
   /bin/bash /tmp/homebrew-uninstall.sh --path=/opt/homebrew --dry-run
   # Destructive: run only after reviewing the dry-run and saving needed data.
   /bin/bash /tmp/homebrew-uninstall.sh --path=/opt/homebrew
   ```

   Homebrew documents this uninstaller in its
   [FAQ](https://docs.brew.sh/FAQ#how-do-i-uninstall-homebrew). If Homebrew
   existed before bootstrap, do not uninstall the prefix; use the private
   package baselines to review additions, dependent packages, and cask artifacts
   individually. A baseline created after the original failure cannot prove
   what was present before that failure.
4. Review remaining chezmoi initialization/cache/state, source checkouts,
   Homebrew trust metadata and shell-profile additions, if any. Preserve source
   and personal files. The reported failure occurred in the packages hook,
   before language-tool installation and managed dotfile deployment; there is
   no reason to delete all of `~/.config`, `~/.cargo`, or `~/go` for that failure.
   Later-stage failures may also have installed the user-local Alacritty app,
   its CLI/terminfo, uv tools, Go/Rust tools or plugin caches. Review the failed
   stage and known ownership records rather than deleting these directories.
5. If bootstrap registered Fish in `/etc/shells`, remove only its exact added
   line during a deliberate system-file edit after all accounts that use it
   have switched away. Preserve other registered shells. Leave Command Line
   Tools intact unless removal is separately required and reviewed.

This cleanup can make the next run useful for testing package installation, but
it does not prove factory-clean macOS. Bootstrap does not take an OS snapshot,
track every installer side effect, or automatically roll back successful
stages. Private package inventories and logs aid a reviewed cleanup; a saved
system/VM snapshot or erasure is required for a reproducible fresh-state reset.

## Private backup

At the separately authorized handoff, the backup-only command is:

```sh
./scripts/bootstrap/backup.sh --create
```

It prints a newly created private directory under
`~/.local/state/dotfiles/backups/`. Its `files/` tree contains copies of declared
configuration, `links/` preserves directory symlinks, `files.sha256` describes
saved file contents, and `absent.txt` records previously absent destinations.
It does not move, replace, or unlink the live configuration.

Verify a backup's copied files before proceeding:

```sh
backup=THE_PRINTED_BACKUP_DIRECTORY
cd "$backup/files"
shasum -a 256 -c ../files.sha256
```

This is a backup of the declared migration scope, not a full home-directory
backup. It does not read Fish universal variables, traverse plugin checkouts, or
copy credentials, histories, session snapshots, or application databases. Preserve
those original directories and maintain your normal system backup. In particular,
leave the old Fish directory and its ignored universal-variable file untouched;
extract selected preferences only after a private review.

## Handoff procedure

After the Mac Studio passes acceptance checks:

1. Close Alacritty, Fish sessions, and Neovim; deal with active tmux sessions
   intentionally rather than reconfiguring a running server during setup.
2. Create and verify a private backup. Record which paths were links and retain
   the original checkout and application-generated state.
3. Compare source versus live configuration and reconcile selected local edits.
4. Move only the known directory/file links into a private holding directory.
   Do not recursively delete their target directories. Keep unrelated files in
   real directories such as `~/.config/tmux` in place.
5. Resolve unmanaged Alacritty/fonts. Keep existing Homebrew-managed Alacritty;
   its disabled cask is no longer installed by bootstrap. Unknown apps in either
   Applications directory need a reviewed handoff before the user-local DMG
   installation. For fonts, Homebrew's `--adopt` is appropriate only when every
   existing artifact is identical to the selected cask's artifacts. Otherwise,
   review and back up the files before a deliberate replacement. Never force
   an overwrite. A modified managed Alacritty app also stops provisioning;
   compare it before moving it aside for an intentional reinstall or upgrade.
6. Review executable ownership, especially any standalone uv that would shadow
   Homebrew uv in `~/.local/bin`. Preserve unrelated Go/Cargo/Node installations;
   resolve PATH conflicts intentionally instead of uninstalling them.
7. Run read-only preflight again. Only after it passes, perform the reviewed
   bootstrap/apply and the interactive acceptance checks.

The handoff is deliberately not automated by a script that removes live links.
It remains a separate operation after clean-machine validation.

## Restoring the prior setup

Stop affected applications. Compare any new files against their last recorded
hashes before moving them to another private holding directory; retain edits made
since the migration. Restore the old links from the holding directory or the
backup's `links/` tree, keeping their original source checkout available. Restore
regular managed files from `files/` only after checking for newer edits. Paths in
`absent.txt` should become absent only when the new file is known to be the
migration's unchanged output.

If an original source file has been lost, the backup's `files/` copy can recover
that declared file. It does not recover excluded runtime state. Do not run a
blanket recursive restore or deletion against the whole configuration directory.

Validate link targets, settings, and keybindings before reopening normal work.
Homebrew installations are separate from configuration rollback; do not run
automatic cleanup or uninstall software as a recovery step.
