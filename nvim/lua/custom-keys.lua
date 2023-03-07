-- fetch keymap
local map = vim.api.nvim_set_keymap

-- map the key n to run the command :NvimTreeToggle
map('n', '<Leader>n', [[:NvimTreeToggle<CR>]], {})

map('n', '<Leader>lf', [[:lua vim.lsp.buf.format({ timeout_ms = 2000 })<CR>]], {})
