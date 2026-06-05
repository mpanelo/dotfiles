return {
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				python = { "ruff" },
				sh = { "shellcheck" },
				bash = { "shellcheck" },
				zsh = { "shellcheck" },
				markdown = { "vale" },
			},
		},
		config = function(_, opts)
			require("lint").linters_by_ft = opts.linters_by_ft
		end,
	},
}
