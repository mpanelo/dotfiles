local util = require("lspconfig/util")

local M = {}

M.setup = function(on_attach, capabilities)
	local lspconfig = require("lspconfig")

	lspconfig.gopls.setup({
		on_attach = on_attach,
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
end

return M
