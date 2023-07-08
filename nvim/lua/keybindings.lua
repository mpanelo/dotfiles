-- TODO use which-key
local map = vim.api.nvim_set_keymap

map("n", "<space>fb", ":Telescope file_browser path=%:p:h select_buffer=true<CR>", { noremap = true })
map("n", "<space>fe", ":Telescope file_browser<CR>", { noremap = true })

----------------
-- lsp-config --
----------------
map("n", "<Leader>lf", [[:lua vim.lsp.buf.format({ timeout_ms = 2000 })<CR>]], {})

---------------
-- telescope --
---------------
local builtin = require("telescope.builtin")

-- Lists files in your current working directory
vim.keymap.set("n", "<leader>ff", builtin.find_files, {})

-- Lists all files in your current working directory, including git ignored and hidden files
vim.keymap.set("n", "<leader>fa", function()
	builtin.find_files({ no_ignore = true, hidden = true })
end, {})

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

vim.keymap.set("n", "<leader>bn", "<cmd>bn<CR>", { desc = "Next" })
vim.keymap.set("n", "<leader>bp", "<cmd>bp<CR>", { desc = "Previous" })
