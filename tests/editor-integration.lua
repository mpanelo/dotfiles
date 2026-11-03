-- Runs only with the freshly built, isolated editor integration harness.
local ok, err = xpcall(function()
  assert(vim.env.DOTFILES_ISOLATED_TEST == "1" and vim.env.DOTFILES_VERIFY_ONLY == "1")
  local spec = vim.json.decode(vim.env.DOTFILES_EDITOR_CASE)
  local file = vim.env.DOTFILES_EDITOR_PROJECT .. "/" .. spec.file
  vim.cmd.edit(vim.fn.fnameescape(file))
  local buffer = vim.api.nvim_get_current_buf()
  local client
  assert(vim.wait(120000, function()
    for _, candidate in ipairs(vim.lsp.get_clients({ bufnr = buffer })) do
      if candidate.name:find(spec.client, 1, true) and candidate.initialized then
        client = candidate
        return true
      end
    end
  end, 100), "Language server did not attach: " .. spec.client)
  assert(client.root_dir == vim.env.DOTFILES_EDITOR_PROJECT, "Wrong language-server workspace")
  local command = client.config.cmd
  assert(type(command) == "table" and not table.concat(command, " "):find("/mason/", 1, true))
  assert(vim.fn.exepath("node") == "" and vim.fn.exepath("npm") == "", "Global Node/npm leaked into test PATH")

  local line = vim.api.nvim_buf_get_lines(buffer, spec.call_line, spec.call_line + 1, false)[1]
  local column = assert(line:find("answer", 1, true)) - 1
  vim.api.nvim_win_set_cursor(0, { spec.call_line + 1, column + 3 })
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local function request(method, accept)
    local value
    assert(vim.wait(60000, function()
      local response = client:request_sync(method, params, 3000, buffer)
      if response and not response.err and response.result and accept(response.result) then
        value = response.result
        return true
      end
    end, 100), "No useful result from " .. method .. " for " .. spec.client)
    return value
  end
  request("textDocument/completion", function(result)
    for _, item in ipairs(result.items or result) do
      if item.label:find("answer", 1, true) then return true end
    end
    return false
  end)
  request("textDocument/definition", function(result)
    local location = result.uri and result or result[1]
    return location and vim.uri_to_fname(location.uri or location.targetUri) == file
  end)
  if spec.diagnostic_line then
    assert(vim.wait(60000, function()
      for _, diagnostic in ipairs(vim.diagnostic.get(buffer)) do
        if diagnostic.lnum == spec.diagnostic_line and diagnostic.severity <= vim.diagnostic.severity.WARN then
          return true
        end
      end
    end, 100), "Expected type diagnostic was not published: " .. spec.client)
  end

  -- Exercise the configured format-on-save path, including Rust's LSP fallback.
  local before = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n")
  vim.cmd.write()
  local after = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n")
  assert(after ~= before, "Format-on-save did not change the sample: " .. spec.client)
  assert(after:find(spec.formatted, 1, true), "Unexpected formatter output: " .. spec.client)
  assert(#(_G.dotfiles_startup_errors or {}) == 0, table.concat(_G.dotfiles_startup_errors or {}, "\n"))
  io.stdout:write("DOTFILES_EDITOR_CASE_OK: " .. spec.client .. "\n")
  vim.lsp.stop_client(vim.lsp.get_clients(), true)
end, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
