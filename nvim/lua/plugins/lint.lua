return {
	"mfussenegger/nvim-lint",
	opts = {
		linters_by_ft = {
			fish = {
				"fish",
			},
			javascript = {
				"eslint_d",
			},
			typescript = {
				"eslint_d",
			},
			javascriptreact = {
				"eslint_d",
			},
			typescriptreact = {
				"eslint_d",
			},
		},
	},
	config = function(_, opts)
		local lint = require("lint")

		lint.linters_by_ft = opts.linters_by_ft

		-- events = { "BufWritePost", "BufReadPost", "InsertLeave" },
		vim.api.nvim_create_autocmd({ "InsertLeave", "BufWritePost" }, {
			callback = function()
				lint.try_lint()
			end,
		})
	end,
}
