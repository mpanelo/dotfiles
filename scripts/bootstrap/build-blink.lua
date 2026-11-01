-- Build only when the native module is missing or cannot be loaded by macOS.
-- Cargo's strip step can produce misaligned dylibs with the pinned Rust/LLVM:
-- https://github.com/rust-lang/rust/issues/157750
return function()
  local blink = require("blink.cmp")
  local native = require("blink.lib.native")
  local name = blink.get_library_name()
  local commit = native.try_git_commit(blink.get_repo_root())
  local function loadable()
    local path = native.resolve(name, commit)
    if not path then return false, "Native matcher is missing" end
    local loader, err = package.loadlib(path, "luaopen_" .. name)
    return loader ~= nil, err
  end
  local available = loadable()
  if available then return end
  vim.api.nvim_out_write("Rebuilding Blink's missing or unloadable native matcher\n")

  -- Limit the workaround to this build and restore the inherited environment,
  -- including on failure. Preserve plugin sources and unrelated Cargo caches.
  local keys = { "CARGO_PROFILE_RELEASE_STRIP", "CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP" }
  local previous = {}
  for _, key in ipairs(keys) do
    previous[key] = vim.env[key]
    vim.env[key] = "none"
  end
  local ok, err = xpcall(function()
    local built, failure = blink.build({ force = true }):pwait()
    assert(built, "Blink native build failed: " .. tostring(failure))
    local loaded, load_error = loadable()
    assert(loaded, "Built Blink matcher cannot be loaded: " .. tostring(load_error))
  end, debug.traceback)
  for _, key in ipairs(keys) do vim.env[key] = previous[key] end
  assert(ok, err)
end
