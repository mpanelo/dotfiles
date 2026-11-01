# Reproducible macOS development environment

Status: core tooling agreed; repository implementation and isolated MacBook
validation are complete. Clean-machine provisioning remains to be tested.
See [bootstrap and validation](bootstrap.md) for the implementation and outstanding
clean-Mac checks. No software installation or live configuration migration has
been performed on the reference machine.

The existing Mac is the compatibility reference. The new Mac Studio will be the
first machine provisioned through the completed bootstrap. Preserve existing
configuration, appearance, and keybindings unless a change is explicitly agreed.

## Agreed scope

- macOS, primarily native Apple Silicon.
- chezmoi for configuration; Homebrew and a curated Brewfile for applications and
  most CLI tools.
- Fish, Alacritty, tmux, Neovim, Starship, and JetBrainsMono Nerd Font.
- Standard Go tooling and rustup for the Go and Rust development toolchains.
- Keep BasedPyright, Lua language server, StyLua, and existing Go/Rust editor
  integrations. Provision tools directly through repository-owned manifests and
  scripts, never through Mason.
- Keep fd, ripgrep, uv, workmux, and the existing modern Unix tools used by Fish.
- Keep ssh-copy-id in core.
- Drop shfmt from future provisioning and remove its Conform entry during the
  implementation stage. This is an intentional exception to preserving existing
  editor functionality; do not uninstall the existing executable automatically.
- Exclude tmux-sessionx from the managed tmux configuration and plugin manifest.
  Leave the existing live checkout alone during repository-only implementation.
- Keep fnm installed, but do not install a Node version through it. Use uv to
  isolate BasedPyright and its private Node runtime separately.
- Node is allowed as a private dependency of BasedPyright. Do not add TypeScript compilers,
  React, frontend frameworks, frontend language servers, or frontend build tools.
- Other tools discovered during the audit are a la carte and outside this project.
  Do not build optional-tool installers or reproduce the machine's full inventory.
- Agent Workbench is outside scope. Do not provision it or use the existing `awb`
  function as a bootstrap validation requirement. Leave that function unchanged
  unless a later change is agreed.

## Core installation contract

"Direct management" means the repository declares installation source, versions
where supported, PATH requirements, and verification. It does not mean manually
typing installation commands on each machine. Neovim consumes the resulting
executables and does not install language servers or external formatters.

The following user-facing core tools are agreed. The installer assignments define
the intended implementation; exact versions will be selected and validated when
the manifests are implemented.

| Area | Core tooling | Proposed owner |
| --- | --- | --- |
| Provisioning | Homebrew, chezmoi | Official Homebrew installer; Homebrew installs chezmoi |
| Terminal | Alacritty, Fish, tmux, Starship | Homebrew formulae; pinned official Alacritty DMG |
| Font | JetBrainsMono Nerd Font | Homebrew `font-jetbrains-mono-nerd-font` cask |
| Editor | Neovim | Homebrew |
| Search/navigation | fd, ripgrep, fzf, zoxide | Homebrew |
| Modern Unix commands | bat, eza, HTTPie, tlrc | Homebrew; commands `bat`, `eza`, `http`, `tldr` |
| Shell environment | direnv | Homebrew |
| Git workflow | Git, git-delta, lazygit, ssh-copy-id | Homebrew; commands include `delta` |
| Structured data | jq | Homebrew |
| Python tool runner | uv | Homebrew; manage needed tool runtimes through uv |
| On-demand Node manager | fnm, with no Node version installed | Homebrew; no general-purpose Node/npm installation |
| Worktree workflow | workmux | Homebrew `raine/workmux` tap, trusting only the workmux formula |
| Go development | Go, gopls, goimports, gofumpt | Homebrew base Go; pinned Go-native tool installation |
| Rust development | rustup, rustc, Cargo, rust-analyzer, rustfmt, Clippy, rust-src | Official rustup installation and pinned toolchain/components |
| Python editor support | BasedPyright, Ruff | Versioned uv tool installation; BasedPyright owns its private Node runtime |
| Lua editor support | lua-language-server, StyLua | Homebrew |

Supporting dependencies are also required to preserve the editor and shell:

