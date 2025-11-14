return {
	"nvim-telescope/telescope.nvim",
	tag = "v0.1.9",
	dependencies = {
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-lua/plenary.nvim" },
		{
			"nvim-telescope/telescope-live-grep-args.nvim",
			-- This will not install any breaking changes.
			-- For major updates, this must be adjusted manually.
			version = "^1.0.0",
		},
	},
	keys = {
		-- { "<leader>/", "<cmd>Telescope live_grep<cr>", desc = "Grep" },
		{ "<leader>/", "<cmd>Telescope live_grep_args<cr>", desc = "Grep" },
		-- Find
		{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find File" },
		{ "<leader>fb", "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
		{ "<leader>fg", "<cmd>Telescope git_files<cr>", desc = "Find File (git-files)" },
		{ "<leader>fr", "<cmd>Telescope oldfiles cwd_only=true<cr>", desc = "Recent" },
		-- Git
		{ "<leader>gc", "<cmd>Telescope git_commits<cr>", desc = "Commits" },
		-- Search
		{ "<leader>sc", "<cmd>Telescope command_history<cr>", desc = "Command History" },
		{ "<leader>sh", "<cmd>Telescope help_tags<cr>", desc = "Search Help Pages" },
		{ "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Search Man Pages" },
	},
	config = function(_, opts)
		local telescope = require("telescope")

		telescope.setup(opts)

		telescope.load_extension("fzf")
		telescope.load_extension("live_grep_args")
	end,
}
