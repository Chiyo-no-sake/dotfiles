return {
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		version = false, -- Never use "*", always use latest
		build = "make",
		opts = {
			provider = "openrouter",
			providers = {
				openrouter = {
					__inherited_from = "openai",
					endpoint = "https://openrouter.ai/api/v1",
					api_key_name = "OPENROUTER_API_KEY",
					model = "google/gemini-2.5-flash",
					extra_request_body = {
						temperature = 0,
						max_tokens = 4096,
					},
					extra_headers = {
						["HTTP-Referer"] = "https://github.com/yetone/avante.nvim",
						["X-Title"] = "Avante.nvim",
					},
				},
			},
			behaviour = {
				auto_suggestions = false, -- Disabled by default (expensive)
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
			"hrsh7th/nvim-cmp", -- For autocompletion in avante commands
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