| Dependency | Purpose and ownership |
| --- | --- |
| Xcode Command Line Tools | System Git before Homebrew, C compiler, make, native parser/extension builds |
| Tree-sitter CLI | Pin the known-compatible Cargo CLI initially; the Homebrew `tree-sitter` library alone is insufficient |
| LuaRocks | Retain existing lazy.nvim compatibility initially; reassess only after proving it is unused |
| Fisher, Bass, fzf.fish | Retain existing Fish plugins; record revisions and install outside the source tree |
| TPM and configured tmux plugins | Retain current plugins, including the Catppuccin fork; record revisions |
| lazy.nvim and existing Neovim plugins | Preserve committed `lazy-lock.json`; restore rather than update during bootstrap |
| Python runtime | Infrastructure for BasedPyright's uv distribution and Bass; not an additional project-development setup |

ShellCheck is proposed as a repository validation dependency, rather than a
required everyday development tool. It can be supplied by CI or a maintainer's
local installation.

The core retains Fish's current `cat` -> `bat`, `ls`/`ll` -> `eza`, `curl` ->
`http`, `tldr`, `lg`, and `nvd` abbreviations, together with Starship, zoxide,
fzf.fish, and direnv integration. Preserve existing bindings while making startup
ordering and missing-dependency handling explicit.

Exclude cloc, wget, and unrelated tools from core. Homebrew resolves libraries
transitively; do not copy every installed library into the Brewfile. Removing a
tool from the provisioning plan never implies uninstalling it on an existing Mac.

## BasedPyright and Node: agreed ownership

Install fnm through Homebrew, but do not install any Node version through it.
The manager is available for future on-demand use; bootstrap must not run
`fnm install`, select a downloadable default, or enable automatic Node installation
when entering a directory. Fish initialization must tolerate zero installed Node
versions. Replace the existing user-specific fnm path with portable, guarded
initialization and an explicit Fish shell argument during implementation.

Separately, install a versioned BasedPyright wheel into an isolated uv tool
environment. Its `nodejs-wheel-binaries` dependency supplies the private Node
runtime automatically. Do not install BasedPyright through Homebrew, npm, or
Mason. Do not add Homebrew Node or a general-purpose npm installation to core.

This keeps the language server independent of fnm, project `.node-version` or
`.nvmrc` files, and interactive shell startup. It does not expose BasedPyright's
`node` or `npm` on the shell PATH. Its isolated Python runtime and Node dependency
both need deliberate updates. Pin the language-server and Node-wheel versions
in a constraints manifest; install published wheels rather than building
BasedPyright from source. Verify startup from a fresh terminal and through tmux.

Existing standalone or fnm-managed Node installations on an existing Mac are
outside this migration's ownership. Do not remove or change them automatically;
validate absence of general-purpose Node only on a clean provisioning target.

Existing JavaScript/TypeScript Tree-sitter grammars remain syntax-viewing support.
Preserve them without installing frontend language servers or running Node-based
grammar regeneration.

## Font ownership and appearance

Declare `cask "font-jetbrains-mono-nerd-font"` in the Brewfile and retain
Alacritty's `JetBrainsMono Nerd Font` family, size, and appearance. Use the normal
family already configured; do not silently switch to Mono or Propo variants.

On a new Mac, Homebrew installs the fonts before the terminal is validated. On
the existing Mac, preflight must detect manually installed font files and an
existing unmanaged Alacritty application. Adopt existing font cask artifacts
only if they are identical to the selected release. Homebrew supports `--adopt`
for that case. If files differ, stop and plan a reviewed backup/handoff instead
of using `--force`, overwriting fonts, or deleting them.

Alacritty's Homebrew cask is disabled because it fails Gatekeeper checks.
Install its pinned, SHA-256-verified official GitHub DMG into
`~/Applications/Alacritty.app`, preserving bundle metadata and tracking installed
contents for safe retries. Keep an existing Homebrew-managed app. Do not remove
quarantine, re-sign the release or change macOS security settings. First launch
and any app-specific approval remain manual; checksum verification does not
prove notarization. See the bootstrap runbook for ownership and update behavior.

