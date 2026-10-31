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
5. Resolve unmanaged Alacritty/fonts. Homebrew's `--adopt` is appropriate only
   when every existing artifact is identical to the selected cask's artifacts.
   For different versions, review and back up the application/font files before
   a deliberate replacement. Never use an automatic force overwrite.
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
