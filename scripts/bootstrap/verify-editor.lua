local parsers = require("config.treesitter")
for _, parser in ipairs(parsers) do
  assert(pcall(vim.treesitter.language.add, parser), "Missing parser: " .. parser)
end
require("telescope").load_extension("fzf")
assert(pcall(require, "telescope._extensions.fzf"), "Telescope native extension failed to load")
assert(require("blink.cmp").library_available(), "Blink's native matcher is missing")
require("blink.cmp.fuzzy").set_implementation("rust")
for _, tool in ipairs({ "gopls", "goimports", "gofumpt", "rust-analyzer", "basedpyright-langserver", "ruff", "lua-language-server", "stylua" }) do
  local path = vim.fn.exepath(tool)
  assert(path ~= "", "Missing editor tool: " .. tool)
  assert(not path:find("/mason/", 1, true), "Mason executable shadows managed tool: " .. tool)
end