Verify family availability, duplicate-font conflicts, and Nerd Font glyphs in
Alacritty, tmux, Starship, Neo-tree, and Neovim diagnostics. Keep font updates
explicit because glyph changes can affect the existing UI. Font binaries and
machine font inventories do not belong in Git.

## Configuration migration

The current Fish, Alacritty, and Neovim directories are linked into the checkout.
tmux uses a real configuration directory with individual file links. Do not move
the original source directories while these live links exist.

Use a dedicated chezmoi source-state directory:

```text
dotfiles/
  .chezmoiroot                 # contains: home
  bootstrap.sh
  Brewfile
  manifests/                  # core toolchain, tool, and plugin versions only
  scripts/                    # preflight, migration, reconciliation, verification
  docs/
  home/
    .chezmoi.toml.tmpl
    .chezmoiignore
    empty_dot_hushlogin
    dot_config/
      fish/
      alacritty/
        themes/catppuccin-mocha.toml
      tmux/
        tmux.conf
        executable_has-battery.sh
      nvim/
      starship.toml
    run_before_10_packages.sh.tmpl
    run_before_20_toolchains.sh.tmpl
    run_after_30_plugins.sh.tmpl
```

Copy tracked configuration into the new tree while leaving the original layout
in place. Track the currently ignored Alacritty theme. Preserve Neovim's lockfile,
Lua LSP, StyLua, BasedPyright settings, Go/Rust integrations, keymaps, formatting
controls, and tmux/Fish plugin behavior. Remove only the agreed shfmt formatter
entry. Do not introduce Mason or migrate the plugin manager during this work.

Use regular deployed files instead of links into the source checkout. Preserve
runtime files alongside them; avoid chezmoi `exact_` directory management where
applications create state. Keep Fisher output, tmux plugin checkouts, Neovim data,
Fish universal variables, history, caches, and session snapshots outside Git.

Validate the new source in a temporary destination first. Provision and validate
the Mac Studio before a separate MacBook handoff. For that handoff, preserve the
old links and their target contents in a private local backup; replace only known
repository-owned links after reviewing the diff. Stop on unknown files, unexpected
link targets, or divergent configurations. Document and exercise restoration.

## Toolchain and package version policy

Go uses a Homebrew base executable plus Go's native toolchain selection. Record
the tested baseline in the core manifest; honor project `go.mod`/`go.work`
requirements. Install pinned gopls, goimports, and gofumpt using standard Go
tooling. Do not hardcode GOROOT or introduce another Go version manager.

Rust uses rustup with an explicitly versioned default toolchain and the required
components. Respect project `rust-toolchain.toml`; do not globally set
RUSTUP_TOOLCHAIN or install Homebrew Rust as an editor-build fallback. Extra
targets, Cargo utilities, and other language-tool findings stay outside scope.

Pin plugin revisions and language-tool versions where the chosen installer
supports it. Preserve a tested Tree-sitter CLI/parser/plugin combination.
Homebrew is rolling release software: a Brewfile and `--no-upgrade` provide
repeatable package selection, not bit-for-bit version locking. Keep upgrades
explicit and validate compatibility before propagating them to the second Mac.

Each executable has one declared owner. Verification checks executable resolution
and version so leftover Mason directories or old installations cannot silently
take precedence. Do not remove old installations during initial migration.

## One-command bootstrap

The eventual command invokes a reviewed bootstrap release using macOS's system
Bash. It must work without Fish, Go, Rust, or Python already installed.

1. Check macOS/architecture, prerequisites, existing files, links, font/application
   conflicts, and any existing source checkout. Refuse incompatible state.
2. Detect Command Line Tools. If installation needs user interaction, explain the
   action and make rerunning the same bootstrap a supported resume path.
3. Install native Homebrew using the official installer when absent, then chezmoi.
4. Initialize the repository without immediately applying configuration.
5. Review migration conflicts before installing the rest of the environment.
6. Reconcile the core Brewfile without routine upgrades or automatic cleanup.
7. Install/reconcile Go, rustup components, and directly managed language tools.
8. Apply configuration only after prerequisites are ready.
9. Restore pinned plugins, build native editor extensions, and install parsers.
   Use an isolated tmux server for any setup work requiring a server.
10. Verify the environment and report any remaining manual actions.

