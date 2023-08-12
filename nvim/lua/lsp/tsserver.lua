local M = {}

M.setup = function(on_attach, capabilities)
	local lspconfig = require("lspconfig")

	lspconfig.tsserver.setup({
		on_attach = on_attach,
		capabilities = capabilities,
		filetypes = {
			"javascript",
			"javascriptreact",
			"typescript",
			"typescriptreact",
			"typescript.tsx",
		},
	})
end

return M
