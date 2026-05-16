return {
	{
		"williamboman/mason.nvim",
		lazy = false,
		cmd = "Mason",
		keys = { { "<leader>M", "<cmd>Mason<cr>", desc = "Mason" } },
		build = ":MasonUpdate",
		opts = {
			ensure_installed = {
				-- "stylua",
				-- "shfmt",
				--"goimports",
				-- "gofumpt",
				"rust-analyzer",
				"codelldb",
				"gopls",
				"lua-language-server",
			},
		},
	},
}
