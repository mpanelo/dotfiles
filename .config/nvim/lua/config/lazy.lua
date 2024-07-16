-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out,                            "WarningMsg" },
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
vim.g.mapleader = ","        -- Change default \ to ,
vim.opt.ignorecase = true    -- search case insensitive
vim.opt.smartcase = true     -- search matters if capital letter
vim.opt.inccommand = "split" -- "for incsearch while sub

-- The : command allows you to use the tab completion to find the longest common
-- match and then show the full list.
vim.opt.wildmode = "list:longest,list:full"

vim.opt.wildignore:append({ "node_modules", ".git" }) -- ignore certain files when using tab completion
vim.opt.suffixesadd:append({ ".java", ".rs" })        -- search for suffexes using gf
vim.opt.undofile = true                               -- save undo history

-- In Insert mode: Use the appropriate number of spaces to insert a
-- <Tab>. Spaces are used in indents with the '>' and '<' commands and
-- when 'autoindent' is on.
vim.opt.expandtab = true

-- Copy indent from current line when starting a new line (typing <CR>
-- in Insert mode or when using the "o" or "O" command).
vim.opt.autoindent = true

-- Do smart autoindenting when starting a new line.
vim.opt.smartindent = true

-- Number of spaces that a <Tab> in the file counts for.
vim.opt.tabstop = 4

-- Number of spaces that a <Tab> counts for while performing editing
-- operations, like inserting a <Tab> or using <BS>.
vim.opt.softtabstop = 4

-- Number of spaces to use for each step of (auto)indent.
vim.opt.shiftwidth = 4


-- Setup lazy.nvim
require("lazy").setup({
    spec = {
        -- import your plugins
        { import = "plugins" },
    },
    -- Configure any other settings here. See the documentation for more details.
    -- colorscheme that will be used when installing plugins.
    install = { colorscheme = { "habamax" } },
    -- automatically check for plugin updates
    checker = { enabled = true },
})
