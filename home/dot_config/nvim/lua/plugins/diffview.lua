return {
	"sindrets/diffview.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	cmd = {
		"DiffviewOpen",
		"DiffviewClose",
		"DiffviewToggleFiles",
		"DiffviewFocusFiles",
		"DiffviewFileHistory",
	},
	keys = {
		{ "<leader>gdo", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
		{ "<leader>gdc", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
		{
			"<leader>gdt",
			"<cmd>DiffviewToggleFiles<cr>",
			desc = "Toggle Diffview Files",
		},
		{
			"<leader>gdh",
			"<cmd>DiffviewFileHistory %<cr>",
			desc = "Current File History",
		},
		{
			"<leader>gdH",
			"<cmd>DiffviewFileHistory<cr>",
			desc = "Branch History",
		},
	},
}
