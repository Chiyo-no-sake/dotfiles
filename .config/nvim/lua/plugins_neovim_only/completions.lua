return {
	{
		"L3MON4D3/LuaSnip",
		dependencies = {
			"rafamadriz/friendly-snippets",
		},
		config = function()
			require("luasnip.loaders.from_vscode").lazy_load()
		end,
	},
	{
		"saghen/blink.cmp",
		version = "1.*",
		dependencies = {
			"saghen/blink.lib",
			"L3MON4D3/LuaSnip",
			"rafamadriz/friendly-snippets",
			"frankroeder/parrot.nvim",
		},
		---@module 'blink.cmp'
		---@type blink.cmp.Config
		opts = {
			keymap = {
				preset = "none",
				["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
				["<C-e>"] = { "hide", "fallback" },
				["<CR>"] = { "accept", "fallback" },
				["<C-j>"] = { "select_next", "fallback" },
				["<C-k>"] = { "select_prev", "fallback" },
				["<C-n>"] = { "scroll_documentation_up", "fallback" },
				["<C-m>"] = { "scroll_documentation_down", "fallback" },
			},
			snippets = { preset = "luasnip" },
			completion = {
				accept = { auto_brackets = { enabled = true } },
				documentation = { auto_show = true, auto_show_delay_ms = 200 },
				menu = {
					border = "rounded",
					draw = {
						treesitter = { "lsp" },
					},
				},
			},
			signature = { enabled = true, window = { border = "rounded" } },
			sources = {
				default = { "lsp", "path", "snippets", "buffer", "parrot" },
				providers = {
					parrot = {
						name = "parrot",
						module = "parrot.completion.blink",
					},
				},
			},
			fuzzy = { implementation = "rust" },
		},
		opts_extend = { "sources.default" },
	},
}
