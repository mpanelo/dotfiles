-- Run with -u NONE, before loading managed Neovim configuration. An unloadable
-- cached library must be repaired before Blink's normal setup requires it.
local ok, err = xpcall(function()
  local root = vim.fn.stdpath("data") .. "/lazy/"
  local lock = vim.json.decode(table.concat(vim.fn.readfile(
    vim.env.DOTFILES_REPO_ROOT .. "/home/dot_config/nvim/lazy-lock.json"
  ), "\n"))
  for _, name in ipairs({ "blink.lib", "blink.cmp" }) do
    assert(vim.fn.isdirectory(root .. name) == 1, "Missing seeded plugin: " .. name)
    local result = vim.system({ "git", "-C", root .. name, "rev-parse", "HEAD" }, { text = true }):wait()
    assert(result.code == 0 and vim.trim(result.stdout) == lock[name].commit, "Plugin differs from its pin: " .. name)
    vim.opt.rtp:prepend(root .. name)
  end
  dofile(vim.env.DOTFILES_REPO_ROOT .. "/scripts/bootstrap/build-blink.lua")()
  require("blink.cmp.fuzzy").set_implementation("rust")
end, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
