return {
	"frankroeder/parrot.nvim",
	dependencies = { "ibhagwan/fzf-lua", "nvim-lua/plenary.nvim" },
	opts = {},
	config = function()
		require("parrot").setup({
			-- Providers must be explicitly set up to make them available.
			providers = {
				openrouter = {
					name = "openrouter",
					api_key = os.getenv("OPENROUTER_API_KEY"),
					endpoint = "https://operouter.ai/api/v1",
					params = {
						chat = { temperature = 1.1, top_p = 1 },
						command = { temperature = 1.1, top_p = 1 },
					},
					topic = {
						model = "google/gemini-2.5-flash",
						params = { max_completion_tokens = 64 },
					},
					models = {
						"moonshotai/kimi-linear-48b-a3b-instruct",
						"x-ai/grok-code-fast-1",
						"anthropic/claude-sonnet-4.5",
						"google/gemini-2.5-flash",
					},
				},
			},
		})
	end,
}
