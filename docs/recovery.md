# Recovery

## Resume a failed installation

Review the error and the [run logs](bootstrap.md#logs-and-homebrew-caveats), then rerun:

```sh
./bootstrap.sh
```

Bootstrap preserves conflicting files and can resume completed stages. It has no
automatic rollback; installed software can remain after a failure.

## Common problems

| Problem | Action |
| --- | --- |
| File, symlink, app, or font conflict | Compare the reported path, back it up, and resolve ownership before retrying. Do not bypass ownership records. |
| Alacritty moved into `/Applications` | Return the verified managed app to `~/Applications`; leave an existing Homebrew-managed app in place. |
| Font falls back to Menlo | Fully quit Alacritty and restart the Mac. If it persists, check the configured family in Font Book. |
| Colors missing with `NO_COLOR` set | Clear it in Fish with `set -eg NO_COLOR`. Fully quit and relaunch Alacritty from Finder if new windows inherit it. |
| Empty or known truncated Neovim lockfile | Run `./scripts/bootstrap/repair-editor-lock.sh`, then bootstrap. Repair backs up the damaged file and refuses other differences. |

Preserve unrelated files and toolchains. Do not delete whole configuration/cache
directories or change macOS security settings to fix an installation.

## Configuration backups

```sh
./scripts/bootstrap/backup.sh --create
```

Backups go into `~/.local/state/dotfiles/backups/`. They contain declared files,
link metadata, checksums, and a list of absent paths. Histories, credentials,
Fish universal variables, plugin data, and sessions are excluded; keep a normal
system backup too.

To restore, close affected apps and preserve newer edits. Compare current files
with `files/`, restore regular files selectively, and restore links from `links/`
only when their original targets are available. Use `absent.txt` to identify newly
created paths; remove only unchanged migration output. This does not uninstall software.

## Existing dotfiles

Before updating a Mac that still uses legacy links:

1. Preserve the original checkout separately. Pass its absolute path with
   `backup.sh --create --legacy-root` when backing up linked configuration.
2. Review local edits and move recognized links into a private holding directory.
3. Resolve app/font ownership and executable PATH conflicts.
4. Run `./bootstrap.sh --check`, then bootstrap once conflicts are resolved.
5. Complete the [manual checks](../README.md#after-setup) before removing backups.

Keep the original link targets available until migration is verified. The current
checkout no longer includes legacy component directories; tracked copies remain
in Git history.
