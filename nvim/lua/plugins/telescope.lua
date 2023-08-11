local telescope = require("telescope")

telescope.setup({
	defaults = {
		layout_strategy = "horizontal",
		layout_config = {
			height = 0.95,
			width = 0.95,
		},
		path_display = {
			shorten = {
				len = 1,
				exclude = { -2, -1 },
			},
		},
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
	extensions = {
		file_browser = {
			theme = "ivy",
			-- disables netrw and use telescope-file-browser in its place
			hijack_netrw = true,
		},
	},
})

telescope.load_extension("file_browser")
telescope.load_extension("fzf")
