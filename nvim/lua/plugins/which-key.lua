return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		spec = {
			{
				mode = { "n", "v" },
				{ "<leader>b", group = "Buffers", icon = "󰈢" },
				{ "<leader>bb", icon = "󰈢" },
				{
					"<leader>E",
					group = "Neo-tree (extended)",
					icon = "󰙅",
				},
				{ "<leader>f", group = "File/Find" },
				{ "<leader>g", group = "Git" },
				{ "<leader>gh", group = "Hunks" },
				{ "<leader>o", group = "Open" },
				{ "<leader>s", group = "Search" },
				{ "<leader>x", group = "Diagnostics" },
				{ "[", group = "Prev" },
				{ "]", group = "Next" },
			},
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
}
