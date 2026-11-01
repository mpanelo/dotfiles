# Bootstrap and validation

The repository implementation has offline checks and a real chezmoi test harness.
Real applies are confined to temporary destinations; no core package installation
or live-home apply has been performed. Keep the original configuration directories until the Mac Studio is
provisioned and the MacBook handoff is separately reviewed.

## Commands available now

From the checkout:

```sh
./bootstrap.sh --check
python3 tests/test_bootstrap.py
shellcheck -x bootstrap.sh install.sh scripts/bootstrap/*.sh
tests/run-isolated.sh --download-chezmoi
tests/run-isolated.sh --download-chezmoi --smoke
```

`--check` reports whether the installation has any blocking configuration or
path conflicts, without installing software or changing destination files. It
checks platform/default directory settings, source inventory coverage, existing
file contents, symlinks/runtime directories, a shadowing `~/.tmux.conf`, and
unmanaged Alacritty or JetBrains Nerd Font installations. The output includes
file counts and the detected Command Line Tools, Homebrew and chezmoi state.

Missing prerequisites are informational because bootstrap will install them.
On a clean Mac, a pass normally means there are no existing files to conflict
with installation. It does not mean the environment has been provisioned or
tested. Network access, administrator authentication, installed tool versions,
language-server behavior and visual rendering are outside this check. Use
`scripts/bootstrap/verify.sh` and the manual checks after provisioning.

Existing directory/file symlinks or divergent configurations cause a failure.
That refusal is expected on the reference Mac; it is not an instruction to remove
those files.

The offline Python suite never invokes an installer or chezmoi apply.
`tests/render-templates.go` additionally checks template syntax and architecture
selection using the standard Go template engine. The integration harness uses
real chezmoi init, dry-run, apply and diff against temporary source/configuration/
destination/cache/state directories. It never applies to your live home.

`--download-chezmoi` explicitly downloads a pinned official Apple Silicon release,
verifies its SHA-256, and removes the temporary executable afterward. It does not
install into Homebrew or HOME. To use an existing executable instead, pass
`--chezmoi /path/to/chezmoi`. The harness itself never downloads software.

`--smoke` additionally starts existing Fish, tmux and Neovim binaries against the
temporary configuration. It uses independent copies of cached pinned plugins and
native artifacts, without installing/updating plugins or using Mason. tmux uses a
private socket; session restore/save are disabled in the test fixture. Both laptop
and desktop battery branches are exercised. Neovim checks mappings after deferred
startup, native extensions/parsers, and StyLua formatting in a scratch buffer.
Language-server attachment, GUI/font rendering, and full package provisioning
remain separate acceptance checks. Cached plugin revisions must match the pins.

The generated fake HOME is deliberately distinct from the apply destination.
The harness checks the real chezmoi context and rendered hooks before applying;
all provisioning hooks must be no-ops. `DOTFILES_ISOLATED_TEST=1` independently
blocks the reconciliation installer if called directly. Do not approximate this
by setting HOME and destination to the same directory. Keep private fixtures with
`--keep-workspace` only when diagnosing a failure; they are deleted by default.

Some execution sandboxes block tmux's private Unix socket. Run the reviewed
harness with permission to create that socket; do not connect it to a live tmux
server or weaken the configuration-isolation checks.

## Provisioning a new Mac

After this implementation has been reviewed and published at an explicit commit,
the standalone entry point is:

```sh
revision=REVIEWED_40_CHARACTER_COMMIT
/bin/bash -c "$(curl -fsSL "https://raw.githubusercontent.com/mpanelo/dotfiles/$revision/install.sh")" -- "$revision"
```

Use the same real commit in the download URL and argument. This command is not
available remotely until that commit has been published; the agent does not push
it automatically. Review the downloaded script before execution if desired.

The launcher obtains the source under `~/.local/share/chezmoi` at that commit. If
Command Line Tools need installation, complete the system dialog and rerun the
same command. Administrator authentication for Homebrew may also be required.

With an already reviewed local checkout and Command Line Tools, the provisioning
entry point is `./bootstrap.sh` without arguments. That command installs software
and applies configuration; it is not a dry run.

Bootstrap does the following:

1. Refuses configuration, runtime-directory, and application/font conflicts.
2. Detects native macOS architecture and installs Homebrew if absent.
3. Installs chezmoi and initializes the source without applying immediately.
4. Uses ordered chezmoi scripts for core packages, pinned language tools,
   configuration, pinned plugins, Fish login-shell setup, and verification.
5. Records hashes of successfully deployed configuration for later conflict
   detection. Local edits that diverge from the recorded or desired state stop a
   subsequent apply instead of being silently overwritten.

