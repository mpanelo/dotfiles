vim.cmd([[colorscheme tokyonight]])

-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

-- Show line numbers
vim.opt.number = true
-- Show the line number relative to the line with the cursor in front of each line.
vim.opt.relativenumber = true

-- In Insert mode: Use the appropriate number of spaces to insert a
-- <Tab>.  Spaces are used in indents with the '>' and '<' commands and
-- when 'autoindent' is on.
vim.opt.expandtab = true

-- Copy indent from current line when starting a new line (typing <CR>
-- in Insert mode or when using the "o" or "O" command).
vim.opt.autoindent = true

-- Do smart autoindenting when starting a new line.
vim.opt.smartindent = true

-- Number of spaces that a <Tab> in the file counts for.
vim.opt.tabstop = 4

-- Number of spaces that a <Tab> counts for while performing editing
-- operations, like inserting a <Tab> or using <BS>.
vim.opt.softtabstop = 4

-- Number of spaces to use for each step of (auto)indent.
vim.opt.shiftwidth = 4

-- While typing a search command, show where the pattern, as it was typed so far, matches.
vim.opt.incsearch = true
-- Ignore case in search patterns.
vim.opt.ignorecase = true
-- Override the 'ignorecase' option if the search pattern contains upper case characters.
vim.opt.smartcase = true
