local wk = require("which-key")

wk.add({
	{
		"<leader>sr",
		":%s/<C-r><C-w>//g<Left><Left>",
		desc = "Search/Replace Word",
	},
	{
		"<leader>e",
		":Neotree filesystem reveal left toggle<CR>",
		desc = "Neotree",
		icon = "󰙅",
	},
	{
		"<leader>Es",
		":Neotree filesystem show left toggle<CR>",
		desc = "Neotree (no focus)",
		icon = "󰙅",
	},
	{
		"<leader>Eg",
		":Neotree git_status reveal left toggle<CR>",
		desc = "Neotree git status",
		icon = "󰙅",
	},
	{
		"<leader>bd",
		":bdelete<CR>",
		desc = "Delete Buffer",
		icon = "󰅖",
	},
	{ ",", ",<C-g>U", mode = "i" },
})
