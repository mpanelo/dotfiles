# alacritty

Rectangle selection: `C-Shift` then use the mouse to select text.
Toggle vi mode: `C-Shift-Space` then `C-v` to do a block selection.

# tmux

## Rename Session

```bash
tmux rename-session -t [target-session] [new-name]
# alias rename
```

OR `<Prefix> + $`

# neovim

## Commands

### Set the current dir for the current window

`:lcd %:p:h`

- `%` represents the current file.
- `%:p` the absolute path.
- `%:p:h` the directory containing the file. `:h` (head) modifier strips one level off the path.

Also see `:help lcd`

## Key mappings

### Copy to system clipboard

`"+y`

### Enter "Insert Normal" mode

Execute one normal mode command before returning to insert mode.

`<C-o>`

### Diagnostics

`]d` jumps to the next diagnostic in the buffer.
`[d` jumps to the previous diagnostic in the buffer.
`]D` jumps to the last diagnostic in the buffer.
`[D` jumps to the first diagnostic in the buffer.

`<C-w>d` shows diagnostic at cursor in a floating window.

### LSP

`<C-]>` jump to definition (use `<C-t>` to go back).
`<C-x>` then `<C-o>` will trigger code completion menu.
`grn`   renames all references of the symbol under the cursor.
`gra`   shows a list of code actions available in the line under the cursor.
`grr`   lists all the references of the symbol under the cursor.
`gri`   lists all the implementations for the symbol under the cursor.
`<C-s>` in insert mode displays the function signature of the symbol under the cursor.

`grr`, `gri` and `gd` map to Telescope commands. You can send the results to 
Quickfix by using `<C-q>`. Go back to Telescope `:Telescope resume`.

## Troubleshooting gopls

In a Go buffer, check LSP health, the executable, and the attached workspace:

```vim
:checkhealth vim.lsp
:echo exepath('gopls')
:lua vim.print(vim.tbl_map(function(c) return { name = c.name, root_dir = c.root_dir } end, vim.lsp.get_clients({ bufnr = 0 })))
```

An empty executable path means `gopls` is missing from Neovim's PATH. For a wrong
or overly broad workspace, check `go env GOMOD GOWORK` and the configured
[root markers](home/dot_config/nvim/lsp/gopls.lua). Multi-module projects may
need a `go.work` file; see the [gopls workspace guide](https://go.dev/gopls/workspace).

For debugging, enable `:lua vim.lsp.log.set_level("debug")`, restart with
`:lsp restart gopls`, and reproduce the issue. Find the log with
`:lua print(vim.lsp.log.get_filename())`; restore log level `"warn"` afterward.
See the [settings](https://go.dev/gopls/settings) and
[troubleshooting](https://go.dev/gopls/troubleshooting) references for tuning.

## Telescope

### fzf-native

Use [fzf syntax](https://github.com/junegunn/fzf#search-syntax) in your Telescope queries.

| Token     | Match type                 | Description                          |
| --------- | -------------------------- | ------------------------------------ |
| `sbtrkt`  | fuzzy-match                | Items that match `sbtrkt`            |
| `'wild`   | exact-match (quoted)       | Items that include `wild`            |
| `^music`  | prefix-exact-match         | Items that start with `music`        |
| `.mp3$`   | suffix-exact-match         | Items that end with `.mp3`           |
| `!fire`   | inverse-exact-match        | Items that do not include `fire`     |
| `!^music` | inverse-prefix-exact-match | Items that do not start with `music` |
| `!.mp3$`  | inverse-suffix-exact-match | Items that do not end with `.mp3`    |
