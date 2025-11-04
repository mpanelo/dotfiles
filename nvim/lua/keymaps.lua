local function close_diagnostic_float()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_get_config(win).relative ~= "" then
			vim.api.nvim_win_close(win, true)
		end
	end
end

local map = vim.keymap.set

map("n", "<leader>sr", ":%s/<C-r><C-w>//g<Left><Left>")
map("i", ",", ",<C-g>U")

-- Diagnostic
map("n", "<leader>od", vim.diagnostic.open_float)
map("n", "<leader>cd", close_diagnostic_float, { desc = "Close diagnostic float" })
