return {
	"williamboman/mason.nvim",
	lazy = false,
	cmd = "Mason",
	keys = { { "<leader>M", "<cmd>Mason<cr>", desc = "Mason" } },
	build = ":MasonUpdate",
}
