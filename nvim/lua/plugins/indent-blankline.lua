local indent_blankline = require("indent_blankline")

indent_blankline.setup({
	use_treesitter = true,
	show_trailing_blankline_indent = false,
	show_current_context = true,
	show_first_indent_level = true,
})