Scripts must be idempotent and detect missing tools even after a successful prior
run. Change-triggered scripts must include relevant manifest hashes, but recorded
completion alone is not proof the desired state still exists. Do not use a
routine apply operation to update every package or plugin.

## Validation and implementation stages

| Stage | Work | Exit criteria |
| --- | --- | --- |
| 1 (complete) | Agree core and BasedPyright/Node ownership | fnm with no Node version; uv-isolated BasedPyright runtime; ssh-copy-id retained |
| 2 (implemented) | Add source tree alongside the original layout | Existing live links remain valid; offline configuration/keymap comparisons |
| 3 (implemented; installation untested) | Implement package/tool manifests and bootstrap | Script validation; predictable PATH; no Mason or unintended frontend dependencies |
| 4 (isolated checks passed) | Exercise isolated deployment and conflict cases | Isolated deployment and app smoke tests pass; full installer interruption/recovery still needs a clean target |
| 5 | Provision Mac Studio | Complete terminal and editor checks on a clean machine |
| 6 | Perform separately reviewed MacBook handoff | Preserved local state, no unexpected file changes, working rollback |
| 7 | Retire obsolete layout and scripts | Both Macs use the new source and documented workflow |

Editor checks include Lua LSP/StyLua, Python BasedPyright/Ruff, Go LSP/formatting,
Rust LSP/components, Blink's native matcher, Telescope's native extension and
search, all existing parsers, and preserved keybindings. Check that shfmt is no
longer configured and that each LSP executable resolves outside Mason.

Terminal checks include Fish startup, abbreviations, fzf bindings, direnv, zoxide,
Starship, Alacritty shortcuts/font/theme, tmux clipboard/navigation/session
persistence, and omission of the battery module on a desktop. Workmux remains
core; Agent Workbench is not a dependency or acceptance test.

## Maintenance and manual actions

Edit managed files using `chezmoi edit`; review `chezmoi diff` before applying.
Use `chezmoi re-add` deliberately for selected live changes. Review and commit
source changes, then pull, inspect the diff, apply, and verify on the other Mac.
Keep automatic commits and pushes disabled. Version upgrades are separate,
reviewed manifest/lockfile changes, tested on one Mac before the other.

Manual actions may include macOS account setup, administrator authentication,
Command Line Tools dialogs, Git identity/authentication/signing, application
logins, and device permissions. Fish is the required account login shell:
register the native Homebrew path in `/etc/shells` if absent, then use `chsh`
after installing configuration and plugins. Record the prior shell for recovery
and verify the account setting, rather than an inherited `$SHELL` value.
Authentication may be required. Any macOS preference automation is a separate,
reviewed usability-only stage. Do not change macOS security settings.

Never inspect or commit secrets, credentials, private keys, machine identifiers,
or private state. Do not overwrite existing configuration, uninstall software,
execute chezmoi apply, or push to GitHub during the planning stage.

## References

- [BasedPyright installation](https://docs.basedpyright.com/latest/installation/command-line-and-language-server/)
- [BasedPyright runtime dependencies](https://github.com/DetachHead/basedpyright/blob/main/pyproject.toml)
- [uv tool management](https://docs.astral.sh/uv/guides/tools/)
- [fnm installation and Fish integration](https://github.com/Schniz/fnm)
- [Homebrew BasedPyright dependencies](https://formulae.brew.sh/formula/basedpyright)
- [JetBrainsMono Nerd Font cask](https://formulae.brew.sh/cask/font-jetbrains-mono-nerd-font)
- [Homebrew adoption of identical cask artifacts](https://docs.brew.sh/Manpage#install-options-formulacask-)
- [Homebrew versioning limitations](https://docs.brew.sh/Versions)
- [Tree-sitter library versus CLI](https://formulae.brew.sh/formula/tree-sitter)
- [chezmoi source-directory structure](https://www.chezmoi.io/user-guide/advanced/customize-your-source-directory/)
- [chezmoi symlink migration](https://www.chezmoi.io/migrating-from-another-dotfile-manager/)
- [Go toolchain selection](https://go.dev/doc/toolchain)
- [rustup project overrides](https://rust-lang.github.io/rustup/overrides.html)
