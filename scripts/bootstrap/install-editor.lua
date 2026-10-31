local ok, err = xpcall(function()
  vim.cmd("Lazy! restore")
  require("blink.cmp").build():pwait()
  local result = vim.system({ "make" }, {
    cwd = vim.fn.stdpath("data") .. "/lazy/telescope-fzf-native.nvim",
    text = true,
  }):wait()
  assert(result.code == 0, result.stderr)
  local treesitter = require("nvim-treesitter")
  local parsers = require("config.treesitter")
  treesitter.install(parsers):wait(300000)
  -- A changed plugin pin can change parser revisions even when files exist.
  treesitter.update(parsers):wait(300000)
  dofile(vim.env.DOTFILES_REPO_ROOT .. "/scripts/bootstrap/verify-editor.lua")
end, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
