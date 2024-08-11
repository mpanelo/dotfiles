return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			local configs = require("nvim-treesitter.configs")

			configs.setup({
				ensure_installed = {
					"lua",
					"luadoc",
					"markdown",
					"vim",
					"vimdoc",
					"query",
					"go",
					"gomod",
					"gowork",
					"gosum",
					"comment",
					"json",
					"yaml",
				},
				sync_install = false,
				highlight = { enable = true },
				indent = { enable = true },
			})
		end,
	},
}
