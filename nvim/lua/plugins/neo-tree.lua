return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
		"MunifTanjim/nui.nvim",
	},
	lazy = false, -- neo-tree will lazily load itself
	opts = {
		close_if_last_window = true, -- Close Neo-tree if it is the last window left in the tab
		filesystem = {
			filtered_items = {
				always_show = {
					".gitignore",
				},
				always_show_by_pattern = {
					".env",
				},
			},
		},
		follow_current_file = {
			enabled = true, -- This will find and focus the file in the active buffer every time
		},
		use_libuv_file_watcher = true,
	},
}
