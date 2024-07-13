local map = vim.keymap.set

map("n", "<leader>sr", ":%s/<C-r><C-w>//g<Left><Left>")
map("i", ",", ",<C-g>U")

-- Telescope
map("n", "<leader>ff", ":Telescope find_files<CR>")
map("n", "<leader><leader>f", ":Telescope git_files<CR>")
map("n", "<leader>fg", ":Telescope live_grep<CR>")
map("n", "<leader>fb", ":Telescope buffers<CR>")
map("n", "<leader>fm", ":Telescope man_pages<CR>")
map("n", "<leader>ft", ":Telescope treesitter<CR>")
map("n", "<leader>fk", ":Telescope keymaps<CR>")
map("n", "<leader>fh", ":Telescope help_tags<CR>")
