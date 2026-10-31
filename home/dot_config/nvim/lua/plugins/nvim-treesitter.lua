local parsers = require("config.treesitter")

return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = function()
			-- Skip the update when tree-sitter-cli is not installed.
			if vim.fn.executable("tree-sitter") == 1 then
				vim.cmd("TSUpdate")
			end
		end,
		lazy = false,
		config = function()
			if vim.env.DOTFILES_VERIFY_ONLY ~= "1" and vim.env.DOTFILES_PROVISIONING ~= "1" then
				require("nvim-treesitter").install(parsers)
			end
			vim.api.nvim_create_autocmd("FileType", {
				pattern = {
					"go",
					"gomod",
					"gowork",
					"gosum",
					"python",
					"rust",
					"javascript",
					"typescript",
					"json",
					"yaml",
					"toml",
					"groovy",
					"comment",
					"vim",
					"vimdoc",
				},
				callback = function()
					vim.treesitter.start()
				end,
			})
		end,
	},
}
