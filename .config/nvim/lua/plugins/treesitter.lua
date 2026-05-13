return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		dependencies = {
			{ "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
		},
		build = ":TSUpdate",
		config = function()
			-- Install parsers
			local parsers = {
				"bash",
				"css",
				"dockerfile",
				"go",
				"graphql",
				"html",
				"javascript",
				"json",
				"lua",
				"python",
				"regex",
				"rust",
				"scss",
				"toml",
				"tsx",
				"typescript",
				"yaml",
				"markdown",
				"markdown_inline",
			}
			require("nvim-treesitter").install(parsers)

			-- Enable highlighting and indentation for all filetypes with a parser
			vim.api.nvim_create_autocmd("FileType", {
				callback = function()
					if pcall(vim.treesitter.start) then
						vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
			})

			-- Disable folding
			vim.o.foldenable = false

			require("nvim-treesitter-textobjects").setup({
				select = {
					lookahead = true,
					include_surrounding_whitespace = false,
				},
				move = {
					set_jumps = true,
				},
			})

			-- Textobject select keymaps
			local select = require("nvim-treesitter-textobjects.select")
			local select_keymaps = {
				["ib"] = "@block.inner",
				["ab"] = "@block.outer",
				["im"] = "@function.inner",
				["am"] = "@function.outer",
				["ic"] = "@class.inner",
				["ac"] = "@class.outer",
				["as"] = "@statement.outer",
				["is"] = "@statement.inner",
				["ap"] = "@parameter.outer",
				["ip"] = "@parameter.inner",
				["aa"] = "@assignment.outer",
				["ia"] = "@assignment.rhs",
				["iA"] = "@assignment.lhs",
				["al"] = "@loop.outer",
				["il"] = "@loop.inner",
				["ad"] = "@comment.outer",
				["id"] = "@comment.inner",
			}
			for key, query in pairs(select_keymaps) do
				vim.keymap.set({ "x", "o" }, key, function()
					select.select_textobject(query, "textobjects")
				end, { desc = "Select " .. query })
			end

			-- Textobject move keymaps
			local move = require("nvim-treesitter-textobjects.move")
			local goto_next_start = {
				["<leader>nm"] = "@function.outer",
				["<leader>nc"] = "@class.outer",
				["<leader>ns"] = "@statement.outer",
				["<leader>np"] = "@parameter.outer",
				["<leader>na"] = "@assignment.outer",
				["<leader>nl"] = "@loop.outer",
				["<leader>nd"] = "@comment.outer",
			}
			local goto_next_end = {
				["<leader>nM"] = "@function.outer",
				["<leader>nC"] = "@class.outer",
				["<leader>nS"] = "@statement.outer",
				["<leader>nP"] = "@parameter.outer",
				["<leader>nA"] = "@assignment.outer",
				["<leader>nL"] = "@loop.outer",
				["<leader>nD"] = "@comment.outer",
			}
			local goto_previous_start = {
				["<leader>pm"] = "@function.outer",
				["<leader>pc"] = "@class.outer",
				["<leader>ps"] = "@statement.outer",
				["<leader>pp"] = "@parameter.outer",
				["<leader>pa"] = "@assignment.outer",
				["<leader>pl"] = "@loop.outer",
				["<leader>pd"] = "@comment.outer",
			}
			local goto_previous_end = {
				["<leader>pM"] = "@function.outer",
				["<leader>pC"] = "@class.outer",
				["<leader>pS"] = "@statement.outer",
				["<leader>pP"] = "@parameter.outer",
				["<leader>pA"] = "@assignment.outer",
				["<leader>pL"] = "@loop.outer",
				["<leader>pD"] = "@comment.outer",
			}

			for key, query in pairs(goto_next_start) do
				vim.keymap.set({ "n", "x", "o" }, key, function()
					move.goto_next_start(query, "textobjects")
				end, { desc = "Next " .. query .. " start" })
			end
			for key, query in pairs(goto_next_end) do
				vim.keymap.set({ "n", "x", "o" }, key, function()
					move.goto_next_end(query, "textobjects")
				end, { desc = "Next " .. query .. " end" })
			end
			for key, query in pairs(goto_previous_start) do
				vim.keymap.set({ "n", "x", "o" }, key, function()
					move.goto_previous_start(query, "textobjects")
				end, { desc = "Previous " .. query .. " start" })
			end
			for key, query in pairs(goto_previous_end) do
				vim.keymap.set({ "n", "x", "o" }, key, function()
					move.goto_previous_end(query, "textobjects")
				end, { desc = "Previous " .. query .. " end" })
			end

			-- Repeatable movement with ; and ,
			local ts_repeat_move = require("nvim-treesitter-textobjects.repeatable_move")
			vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
			vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)

			-- Make builtin f, F, t, T also repeatable with ; and ,
			vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
			vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
			vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
			vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		opts = {
			enable = true,
		},
	},
}
