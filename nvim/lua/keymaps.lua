local function close_diagnostic_float()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_get_config(win).relative ~= "" then
			vim.api.nvim_win_close(win, true)
		end
	end
end

local wk = require("which-key")

wk.add({
	{
		"<leader>sr",
		":%s/<C-r><C-w>//g<Left><Left>",
		desc = "Search/Replace Word",
	},
	{ "<leader>od", vim.diagnostic.open_float, desc = "Open Diagnostic Float" },
	{ "<leader>cd", close_diagnostic_float, desc = "Close Diagnostic Float" },
	{
		"<leader>e",
		":Neotree filesystem reveal left toggle<CR>",
		desc = "Open Neotree",
		icon = "󰙅",
	},
	{
		"<leader>Es",
		":Neotree filesystem show left toggle<CR>",
		desc = "Show Neotree (no focus)",
		icon = "󰙅",
	},
	{
		"<leader>Eg",
		":Neotree git_status reveal left toggle<CR>",
		desc = "Open Neotree git status",
		icon = "󰙅",
	},
	{ ",", ",<C-g>U", mode = "i" },
})
