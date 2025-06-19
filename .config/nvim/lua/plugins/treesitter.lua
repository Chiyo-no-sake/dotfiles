return {
	{
		"nvim-treesitter/nvim-treesitter",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-refactor",
			"nvim-treesitter/nvim-treesitter-textobjects",
		},
		build = ":TSUpdate",
		config = function(_, opts)
			require("nvim-treesitter.configs").setup(opts)

			local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")

			-- Repeat movement with ; and ,
			-- ensure ; goes forward and , goes backward regardless of the last direction
			vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
			vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)

			-- vim way: ; goes to the direction you were moving.
			-- vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move)
			-- vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_opposite)

			-- Optionally, make builtin f, F, t, T also repeatable with ; and ,
			vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
			vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
			vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
			vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })

			-- create fold with treesitter if there is a parser for file type
			vim.cmd("set nofoldenable")
			vim.api.nvim_create_autocmd({ "FileType" }, {
				callback = function()
					if require("nvim-treesitter.parsers").has_parser() then
						vim.opt.foldmethod = "expr"
						vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
					else
						vim.opt.foldmethod = "syntax"
					end
				end,
			})
		end,
		opts = {
			auto_install = true,
			ensure_installed = {
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
			},
			highlight = { enable = true },
			indent = { enable = true },
			lsp_interop = { enable = true },
			refactor = {
				highlight_definitions = { enable = true, clear_on_cursor_move = true },
				--				smart_rename = {
				--					enable = true,
				--					keymaps = {
				--						smart_rename = "<leader>rn",
				--					},
				--				},
				--				navigation = {
				--					enable = true,
				--					keymaps = {
				--						goto_definition_lsp_fallback = "gd",
				--					},
				--				},
			},
			textobjects = {
				select = {
					enable = true,
					lookahead = true,
					keymaps = {
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
					},
				},
				move = {
					enable = true,
					set_jumps = true,
					goto_next_start = {
						["<leader>nm"] = "@function.outer",
						["<leader>nc"] = "@class.outer",
						["<leader>ns"] = "@statement.outer",
						["<leader>np"] = "@parameter.outer",
						["<leader>na"] = "@assignment.outer",
						["<leader>nl"] = "@loop.outer",
						["<leader>nd"] = "@comment.outer",
					},
					goto_next_end = {
						["<leader>nM"] = "@function.outer",
						["<leader>nC"] = "@class.outer",
						["<leader>nS"] = "@statement.outer",
						["<leader>nP"] = "@parameter.outer",
						["<leader>nA"] = "@assignment.outer",
						["<leader>nL"] = "@loop.outer",
						["<leader>nD"] = "@comment.outer",
					},
					goto_previous_start = {
						["<leader>pm"] = "@function.outer",
						["<leader>pc"] = "@class.outer",
						["<leader>ps"] = "@statement.outer",
						["<leader>pp"] = "@parameter.outer",
						["<leader>pa"] = "@assignment.outer",
						["<leader>pl"] = "@loop.outer",
						["<leader>pd"] = "@comment.outer",
					},
					goto_previous_end = {
						["<leader>pM"] = "@function.outer",
						["<leader>pC"] = "@class.outer",
						["<leader>pS"] = "@statement.outer",
						["<leader>pP"] = "@parameter.outer",
						["<leader>pA"] = "@assignment.outer",
						["<leader>pL"] = "@loop.outer",
						["<leader>pD"] = "@comment.outer",
					},
				},
			},
		},
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		opts = {
			enable = true,
		},
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
	},
}
