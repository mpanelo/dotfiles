local bufferline = require("bufferline")

bufferline.setup({
	options = {
		mode = "buffers",
		diagnostics = "nvim_lsp",
		separator_style = "slant",
		color_icons = true,
		always_show_bufferline = false,
		show_buffer_close_icons = false,
		show_close_icon = false,
	},
})
