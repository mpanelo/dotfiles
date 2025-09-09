-- When nonempty, shows the effects of |:substitute|, |:smagic|, |:snomagic|
-- and user commands with the |:command-preview| flag as you type. The 'split'
-- option shows the effects of a command incrementally in the buffer, but also
-- shows partial off-screen results in a preview window.

vim.opt.inccommand = "split"

-- The : command allows you to use the tab completion to find the longest common
-- match and then show the full list.
vim.opt.wildmode = "list:longest,list:full"

vim.opt.wildignore:append({ "node_modules", ".git" }) -- ignore certain files when using tab completion
vim.opt.suffixesadd:append({ ".java", ".rs" }) -- search for suffexes using gf

-- In Insert mode: Use the appropriate number of spaces to insert a
-- <Tab>. Spaces are used in indents with the '>' and '<' commands and
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

-- While typing a search command, show where the pattern matches so far
vim.opt.incsearch = true

-- Ignore case in search patterns
vim.opt.ignorecase = true

-- Override the 'ignorecase' option if the search pattern contains uppercase characters.
vim.opt.smartcase = true

-- Show line numbers
vim.opt.number = true

-- Relative line numbers to help with jumping
vim.o.relativenumber = true

-- Saves undo history to a file
vim.opt.undofile = true

-- Diagnostic
vim.diagnostic.config({
	underline = true,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "",
			[vim.diagnostic.severity.WARN] = "",
			[vim.diagnostic.severity.INFO] = "",
			[vim.diagnostic.severity.HINT] = "󰌵",
		},
	},
	virtual_text = false,
	float = {
		show_header = true,
		source = "if_many",
		border = "rounded",
		focusable = false,
	},
})

vim.api.nvim_create_autocmd("CursorMoved", {
	callback = function()
		local diagnostic = vim.diagnostic.get(0, { buf = 0, lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
		if #diagnostic > 0 then
			vim.diagnostic.open_float(0, { scope = "line", focusable = false })
		end
	end,
	desc = "Open diagnostic float on cursor move",
})
