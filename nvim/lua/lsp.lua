vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("my.lsp", {}),
	callback = function(args)
		local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
		local telescope = require("telescope.builtin")

		local function map(lhs, rhs, desc)
			vim.keymap.set(
				"n",
				lhs,
				rhs,
				{ silent = true, buffer = args.bufn, desc = desc }
			)
		end

		-- Wire mini.completion's LSP completefunc for *this buffer*.
		-- (You can use 'completefunc' instead if you prefer.)
		vim.bo[args.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"

		if client:supports_method("textDocument/implementation") then
			map("gI", telescope.lsp_implementations, "Go to Implementation")
		end
		if client:supports_method("textDocument/definition") then
			map("gd", telescope.lsp_definitions, "Go to Definition")
		end
		if client:supports_method("textDocument/references") then
			map("gr", telescope.lsp_references, "Go to References")
		end
	end,
})

-- Advertise to servers that Neovim now supports certain set of completion and
-- signature features through 'mini.completion'.
vim.lsp.config(
	"*",
	{ capabilities = require("mini.completion").get_lsp_capabilities() }
)

-- Taken from https://github.com/neovim/nvim-lspconfig/blob/master/lsp/lua_ls.lua
vim.lsp.config("lua_ls", {
	on_init = function(client)
		if client.workspace_folders then
			local path = client.workspace_folders[1].name
			if
				path ~= vim.fn.stdpath("config")
				and (
					vim.uv.fs_stat(path .. "/.luarc.json")
					or vim.uv.fs_stat(path .. "/.luarc.jsonc")
				)
			then
				return
			end
		end

		client.config.settings.Lua =
			vim.tbl_deep_extend("force", client.config.settings.Lua, {
				runtime = {
					-- Tell the language server which version of Lua you're using (most
					-- likely LuaJIT in the case of Neovim)
					version = "LuaJIT",
					-- Tell the language server how to find Lua modules same way as Neovim
					-- (see `:h lua-module-load`)
					path = {
						"lua/?.lua",
						"lua/?/init.lua",
					},
				},
				-- Make the server aware of Neovim runtime files
				workspace = {
					checkThirdParty = false,
					library = {
						vim.env.VIMRUNTIME,
						-- For LSP Settings Type Annotations: https://github.com/neovim/nvim-lspconfig#lsp-settings-type-annotations
						-- vim.api.nvim_get_runtime_file("lua/lspconfig", false)[1],
						-- Depending on the usage, you might want to add additional paths
						-- here.
						"${3rd}/luv/library",
						-- '${3rd}/busted/library',
					},
					-- Or pull in all of 'runtimepath'.
					-- NOTE: this is a lot slower and will cause issues when working on
					-- your own configuration.
					-- See https://github.com/neovim/nvim-lspconfig/issues/3189
					-- library = vim.api.nvim_get_runtime_file('', true),
				},
			})
	end,
	settings = {
		Lua = {},
	},
})

vim.lsp.enable("lua_ls")
vim.lsp.enable("gopls")
--vim.lsp.enable("ts_ls")
vim.lsp.enable("basedpyright")
