# Bootstrap and validation

The repository implementation has offline checks and a real chezmoi test harness.
Real applies are confined to temporary destinations; no core package installation
or live-home apply has been performed. Keep the original configuration directories until the Mac Studio is
provisioned and the MacBook handoff is separately reviewed.

## Commands available now

From the checkout:

```sh
./bootstrap.sh --plan
./bootstrap.sh --check
python3 tests/test_bootstrap.py
shellcheck -x bootstrap.sh install.sh scripts/bootstrap/*.sh
tests/run-isolated.sh --download-chezmoi
tests/run-isolated.sh --download-chezmoi --smoke
```

`--plan` prints the stages. `--check` is read-only and deliberately fails when it
finds directory/file symlinks, divergent configurations, shadowing `~/.tmux.conf`,
or unmanaged Alacritty/font installations. That refusal is expected on the
reference Mac; it is not an instruction to remove those files.

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
   configuration, pinned plugins, and verification.
5. Records hashes of successfully deployed configuration for later conflict
   detection. Local edits that diverge from the recorded or desired state stop a
   subsequent apply instead of being silently overwritten.

Do not run bootstrap with sudo. The implementation targets the standard
`~/.config`, `~/.cargo`, and `~/.rustup` locations; custom locations need a reviewed
extension rather than a guessed migration. It does not change the login shell,
macOS preferences, security settings, or authentication.

## Ownership

The root `Brewfile` is the core package declaration. `macos/brew/Brewfile` and
component setup scripts remain legacy compatibility files while the old layout
is linked into the reference machine. Do not run the legacy installers as part
of the new bootstrap.

`manifests/versions.json` pins Go, Rust, the uv tool Python runtime, BasedPyright,
its Node wheel, Ruff, and the Tree-sitter CLI. `go-tools.tsv` pins Go editor
tools. `python-tools.constraints.txt` must match the corresponding JSON pins.
These are initial reference-compatible versions, not a promise they are the
latest releases; review updates explicitly before broad deployment.

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
