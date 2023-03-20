-- TODO split configs into smaller files

-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

-- show line numbers
vim.opt.number = true

vim.cmd([[colorscheme tokyonight]])
-- vim.cmd([[colorscheme sonokai]])
-- vim.cmd([[colorscheme dracula]])

-- In Insert mode: Use the appropriate number of spaces to insert a
-- <Tab>.  Spaces are used in indents with the '>' and '<' commands and
-- when 'autoindent' is on.
vim.opt.expandtab = true

-- Copy indent from current line when starting a new line (typing <CR>
-- in Insert mode or when using the "o" or "O" command).
vim.opt.autoindent = true

-- Do smart autoindenting when starting a new line.
vim.opt.smartindent = true

-- TODO figure out how to change indentation based on filetype

-- Number of spaces that a <Tab> in the file counts for.
vim.opt.tabstop = 4

-- Number of spaces that a <Tab> counts for while performing editing
-- operations, like inserting a <Tab> or using <BS>.
vim.opt.softtabstop = 4

-- Number of spaces to use for each step of (auto)indent.
vim.opt.shiftwidth = 4
