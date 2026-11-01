local function read(path)
  local file = assert(io.open(path, "rb"))
  local bytes = file:read("*a")
  file:close()
  return bytes
end

local ok, err = xpcall(function()
  local fixture = vim.env.DOTFILES_EDITOR_FIXTURE
  vim.opt.rtp:prepend(fixture .. "/lazy.nvim")
  local config = require("lazy.core.config")
  local lockfile = fixture .. "/lazy-lock.json"
  config.options = { lockfile = lockfile }
  config.spec = { disabled = {}, ignore_installed = {} }
  config.plugins = {
    fixture = { name = "fixture", dir = fixture .. "/plugin", _ = { installed = true, is_local = false } },
  }
  local original = read(lockfile)
  local git = require("lazy.manage.git")
  assert(git.info(config.plugins.fixture.dir).commit, "fixture must have a real Git commit")
  assert(git.get_branch(config.plugins.fixture) == nil, "fixture must reproduce missing branch metadata")

  -- Reproduce the reported failure using the actual pinned lazy.nvim code.
  local restored, failure = pcall(require("lazy.manage.lock").update)
  assert(not restored and tostring(failure):find("assertion failed", 1, true), "old lock update must reproduce the assertion")
  collectgarbage("collect")
  assert(read(lockfile) == "{\n", "old lock update should leave the reported truncated output")
  local file = assert(io.open(lockfile, "wb"))
  file:write(original)
  file:close()

  -- Native builds are separate tests. Stub them here so this regression test
  -- cannot download/build plugins or launch another package installer.
  package.loaded["blink.cmp"] = { build = function()
    return { pwait = function() vim.g.dotfiles_build_started = true end }
  end }
  local system = vim.system
  vim.system = function(command, options)
    if command[1] == "make" then return { wait = function() return { code = 0 } end } end
    return system(command, options)
  end
  package.loaded["config.treesitter"] = { "lua" }
  local completed = function() return { wait = function() end } end
  package.loaded["nvim-treesitter"] = { install = completed, update = completed }
  vim.g.dotfiles_expected_lock = original
  dofile(vim.env.DOTFILES_EDITOR_INSTALLER)
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
