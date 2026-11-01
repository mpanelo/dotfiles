# Tooling decisions

See the [Brewfile](../Brewfile) for core packages and [manifests](../manifests/)
for pins. Configuration ownership is documented in [maintenance](bootstrap.md#ownership-and-upgrades).

- **chezmoi:** `home/` is the single configuration source; deploy regular files
  and preserve unknown files through conflict checks.
- **Homebrew:** install missing tools without upgrading or removing unrelated
  packages. A Brewfile does not lock package versions.
- **Go:** use Homebrew's Go with native toolchain selection and pinned Go tools.
  **Rust:** use rustup with explicit versions/components. Project toolchain files
  retain control; no additional version manager is needed.
- **Language tools:** install servers and formatters directly, outside Mason.
  Keep Go/Rust support, Lua LS, StyLua, BasedPyright, and Ruff.
- **Node:** install fnm without Node versions. BasedPyright uses uv's isolated
  Python environment and private Node runtime; no frontend toolchain is provisioned.
- **Alacritty:** use the checksum-verified official DMG in `~/Applications`,
  with a CLI link in `~/.local/bin`. App approval remains manual.
- **Plugins:** pin Fish, tmux, and Neovim revisions; build native editor support
  and verify it loads. Use an official pinned Tree-sitter CLI binary.

Go and Rust are the development languages. Python and Lua runtimes support editor
tooling. shfmt, tmux-sessionx, Agent Workbench, and unrelated optional tools stay
outside core provisioning. Exclusion does not uninstall existing software.

Git/SSH identity, application logins, macOS preferences, and app approvals remain
manual. Preserve Gatekeeper and quarantine settings. Bootstrap can resume partial
installation; it is not transactional and provides no automatic rollback.
