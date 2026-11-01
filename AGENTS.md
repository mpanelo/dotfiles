# Dotfiles development runbook

This repository provisions a macOS development environment with chezmoi and
Homebrew. Apple Silicon is the primary target. Preserve the existing settings,
keybindings, and plugin functionality when changing how they are installed.

## Scope and permission

- Explain the intended changes, affected files, and meaningful tradeoffs before
  editing. Work within the user's authorized scope; ask before expanding it.
- Repository development does not authorize changing the reference Mac's live
  environment. Install or uninstall software, apply dotfiles, change the account
  shell, or modify system files only when the user authorizes that operation on
  the intended machine. Developing scripts for those operations is separate.
- Commit or push only when explicitly requested for the active task. Do not
  merge, rebase, open a PR, or rewrite published history without authorization.
- Preserve configured hooks and signing. Report blockers instead of bypassing
  them. Existing instructions from the user take precedence over this runbook.

## Repository layout and ownership

- `.chezmoiroot` selects `home/` as the managed source state. Runtime installers,
  inventories, and verification live under `scripts/bootstrap/` and `manifests/`.
- The root `Brewfile` declares core Homebrew packages. Configuration lives only
  under `home/`; do not restore the retired component installers or duplicates.
- Before updating an older Mac, complete its reviewed chezmoi handoff. Preserve
  legacy link targets and private backups outside the current source checkout.
- Update `manifests/config-files.tsv` whenever managed configuration files are
  added, removed, or renamed. Conflict detection and backups depend on it.
- Keep plugin revisions consistent with the committed lockfiles and manifests.
  Dependency upgrades are deliberate changes, separate from routine reconciliation.

## Safety invariants

- Never inspect or expose secrets, credentials, tokens, private keys, shell
  histories, Fish universal variables, or unrelated application state. Do not
  dump the environment or read credential stores or private account configuration
  to debug builds.
- Keep machine-specific data, diagnostics, package inventories, and backups out
  of Git. Personal provisioning notes stay ignored; never force-add them or copy
  the user's completed notes into committed documentation.
- Preserve unknown files, local edits, and existing applications. Refuse unsafe
  symlinks, path traversal, unexpected file types, and unowned destinations.
  Never remove whole configuration, Cargo, Go, font, or Homebrew directories as
  a shortcut for resolving a provisioning failure.
- Recovery must be explicit and limited to the affected files. Preserve a private
  backup before replacing known damaged configuration; refuse other differences.
- Use private temporary directories for fixtures. Isolate HOME, destination,
  cache, state, plugin copies, and tmux sockets when running application tests.
  A temporary directory alone does not isolate system package installation.
- Do not run live `chezmoi apply`, package installers, or shell-changing commands
  as a test. Keep the isolated-hook and installer guards intact.
- Never disable Gatekeeper, strip quarantine, re-sign downloaded apps, or change
  macOS security settings to make provisioning succeed. User app approvals stay
  manual. Trust only the required third-party Homebrew formula, not a whole tap.
- Verify pinned download checksums before extracting or executing artifacts.
  Check platform, architecture, and version; retain safe retry behavior.
- Treat bootstrap as staged, not transactional. Preserve errors and useful local
  diagnostics. Resuming a partial installation does not prove a clean-Mac install;
  package removal is not a factory reset.

## Core tooling

- Maintain Fish, Alacritty, tmux, Neovim, Starship, and the configured Nerd Font.
- Go and Rust are the development toolchains. Use standard Go tooling and
  rustup with explicit version/component pins.
- Install language servers and formatters directly through the declared owners,
  outside Mason. Preserve BasedPyright, Ruff, Lua LS, StyLua, and Go/Rust support.
- fnm is installed as a manager only. Do not install Node versions through it.
  BasedPyright's uv environment owns its isolated Node runtime. Do not add
  general-purpose Node/npm or frontend tooling to core provisioning.
- Preserve the agreed CLI tools, including fd, ripgrep, uv, workmux,
  ssh-copy-id, and the existing Fish integrations. Do not restore shfmt or
  tmux-sessionx. Agent Workbench and unrelated a la carte tools are out of scope.
- Homebrew is rolling software. A Brewfile is not a version lock or a reason to
  upgrade unrelated packages, start services, uninstall extras, or run cleanup.

## Implementation and tests

- Keep shell scripts compatible with macOS system Bash 3.2. Preserve explicit
  interpreter boundaries between Bash, Fish, and Lua. Do not introduce shfmt.
- Prefer small changes at the failed boundary. Check the exact pinned dependency
  API before changing its integration; file presence is not proof a native
  library can load. Propagate asynchronous build failures instead of hiding them.
- Add tests for meaningful behavior, safety invariants, and regressions. Check
  existing coverage first; avoid tests for trivial edits or tests that only
  repeat the implementation. Extend shared fixtures when appropriate.
- Assert observable outcomes and distinguish intended refusals from unrelated
  errors. Test retries, partial failures, conflict preservation, and actual
  dependency integration where relevant.
- Run `python3 tests/test_bootstrap.py` and
  `shellcheck -x bootstrap.sh install.sh scripts/bootstrap/*.sh tests/run-isolated.sh`
  for bootstrap changes. Run `git diff --check` before committing.
- Use `tests/run-isolated.sh` for real chezmoi deployment tests and its `--smoke`
  mode for existing binaries and copied pinned plugins. Never point those tests
  at live configuration or weaken their isolation guards.
- Report missing dependencies, skipped tests, and platform limits. Fixture tests
  and cached-plugin smoke tests do not validate a fresh package installation,
  a different macOS loader, live LSP attachment, or GUI/font rendering. Keep
  clean-Mac and interactive acceptance checks explicit.

## Documentation

- Write short, plain instructions for the person provisioning or maintaining a
  Mac. Put each command on its own line and keep guards and error handling in
  scripts. Do not require users to assemble argument arrays or demo paths.
- Keep one main setup workflow in `README.md`. Use `docs/bootstrap.md` for
  maintenance, ownership, tooling decisions, and recovery. Link rather than repeat.
- Give each procedure one authoritative home. Update or remove superseded prose
  instead of appending more overlapping validation or status documents.
- Retain necessary safety limits and unique manual or hardware evidence.
  Report routine test results in task summaries or PR descriptions, not a
  committed validation diary. Keep the manual provisioning checklist local.

## Commit messages

```text
<Capitalized imperative verb> <specific change>

<explanation of what changed and why>
```

- Use a concrete, imperative subject of at most 72 characters without a trailing
  period, Conventional Commit prefix, ticket number, or planning identifier.
  Preserve names such as Fish, Neovim, chezmoi, and SHA-256.
- Keep each commit focused on one coherent change. Nontrivial changes need a
  body explaining the behavior and reason, separated by a blank line. Limit
  every line to 72 characters.
- Do not put validation sections, test results, or environment blockers in commit
  messages. Report them accurately in PR descriptions or task summaries.
- Rewrite existing messages only when explicitly requested. Review staged files
  and content before committing; exclude private artifacts and local notes.
