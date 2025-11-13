return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		lazy = false,
		main = "nvim-treesitter.configs",
		opts = {
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
				"nix",
				"python",
				"javascript",
				"typescript",
			},
			-- Install parsers synchronously (only applied to `ensure_installed`)
			sync_install = false,

			-- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
			auto_install = true,

			highlight = {
				enable = true,
				-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
				-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
				-- Using this option may slow down your editor, and you may see some duplicate highlights.
				-- Instead of true it can also be a list of languages
				additional_vim_regex_highlighting = false,
			},

			-- Indentation based on treesitter for the = operator. NOTE: This is an experimental feature.
			-- indent = { enable = true },
		},
	},
	{ "nvim-treesitter/nvim-treesitter-textobjects" },
}