Do not run bootstrap with sudo. The implementation targets the standard
`~/.config`, `~/.cargo`, and `~/.rustup` locations; custom locations need a reviewed
extension rather than a guessed migration. Fish is registered in `/etc/shells`
only if absent, then `chsh` changes the current account's login shell to the
native Homebrew Fish path. These steps can request administrator/account
authentication and are idempotent. Fish binary and configuration syntax checks
run first. New login sessions use Fish; Terminal.app must use its default login
shell setting if it previously had an explicit zsh command. Alacritty already
launches Fish directly. This does not change other accounts, macOS preferences,
Gatekeeper settings, or stored credentials.

## Homebrew output and follow-up instructions

Provisioning prints a private run directory under
`~/.local/state/dotfiles/runs/`. The Homebrew installer, initial chezmoi install,
and Bundle stage save their combined output while still showing it in the
terminal. Failed Bundle output is retained and its failure status is preserved.
`brew-info.txt` contains `brew info --installed --verbose`, including current
caveats for installed formulae and casks, even when a retry skips installation.
`formulae-*`, `casks-*`, and `taps-*` record before/after package inventories;
`homebrew-before.txt` says whether Homebrew existed, and
`login-shell-before.txt` records the prior account shell. The normal bootstrap
shares a run directory with its hooks; hooks invoked by a direct chezmoi apply
can create separate run directories. These are diagnostics, not a full machine
snapshot or an automatic uninstall manifest. They cannot reconstruct an earlier
run that predates this logging feature.

Run directories have mode 0700 and stay outside the repository. Logging captures
command output, not input, passwords, shell tracing, profiles, or environment
dumps. Treat the resulting records as private and review before sharing.

Package caveats are recommendations to assess, not commands to run blindly:

| Recommendation | Managed handling |
| --- | --- |
| Homebrew shellenv in zsh/bash profiles | Fish loads `brew shellenv fish` in `conf.d/00-paths.fish`; no zsh/bash edits are needed |
| Keg-only ssh-copy-id PATH | Its `opt/ssh-copy-id/bin` path is managed in Fish and bootstrap |
| fzf shell integration | The pinned fzf.fish plugin and existing keybindings provide it |
| zsh completions or tmux example config | Informational; preserve the managed Fish/tmux configuration |
| Optional Git GUI or service setup | Outside core; do not install extras or start services automatically |

Check the report after deliberate upgrades because package recommendations can
change. Add required integration explicitly to the managed configuration and
validate it before applying it to another Mac.

## Ownership

The root `Brewfile` is the core package declaration. `macos/brew/Brewfile` and
component setup scripts remain legacy compatibility files while the old layout
is linked into the reference machine. Do not run the legacy installers as part
of the new bootstrap.

Alacritty is the application exception to Homebrew ownership. Its cask is
disabled for failing Gatekeeper checks. Bootstrap downloads the official GitHub
DMG at the version and SHA-256 in `manifests/versions.json`, verifies it before
mounting read-only, and checks bundle identity, version and native architecture.
The app is copied to `~/Applications/Alacritty.app` without administrator access.
The installer preserves bundle metadata, never removes quarantine, never
re-signs the app, and never changes Gatekeeper settings. First launch and any
app-specific macOS approval are manual. A checksum verifies the downloaded
bytes against the reviewed pin; it does not establish Apple notarization.

An existing Homebrew-managed `/Applications/Alacritty.app` is kept. A new user
app receives a private content-hash record under `~/.local/state/dotfiles/`;
unknown or modified apps are refused. A repeat run checks that record and the
version without downloading again. Version upgrades require a reviewed app
replacement; bootstrap does not overwrite an existing version. The CLI links
from `~/.local/bin/alacritty`. Missing Alacritty terminfo entries are installed
in `~/.terminfo`; existing available definitions are preserved.

The workmux entry declares trust for `raine/workmux/workmux` only, using
Homebrew's `trusted: true` Brewfile option. It does not trust the entire tap or
disable tap-trust enforcement. The keg-only Homebrew `ssh-copy-id` directory is
included in the bootstrap and Fish PATH so the installed version is used.

`manifests/versions.json` pins Go, Rust, the uv tool Python runtime, BasedPyright,
its Node wheel, Ruff, and the Tree-sitter CLI. `go-tools.tsv` pins Go editor
tools. `python-tools.constraints.txt` must match the corresponding JSON pins.
These are initial reference-compatible versions, not a promise they are the
latest releases; review updates explicitly before broad deployment.

