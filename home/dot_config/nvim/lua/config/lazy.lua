-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    assert(vim.env.DOTFILES_VERIFY_ONLY ~= "1", "lazy.nvim is missing; run bootstrap first")
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
	local out = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--no-checkout",
		lazyrepo,
		lazypath,
	})
	if vim.v.shell_error == 0 then
		out = vim.fn.system({ "git", "-C", lazypath, "checkout", "--detach", lock["lazy.nvim"].commit })
	end
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = "," -- Change default \ to ,

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- import your plugins
		{ import = "plugins" },
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
    install = {
        missing = vim.env.DOTFILES_VERIFY_ONLY ~= "1",
        colorscheme = { "habamax" },
    },
	-- automatically check for plugin updates
	checker = {
        enabled = vim.env.DOTFILES_VERIFY_ONLY ~= "1" and vim.env.DOTFILES_PROVISIONING ~= "1",
        notify = false,
    },
})
