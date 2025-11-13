return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"mason.nvim",
			{ "williamboman/mason-lspconfig.nvim", config = function() end },
		},
		config = function()
			-- local on_attach = function(_, bufnr)
			-- 	local function map(lhs, rhs, custom_opts)
			-- 		local opts = { noremap = true, silent = true, buffer = bufnr }
			-- 		for k, v in pairs(custom_opts) do
			-- 			opts[k] = v
			-- 		end
			-- 		vim.keymap.set("n", lhs, rhs, opts)
			-- 	end
			--
			-- 	map("gd", function()
			-- 		require("telescope.builtin").lsp_definitions({ reuse_win = true })
			-- 	end, { desc = "Goto Definition" })
			-- 	map("gr", "<cmd>Telescope lsp_references<cr>", { desc = "References", nowait = true })
			-- 	map("gy", function()
			-- 		require("telescope.builtin").lsp_type_definitions({ reuse_win = true })
			-- 	end, { desc = "Goto T[y]pe Definition" })
			-- end
		end,
	},
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
		build = ":MasonUpdate",
		opts = {
			ensure_installed = {
				"stylua",
				"shfmt",
				"goimports",
				"gofumpt",
			},
		},
	},
}
