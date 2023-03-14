local telescope = require("telescope")

telescope.setup({
	pickers = {
		buffers = {
			show_all_buffers = true,
			sort_mru = true,
			mappings = {
				i = {
					["<C-d>"] = "delete_buffer",
				},
			},
		},
	},
})