The Tree-sitter CLI uses the official macOS release binary for the pinned
version, with separate Apple Silicon and Intel archive SHA-256 values in the
version manifest. It installs into `~/.local/bin/tree-sitter`, independently of
Cargo, so parser tooling does not depend on compiling QuickJS Rust bindings.
The installer verifies the archive, native architecture and CLI version before
installation, then records the executable hash in private local state. Unchanged
retries skip downloads; unknown or modified executables are preserved. Any
existing Cargo-installed CLI is left intact, with the managed local binary
taking precedence on PATH. This is editor infrastructure, not a Node/npm
installation or a change to the Rust toolchain strategy.

If an older bootstrap fails compiling `rquickjs` during `tree-sitter-cli`
installation, update the source checkout and rerun bootstrap. Keep the installed
Go/Rust components and Cargo caches; an OS reset or broad cache deletion is not
needed to resume. The final compiler error alone does not identify why the
procedural-macro crate was unavailable. The release-binary installation avoids
that build step while retaining the pinned CLI version and its native runtime.

Homebrew installs fnm only. Bootstrap never calls `fnm install` and never installs
general-purpose Node/npm. BasedPyright is installed through uv from wheels,
including its private Node runtime. LSPs and formatters are independent of Mason.
The existing Go/Rust tools outside the core manifests are not reproduced.

Neovim plugin commits come from the unchanged `lazy-lock.json`; the repository
mapping in `nvim-plugins.tsv` allows seeding those exact commits before startup.
Fish plugin commits are in the managed `fish_plugins` file. tmux plugin commits
are in `tmux-plugins.tsv`. tmux-sessionx is excluded; existing copies are not
deleted. shfmt is absent from the new Conform configuration.

Plugins are installed outside the source checkout. Dirty plugin checkouts and
modified Fish plugin files cause a refusal rather than a forced reset. Routine
bootstrap restores pins; it does not run `Lazy sync`, update plugin revisions,
uninstall packages, or clean up unrelated files.

## Remaining clean-Mac checks

Before treating the setup as production-ready, validate full provisioning on a
disposable macOS VM or clean Mac. An additional user account shares Homebrew and
cannot prove an empty system-package installation works:

- Review rendered source and the diff for the clean target; keep any existing
  configuration safe. Isolated deployment/conflict checks can first be repeated
  on the MacBook with the commands above.
- Provision from empty state; interrupt and resume at each installer stage.
- Run bootstrap again and confirm stable configuration and tool/plugin versions.
- Confirm there is no general-purpose `node`/`npm` and no fnm-managed Node
  installation. BasedPyright must still launch through its private runtime.
- Confirm each language tool resolves outside Mason and the editor's Lua,
  Python, Go, and Rust integrations work on small representative files.
- Check formatting, Blink native completion, Telescope native search, parser
  loading, all preserved bindings, and disabled shfmt integration.
- Check Fish abbreviations/fzf keys, direnv, zoxide, Starship, workmux, Alacritty
  Command shortcuts, clipboard and tmux session persistence.
- Visually check the Nerd Font in the prompt, tmux status, Neo-tree and editor
  diagnostics. The desktop must omit battery status.

The verification script loads the managed editor with automatic parser/plugin
installation and update checking disabled. Installation failures should be fixed
through bootstrap, not hidden by an editor health check. Full interactive LSP,
font, clipboard, and session-restoration checks remain manual acceptance checks.

## Applying future changes

Edit configuration with `chezmoi edit`, then inspect `chezmoi diff` and apply.
Plain `chezmoi apply` runs the same package/tool/plugin reconciliation hooks as
bootstrap. Pull and review source changes before applying on another Mac.

If you intentionally edited a deployed file, compare it first, then use
`chezmoi re-add` for that specific file. A matching desired file is accepted by
preflight; a divergent local edit is not. Do not refresh the ownership hashes
manually just to bypass a conflict.

When adding or renaming a managed file, update `manifests/config-files.tsv` as
well. Preflight refuses source files absent from that safety/backup inventory,
and the source tests check coverage. Use full `chezmoi apply` or bootstrap so the
preflight and reconciliation scripts are included; a targeted apply is not the
supported provisioning workflow.

The standalone launcher initially uses a detached reviewed commit. Before making
source commits, create a branch in the source checkout. To consume published
updates from that checkout, fetch and inspect them before deliberately advancing
the source revision. Do not use the installer to reset a checkout with changes.

Update Homebrew packages separately from routine reconciliation. Update Go/Rust,
language-tool constraints and plugin lockfiles deliberately, validate on one
Mac, commit the reviewed source changes, and then propagate to the other Mac.
Homebrew is rolling release software and is not version-locked by a Brewfile.
Automatic Git commits and pushes remain disabled.
