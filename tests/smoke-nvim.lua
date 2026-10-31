-- Runs only against the harness's temporary configuration and plugin copies.
local ok, err = xpcall(function()
  assert(vim.env.DOTFILES_VERIFY_ONLY == "1", "Offline verification mode is required")
  assert(vim.g.mapleader == ",", "Leader key changed")
  -- which-key registers mappings through deferred startup callbacks.
  vim.wait(2000, function() return vim.fn.maparg(",e", "n", false, true).desc == "Neotree" end)
  for key, description in pairs({ [",ff"] = "Find File", [",gdo"] = "Open Diffview", [",e"] = "Neotree" }) do
    assert(vim.fn.maparg(key, "n", false, true).desc == description, "Missing keybinding: " .. key)
  end
  local conform = require("conform")
  assert(conform.formatters_by_ft.bash == nil, "shfmt is still configured")
  assert(conform.formatters_by_ft.lua[1] == "stylua", "StyLua was removed")
  assert(vim.lsp.config.lua_ls.cmd[1] == "lua-language-server", "Lua LSP configuration changed")
  assert(vim.lsp.config.basedpyright.cmd[1] == "basedpyright-langserver", "BasedPyright configuration changed")
  for _, parser in ipairs(require("config.treesitter")) do
    assert(pcall(vim.treesitter.language.add, parser), "Missing parser: " .. parser)
  end
  require("telescope").load_extension("fzf")
  assert(pcall(require, "telescope._extensions.fzf"), "Telescope native extension failed")
  assert(require("blink.cmp").library_available(), "Blink native matcher is missing")
  require("blink.cmp.fuzzy").set_implementation("rust")
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "local   value={1,2}" })
  conform.format({ bufnr = buffer, formatters = { "stylua" }, async = false, lsp_format = "never", timeout_ms = 5000 })
  assert(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)[1]:match("local value ="), "StyLua did not format the scratch buffer")
  assert(#(_G.dotfiles_startup_errors or {}) == 0, table.concat(_G.dotfiles_startup_errors or {}, "\n"))
  io.stdout:write("DOTFILES_NVIM_SMOKE_OK\n")
end, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
