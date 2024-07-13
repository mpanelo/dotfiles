return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function () 
			local configs = require("nvim-treesitter.configs")

			configs.setup({
			  ensure_installed = { "lua", "luadoc", "markdown", "vim", "vimdoc", "query" },
			  sync_install = false,
			  highlight = { enable = true },
			  indent = { enable = true },  
			})
	        end
	}
}
