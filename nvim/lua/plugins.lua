local ok, packer = pcall(require, "packer")
if not ok then
	print("Module 'packer' is not installed")
	return
end

-- vim.cmd([[packadd packer.nvim]])

return packer.startup(function(use)
	-- Packer can manage itself
	use("wbthomason/packer.nvim")

	-- Portable package manager
	use("williamboman/mason.nvim")
	use("williamboman/mason-lspconfig.nvim")

	-- Configurations for Nvim LSP
	use("neovim/nvim-lspconfig")

	-- Snippets collection for a set of different programming languages
	-- https://github.com/rafamadriz/friendly-snippets
	use("rafamadriz/friendly-snippets")

	-- Hrsh7th Code Completion Suite
	use("hrsh7th/nvim-cmp")
	use("hrsh7th/cmp-nvim-lsp")
	use("hrsh7th/cmp-nvim-lua")
	use("hrsh7th/cmp-nvim-lsp-signature-help")
	use("hrsh7th/cmp-path")
	use("hrsh7th/cmp-buffer")

	-- Snippets
	-- https://github.com/neovim/nvim-lspconfig/wiki/Snippets#nvim-cmp-and-luasnip
	use("saadparwaiz1/cmp_luasnip")
	use({
		"L3MON4D3/LuaSnip",
		config = function()
			require("luasnip/loaders/from_vscode").lazy_load()
		end,
	})

	-- VS-Code like pictograms
	use("onsails/lspkind.nvim")

	-- File explorer tree
	use({
		"nvim-tree/nvim-tree.lua",
		requires = {
			"nvim-tree/nvim-web-devicons", -- optional, for file icons
		},
	})

	use({
		"jose-elias-alvarez/null-ls.nvim",
		requires = {
			"nvim-lua/plenary.nvim",
		},
	})

	-- Dracula theme for styling
	use("Mofiqul/dracula.nvim")

	-- Treesittter
	-- Recommended installation https://github.com/nvim-treesitter/nvim-treesitter/wiki/Installation#packernvim
	use({
		"nvim-treesitter/nvim-treesitter",
		run = function()
			local ts_update = require("nvim-treesitter.install").update({ with_sync = true })
			ts_update()
		end,
	})

	-- Telescope used to fuzzy search files
	use({
		"nvim-telescope/telescope.nvim",
		tag = "0.1.1",
		requires = { { "nvim-lua/plenary.nvim" } },
	})

	-- Lualine information / Status bar
	use({
		"nvim-lualine/lualine.nvim",
		requires = { "nvim-tree/nvim-web-devicons", opt = true },
	})
end)
