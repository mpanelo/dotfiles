---@type vim.lsp.Config
return {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = {
		-- These are ordered by priority
		{
			".luarc.json",
			".luarc.jsonc",
		},
		{
			".luacheckrc",
			".stylua.toml",
			"stylua.toml",
		},
		{ ".git" },
	},
	settings = {
		Lua = {
			codeLens = { enable = true },
			hint = { enable = true, semicolon = "Disable" },
		},
	},
}
