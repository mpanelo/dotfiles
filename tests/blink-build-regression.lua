local function scenario(opts)
  local state = { exists = opts.exists, loads = opts.loads, builds = 0 }
  local keys = { "CARGO_PROFILE_RELEASE_STRIP", "CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP" }
  vim.env[keys[1]] = "symbols"
  vim.env[keys[2]] = nil
  package.loaded["blink.cmp"] = {
    get_library_name = function() return "blink_cmp_fuzzy" end,
    get_repo_root = function() return vim.env.HOME .. "/plugin" end,
    build = function(build_opts)
      state.builds = state.builds + 1
      assert(build_opts.force, "an existing unloadable file must not skip rebuilding")
      for _, key in ipairs(keys) do assert(vim.env[key] == "none", "strip override missing") end
      return { pwait = function()
        for _, key in ipairs(keys) do assert(vim.env[key] == "none", "environment restored before build completed") end
        if opts.build_fails then return false, "fixture build failure" end
        state.exists = true
        state.loads = not opts.still_broken
        return true
      end }
    end,
  }
  package.loaded["blink.lib.native"] = {
    try_git_commit = function() return "fixture-commit" end,
    resolve = function() return state.exists and "/fixture/libblink_cmp_fuzzy.dylib" or nil end,
  }
  local loadlib = package.loadlib
  package.loadlib = function(_, symbol)
    assert(symbol == "luaopen_blink_cmp_fuzzy")
    if state.loads then return function() end end
    return nil, "mis-aligned LINKEDIT string pool"
  end
  local ok, err = pcall(dofile(vim.env.DOTFILES_BLINK_BUILDER))
  package.loadlib = loadlib
  assert(vim.env[keys[1]] == "symbols", "inherited strip setting was not restored")
  assert(vim.env[keys[2]] == nil, "unset build-override setting was not restored")
  if opts.build_fails then
    assert(not ok and tostring(err):find("fixture build failure", 1, true), "build failure was swallowed")
  elseif opts.still_broken then
    assert(not ok and tostring(err):find("cannot be loaded", 1, true), "unloadable output was accepted")
  else
    assert(ok, err)
  end
  assert(state.builds == opts.builds, "unexpected build count")
end

local ok, err = xpcall(function()
  scenario({ exists = true, loads = true, builds = 0 })
  scenario({ exists = true, loads = false, builds = 1 })
  scenario({ exists = false, loads = false, builds = 1 })
  scenario({ exists = true, loads = false, builds = 1, build_fails = true })
  scenario({ exists = true, loads = false, builds = 1, still_broken = true })
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("DOTFILES_BLINK_BUILD_OK: 5 scenarios")
vim.cmd("qa!")
