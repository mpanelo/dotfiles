-- NvimTree Guide: https://docs.rockylinux.org/books/nvchad/nvchad_ui/nvimtree/
require("nvim-tree").setup({
	update_focused_file = {
		enable = true,
	},
})

-- open file upon creation
-- https://github.com/nvim-tree/nvim-tree.lua/wiki/Recipes#automatically-open-file-upon-creation
local api = require("nvim-tree.api")
api.events.subscribe(api.events.Event.FileCreated, function(file)
	vim.cmd("edit " .. file.fname)
end)
