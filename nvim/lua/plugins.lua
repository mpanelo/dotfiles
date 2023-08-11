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
	use({
		"neovim/nvim-lspconfig",
		config = function()
			require("plugins.lspconfig")
		end,
	})

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

	use({
		"jose-elias-alvarez/null-ls.nvim",
		requires = {
			"nvim-lua/plenary.nvim",
		},
		config = [[ require("plugins.null-ls") ]],
	})

	use("folke/tokyonight.nvim")

	-- Treesittter
	-- Recommended installation https://github.com/nvim-treesitter/nvim-treesitter/wiki/Installation#packernvim
	use({
		"nvim-treesitter/nvim-treesitter",
		run = function()
			local ts_update = require("nvim-treesitter.install").update({ with_sync = true })
			ts_update()
		end,
		config = [[ require("plugins.nvim-treesitter") ]],
	})

	-- Telescope used to fuzzy search files
	use({
		"nvim-telescope/telescope.nvim",
		tag = "0.1.1",
		requires = {
			{ "nvim-lua/plenary.nvim" },
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				run = "make",
			},
		},
		config = [[ require("plugins.telescope") ]],
	})

	use("nvim-tree/nvim-web-devicons")

	use({
		"nvim-lualine/lualine.nvim",
		requires = { "nvim-tree/nvim-web-devicons", opt = true },
		config = [[ require("lualine").setup({}) ]],
	})

	use({
		"lukas-reineke/indent-blankline.nvim",
		requires = {
			"nvim-treesitter/nvim-treesitter",
		},
		config = [[ require("plugins.indent-blankline") ]],
	})

	use({
		"goolord/alpha-nvim",
		requires = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("alpha").setup(require("alpha.themes.startify").config)
		end,
	})

	use({
		"lewis6991/gitsigns.nvim",
		-- tag = 'release' -- To use the latest release (do not use this if you run Neovim nightly or dev builds!)
		config = [[ require("plugins.gitsigns") ]],
	})

	use({
		"nvim-telescope/telescope-file-browser.nvim",
		requires = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
	})
end)
