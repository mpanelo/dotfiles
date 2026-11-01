local ok, err = xpcall(function()
  -- Git checkouts were restored by reconcile.sh. Lazy restore fetches again
  -- and rewrites the lockfile; it is unnecessary and unsafe for this stage.
  local config = require("lazy.core.config")
  local lock = vim.json.decode(table.concat(vim.fn.readfile(config.options.lockfile), "\n"))
  for name, entry in pairs(lock) do
    local plugin = assert(config.plugins[name], "Missing plugin specification: " .. name)
    local result = vim.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }, { text = true }):wait()
    assert(result.code == 0, "Cannot read plugin revision: " .. name)
    assert(vim.trim(result.stdout) == entry.commit, "Plugin differs from its pin: " .. name)
  end
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
