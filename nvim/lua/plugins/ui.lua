return {
	{
		"nvimdev/dashboard-nvim",
		event = "VimEnter",
		dependencies = { { "nvim-tree/nvim-web-devicons" } },
		opts = function()
			local logo = [[
███████╗██╗   ██╗███╗   ██╗██╗  ██╗███████╗██████╗ ███████╗███████╗██████╗
██╔════╝██║   ██║████╗  ██║██║ ██╔╝██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗
█████╗  ██║   ██║██╔██╗ ██║█████╔╝ █████╗  ██████╔╝█████╗  █████╗  ██║  ██║
██╔══╝  ██║   ██║██║╚██╗██║██╔═██╗ ██╔══╝  ██╔══██╗██╔══╝  ██╔══╝  ██║  ██║
██║     ╚██████╔╝██║ ╚████║██║  ██╗██║     ██║  ██║███████╗███████╗██████╔╝
╚═╝      ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝
            ]]

			logo = string.rep("\n", 8) .. logo .. "\n\n"
			local opts = {
				theme = "doom",
				config = {
					header = vim.split(logo, "\n"),
					center = {
						{
							action = "Lazy update",
							desc = " Update Plugins",
							icon = "󰊳 ",
							key = "u",
							-- group = "@property",
						},
						{
							action = function()
								vim.api.nvim_input("<cmd>qa<cr>")
							end,
							desc = " Quit",
							icon = " ",
							key = "q",
						},
					},
				},
			}
			return opts
		end,
	},
}
