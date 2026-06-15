return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		lazy = false,
		config = function()
			require("nvim-treesitter").install({
				"lua",
				"luadoc",
				"markdown",
				"markdown_inline",
				"vim",
				"vimdoc",
				"query",
				"go",
				"gomod",
				"gowork",
				"gosum",
				"comment",
				"python",
				"javascript",
				"typescript",
				"json",
				"rust",
				"yaml",
				"toml",
				"groovy",
			})
			vim.api.nvim_create_autocmd("FileType", {
				pattern = {
					"go", "gomod", "gowork", "gosum",
					"python",
					"rust",
					"javascript", "typescript",
					"json",
					"yaml", "toml",
					"groovy",
					"comment",
					"vim", "vimdoc",
				},
				callback = function()
					vim.treesitter.start()
				end,
			})
		end,
	},
	{ "nvim-treesitter/nvim-treesitter-textobjects" },
}
