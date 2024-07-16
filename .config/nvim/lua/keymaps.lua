local map = vim.keymap.set

map("n", "<leader>sr", ":%s/<C-r><C-w>//g<Left><Left>")
map("i", ",", ",<C-g>U")
