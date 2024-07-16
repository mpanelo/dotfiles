return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"mason.nvim",
			{ "williamboman/mason-lspconfig.nvim", config = function() end },
		},
		config = function()
			local lspconfig = require("lspconfig")
			local lsp_capabilities = require("cmp_nvim_lsp").default_capabilities()

			local on_attach = function(_, bufnr)
				local function map(lhs, rhs, custom_opts)
					local opts = { noremap = true, silent = true, buffer = bufnr }
					for k, v in pairs(custom_opts) do
						opts[k] = v
					end
					vim.keymap.set("n", lhs, rhs, opts)
				end

				map("gd", function()
					require("telescope.builtin").lsp_definitions({ reuse_win = true })
				end, { desc = "Goto Definition" })
				map("gr", "<cmd>Telescope lsp_references<cr>", { desc = "References", nowait = true })
				map("gI", function()
					require("telescope.builtin").lsp_implementations({ reuse_win = true })
				end, { desc = "Goto Implementation" })
				map("gy", function()
					require("telescope.builtin").lsp_type_definitions({ reuse_win = true })
				end, { desc = "Goto T[y]pe Definition" })
			end

			lspconfig.gopls.setup({
				on_attach = on_attach,
				capabilities = lsp_capabilities,
				settings = {
					gopls = {
						gofumpt = true,
						hints = {
							functionTypeParameters = true,
							parameterNames = true,
							constantValues = true,
							rangeVariableTypes = true,
						},
						analyses = {
							unusedparams = true,
							useany = true,
						},
						staticcheck = true,
						directoryFilters = { "-.git", "-.vscode", "-.idea", "-.vscode-test", "-node_modules" },
					},
				},
			})

			lspconfig.tsserver.setup({
				on_attach = on_attach,
				capabilities = lsp_capabilities,
			})

			lspconfig.lua_ls.setup({
				on_attach = on_attach,
				capabilities = lsp_capabilities,
				settings = {
					Lua = {
						diagnostics = {
							-- Get the language server to recognize the `vim` global
							globals = {
								"vim",
							},
						},
					},
				},
			})
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
