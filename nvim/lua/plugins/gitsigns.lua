return {
	"lewis6991/gitsigns.nvim",
	opts = {
		signs = {
			add = { text = "▎" },
			change = { text = "▎" },
			delete = { text = "" },
			topdelete = { text = "" },
			changedelete = { text = "▎" },
			untracked = { text = "▎" },
		},
		signs_staged = {
			add = { text = "▎" },
			change = { text = "▎" },
			delete = { text = "" },
			topdelete = { text = "" },
			changedelete = { text = "▎" },
		},
		on_attach = function(bufnr)
			local gitsigns = require("gitsigns")

			local function map(mode, l, r, desc)
				vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
			end

			map("n", "]h", function()
				if vim.wo.diff then
					vim.cmd.normal({ "]c", bang = true })
				else
					gitsigns.nav_hunk("next")
				end
			end, "Next Hunk")
			map("n", "[h", function()
				if vim.wo.diff then
					vim.cmd.normal({ "[c", bang = true })
				else
					gitsigns.nav_hunk("prev")
				end
			end, "Prev Hunk")

			-- Actions
			map(
				{ "n", "v" },
				"<leader>ghs",
				":Gitsigns stage_hunk<CR>",
				"Stage Hunk"
			)
			map(
				{ "n", "v" },
				"<leader>ghr",
				":Gitsigns reset_hunk<CR>",
				"Reset Hunk"
			)
			map("n", "<leader>ghS", gitsigns.stage_buffer, "Stage Buffer")
			map(
				"n",
				"<leader>ghu",
				gitsigns.undo_stage_hunk,
				"Undo Stage Hunk"
			)
			map("n", "<leader>ghR", gitsigns.reset_buffer, "Reset Buffer")
			map(
				"n",
				"<leader>ghp",
				gitsigns.preview_hunk_inline,
				"Preview Hunk Inline"
			)
			map("n", "<leader>ghb", function()
				gitsigns.blame_line({ full = true })
			end, "Blame Line")
			map(
				"n",
				"<leader>ghB",
				gitsigns.toggle_current_line_blame,
				"Blame Toggle Current Line"
			)
			map("n", "<leader>ghd", gitsigns.diffthis, "Diff This")
			map("n", "<leader>ghD", function()
				gitsigns.diffthis("~")
			end, "Diff This ~")
		end,
	},
}
