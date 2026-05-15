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
