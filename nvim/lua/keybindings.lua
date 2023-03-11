local map = vim.api.nvim_set_keymap

---------------
-- nvim-tree --
---------------
map("n", "<Leader>n", [[:NvimTreeToggle<CR>]], {})

----------------
-- lsp-config --
----------------
map("n", "<Leader>lf", [[:lua vim.lsp.buf.format({ timeout_ms = 2000 })<CR>]], {})

---------------
-- telescope --
---------------
local builtin = require("telescope.builtin")

-- Lists files in your current working directory, including hidden ones
map("n", "<leader>ff", ':lua require("telescope.builtin").find_files({ no_ignore = true, hidden = true })<CR>', {})

-- Live fuzzy search inside of the currently open buffer
vim.keymap.set("n", "<leader>fc", builtin.current_buffer_fuzzy_find, {})

-- Search for a string in your current working directory and get results
-- live as you type, respects .gitignore
vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})

-- Lists open buffers in current neovim instance
vim.keymap.set("n", "<leader>fb", builtin.buffers, {})

-- Lists available help tags and opens a new window with the relevant
-- help info on <cr>
vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})

-- Lists function names and variables from Treesitter
vim.keymap.set("n", "<leader>ft", builtin.treesitter, {})
