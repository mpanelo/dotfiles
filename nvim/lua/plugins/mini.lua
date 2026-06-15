-- plugins/mini.lua
return {
	-- See LazyVim configuration for ideas: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/coding.lua#L37-L71
	-- Note which key won't display for text objects. Check how LazyVim does it -> https://github.com/LazyVim/LazyVim/blob/8ba7c64a7da9e46f2ac601919508803824208935/lua/lazyvim/util/mini.lua#L63-L110
	{
		"nvim-mini/mini.ai",
		version = false,
		opts = function()
			local ai = require("mini.ai")
			return {
				n_lines = 100,
				-- 'mini.ai' can be extended with custom textobjects
				custom_textobjects = {
					-- Make `aB` / `iB` act on around/inside whole *b*uffer
					-- B = MiniExtra.gen_ai_spec.buffer(),
					-- For more complicated textobjects that require structural awareness,
					-- use tree-sitter. This example makes `aF`/`iF` mean around/inside function
					-- definition (not call). See `:h MiniAi.gen_spec.treesitter()` for details.
					F = ai.gen_spec.treesitter({
						a = "@function.outer",
						i = "@function.inner",
					}),
				},

				-- 'mini.ai' by default mostly mimics built-in search behavior: first try
				-- to find textobject covering cursor, then try to find to the right.
				-- Although this works in most cases, some are confusing. It is more robust to
				-- always try to search only covering textobject and explicitly ask to search
				-- for next (`an`/`in`) or last (`al`/`il`).
				-- Try this. If you don't like it - delete next line and this comment.
				search_method = "cover",
			}
		end,
	},
	{ "nvim-mini/mini.align", version = false, opts = {} },
	{ "nvim-mini/mini.comment", version = false },
	{ "nvim-mini/mini.icons", version = false },
}
