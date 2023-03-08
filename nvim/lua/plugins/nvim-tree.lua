-- NvimTree Guide: https://docs.rockylinux.org/books/nvchad/nvchad_ui/nvimtree/
require("nvim-tree").setup({
	update_focused_file = {
		enable = true,
	},
})

local function open_nvim_tree(data)
	-- buffer is a real file on the disk
	local real_file = vim.fn.filereadable(data.file) == 1

	-- buffer is a [No Name]
	local no_name = data.file == "" and vim.bo[data.buf].buftype == ""

	if not real_file and not no_name then
		return
	end

	-- open the tree, find the file but don't focus it
	require("nvim-tree.api").tree.toggle({ focus = false, find_file = true })
end

-- open file upon creation
-- https://github.com/nvim-tree/nvim-tree.lua/wiki/Recipes#automatically-open-file-upon-creation
local api = require("nvim-tree.api")
api.events.subscribe(api.events.Event.FileCreated, function(file)
	vim.cmd("edit " .. file.fname)
end)

vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
