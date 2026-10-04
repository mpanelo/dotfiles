# Neovim notes

## Checking gopls

Open a Go file, then run these commands:

```vim
" Check LSP health and which clients are attached to this buffer.
:checkhealth vim.lsp

" Print the attached clients and their workspace roots.
:lua vim.print(vim.tbl_map(function(c) return { name = c.name, root_dir = c.root_dir } end, vim.lsp.get_clients({ bufnr = 0 })))

" Check whether Neovim can find gopls on PATH.
:echo exepath('gopls')

" Show diagnostics at the cursor.
:lua vim.diagnostic.open_float()
```

For this config, `gopls` should attach to Go, `go.mod`, `go.work`, and Go template buffers. Its root markers are `go.work`, `go.mod`, and `.git` in [`lsp/gopls.lua`](lsp/gopls.lua). If the client is missing, a blank result from `exepath()` means `gopls` is not on Neovim's `PATH`. Mason has been removed, so install `gopls` separately and make sure its executable is available in the environment that launches Neovim.

## Diagnosing slow or incomplete features

1. Check `:checkhealth vim.lsp` and confirm that `gopls` is attached to the current buffer.
2. Check the reported `root_dir`. For a multi-module repository, use an appropriate `go.work` file or open the relevant module. Avoid opening an unnecessarily broad GOPATH directory as the workspace.
3. From the project directory, check the Go workspace and tool versions:

   ```sh
   go version
   gopls version
   go env GOMOD GOWORK
   ```

4. If diagnostics are the slow part, gopls can run diagnostics on save instead of after edits. Add this to the gopls configuration when that tradeoff is desirable:

   ```lua
   settings = {
     gopls = {
       diagnosticsTrigger = "Save",
     },
   },
   ```

   To reduce workspace indexing, `directoryFilters` can exclude known, irrelevant directories. Add only paths that are safe to ignore for that repository; excluding source directories can hide results.

5. To capture details, enable LSP debug logging, restart gopls, and reproduce the issue:

   ```vim
   :lua vim.lsp.log.set_level("debug")
   :lsp restart gopls
   :lua print(vim.lsp.log.get_filename())
   ```

   The last command prints the log path. Debug logging can grow quickly; set it back to `warn` when finished:

   ```vim
   :lua vim.lsp.log.set_level("warn")
   ```

See the official [gopls workspace guide](https://go.dev/gopls/workspace), [settings reference](https://go.dev/gopls/settings), and [troubleshooting guide](https://go.dev/gopls/troubleshooting) for more detail.
