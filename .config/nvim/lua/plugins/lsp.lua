return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"mason.nvim",
		"williamboman/mason-lspconfig.nvim",
	},
	config = function()
		require("mason").setup()
		require("mason-lspconfig").setup()

		local lspconfig = require('lspconfig')

		lspconfig.gopls.setup {
		}

		lspconfig.tsserver.setup {
		}

		lspconfig.lua_ls.setup {
			settings = {
				Lua = {
					diagnostics = {
						-- Get the language server to recognize the `vim` global
						globals = {
							'vim',
						}
					}
				},
			},
		}
	end
}
