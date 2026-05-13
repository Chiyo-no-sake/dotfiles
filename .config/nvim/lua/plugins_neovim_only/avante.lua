return {
	{
		"yetone/avante.nvim",
		enabled = false,
		event = "VeryLazy",
		version = false, -- Never use "*", always use latest
		build = "make",
		opts = {
			provider = "gemini",
			providers = {
				gemini = {
					model = "gemini-2.5-flash-lite",
					api_key_name = "AVANTE_GEMINI_API_KEY",
					timeout = 30000,
					temperature = 0,
					max_tokens = 8192,
				},
				claude = {},
			},
			acp_providers = {
				["claude-code"] = {
					command = "npx",
					args = { "@zed-industries/claude-code-acp" },
					env = {
						NODE_NO_WARNINGS = "1",
						ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY"),
					},
				},
			},
			behaviour = {
				auto_suggestions = true, -- Disabled by default (expensive)
				auto_set_keymaps = true,
				auto_set_highlight_group = true,
				auto_apply_diff_after_generation = false,
				support_paste_from_clipboard = false,
			},
			hints = { enabled = true },
			windows = {
				position = "right",
				width = 30, -- percentage
				sidebar_header = {
					align = "center",
					rounded = true,
				},
			},
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
			--- Optional dependencies
			"saghen/blink.cmp", -- For autocompletion in avante commands
			"nvim-telescope/telescope.nvim", -- For file selector
			{
				-- Image pasting support
				"HakonHarnes/img-clip.nvim",
				event = "VeryLazy",
				opts = {
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = {
							insert_mode = true,
						},
					},
				},
			},
			{
				-- Render markdown in avante output
				"MeanderingProgrammer/render-markdown.nvim",
				opts = {
					file_types = { "markdown", "Avante" },
				},
				ft = { "markdown", "Avante" },
			},
		},
	},
}
