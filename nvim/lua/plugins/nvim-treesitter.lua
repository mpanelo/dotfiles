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
			require("nvim-treesitter").install(parsers)
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
