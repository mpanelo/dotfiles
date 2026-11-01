# Terminal shortcuts

## Alacritty

| Action | Shortcut |
| --- | --- |
| Rectangle selection | `Ctrl-Shift` + mouse selection |
| Vi mode / block selection | `Ctrl-Shift-Space`, then `Ctrl-v` |

## tmux

Rename the session with `Prefix` + `$`, or:

```sh
tmux rename-session -t old-name new-name
```

## Neovim

| Action | Command or key |
| --- | --- |
| Set window directory to current file | `:lcd %:p:h` |
| Copy to system clipboard | `"+y` |
| One normal command from insert mode | `Ctrl-o` |
| Next / previous diagnostic | `]d` / `[d` |
| Last / first diagnostic | `]D` / `[D` |
| Diagnostic details | `Ctrl-w d` |
| Definition / return | `Ctrl-]` / `Ctrl-t` |
| Rename symbol | `grn` |
| Code actions | `gra` |
| References / implementations / definition | `grr` / `gri` / `gd` |
| Signature help in insert mode | `Ctrl-s` |
| Completion in insert mode | `Ctrl-x Ctrl-o` |

Telescope results: `Ctrl-q` sends to Quickfix; `:Telescope resume` reopens the picker.

### Diagnose gopls

In a Go buffer:

```vim
:checkhealth vim.lsp
:echo exepath('gopls')
:lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
```

An empty executable path means `gopls` is missing from Neovim's PATH. Check
`go env GOMOD GOWORK` for workspace problems and the configured
[root markers](home/dot_config/nvim/lsp/gopls.lua). See the official
[workspace](https://go.dev/gopls/workspace) and
[troubleshooting](https://go.dev/gopls/troubleshooting) guides.

### Telescope search syntax

| Pattern | Meaning |
| --- | --- |
| `word` | Fuzzy match |
| `'word` | Exact match |
| `^word` | Prefix |
| `.go$` | Suffix |
| `!word` | Exclude exact match |
| `!^word` | Exclude prefix |
| `!.go$` | Exclude suffix |
