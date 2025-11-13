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
					F = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
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
	{
		"nvim-mini/mini.completion",
		version = false,
		opts = function()
			local completion = require("mini.completion")

			-- Customize post-processing of LSP responses for a better user experience.
			-- Don't show 'Text' suggestions (usually noisy) and show snippets last.
			local process_items_opts = { kind_priority = { Text = -1, Snippet = 99 } }
			local process_items = function(items, base)
				return completion.default_process_items(items, base, process_items_opts)
			end

			return {
				lsp_completion = {
					-- Without this config autocompletion is set up through `:h 'completefunc'`.
					-- Although not needed, setting up through `:h 'omnifunc'` is cleaner
					-- (sets up only when needed) and makes it possible to use `<C-u>`.
					source_func = "omnifunc",
					auto_setup = false,
					process_items = process_items,
				},
			}
		end,
	},
	{
		"nvim-mini/mini.snippets",
		version = false,
		config = function()
			-- Define language patterns to work better with 'friendly-snippets'
			local latex_patterns = { "latex/**/*.json", "**/latex.json" }
			local lang_patterns = {
				tex = latex_patterns,
				plaintex = latex_patterns,
				-- Recognize special injected language of markdown tree-sitter parser
				markdown_inline = { "markdown.json" },
			}

			local snippets = require("mini.snippets")
			-- local config_path = vim.fn.stdpath('config')
			snippets.setup({
				snippets = {
					-- Always load 'snippets/global.json' from config directory
					-- snippets.gen_loader.from_file(config_path .. '/snippets/global.json'),
					-- Load from 'snippets/' directory of plugins, like 'friendly-snippets'
					snippets.gen_loader.from_lang({ lang_patterns = lang_patterns }),
				},
			})

			snippets.start_lsp_server()
		end,
	},
	{
		"nvim-mini/mini.keymap",
		version = false,
		config = function()
			local map_multistep = require("mini.keymap").map_multistep

			map_multistep("i", "<Tab>", { "pmenu_next" })
			map_multistep("i", "<S-Tab>", { "pmenu_prev" })
			map_multistep("i", "<CR>", { "pmenu_accept", "minipairs_cr" })
			map_multistep("i", "<BS>", { "minipairs_bs" })
		end,
	},
}
