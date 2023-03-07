local lspconfig = require("lspconfig")
local util = require("lspconfig/util")

local capabilities = require("cmp_nvim_lsp").default_capabilities()

lspconfig.gopls.setup({
	capabilities = capabilities,
	cmd = { "gopls", "serve" },
	filetypes = { "go", "gomod" },
	root_dir = util.root_pattern("go.work", "go.mod", ".git"),
	settings = {
		gopls = {
			analyses = {
				unusedparams = true,
			},
			staticcheck = true,
		},
	},
})
