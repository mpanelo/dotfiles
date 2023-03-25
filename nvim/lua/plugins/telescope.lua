local telescope = require("telescope")

telescope.setup({
	defaults = {
		layout_strategy = "horizontal",
		layout_config = { prompt_position = "top" },
		selection_strategy = "reset",
		sorting_strategy = "ascending",
		color_devicons = true,
	},
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

telescope.load_extension("fzf")
