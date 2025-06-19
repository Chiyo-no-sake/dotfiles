return {
	{
		"tpope/vim-surround",
		dependencies = "tpope/vim-repeat",
		init = function()
			vim.g.surround_no_mappings = 1
		end,
		keys = {
			{ "cs", "<Plug>Csurround", desc = "change surrounding #1 by #2" },
			{ "ds", "<Plug>Dsurround", desc = "delete surrounding #1" },
			{ "cS", "<Plug>CSurround", desc = "change surrounding #1 by #2 + new line" },
			{ "ys", "<Plug>Ysurround", desc = "wraps #1 in #2 (surround)" },
			{ "yS", "<Plug>YSurround", desc = "wraps #1 in #2 (surround) + new line" },
			{ "yss", "<Plug>Yssurround", desc = "wraps line in #1 (surround)" },
			{ "ySs", "<Plug>YSsurround", desc = "wraps line in #1 (surround) + new line" },
			{ "ySS", "<Plug>YSsurround", desc = "wraps line in #1 (surround) + new line" },
			{ "gs", "<Plug>VSurround", desc = "wraps visual selection in #1 (surround)", mode = "x" },
			{ "gS", "<Plug>VgSurround", desc = "wraps visual selection in #1 (surround) + new line", mode = "x" },
		},
	},
}
