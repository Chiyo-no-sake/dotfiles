-- Agentic.nvim — an ACP (Agent Client Protocol) chat client.
-- Configured for OpenAI Codex via the `codex-acp` bridge, using the ChatGPT
-- *subscription* login — NOT an API key, so there are no per-token API costs.
--
-- One-time setup (also documented in README.md):
--   npm i -g @openai/codex            # the Codex CLI
--   npm i -g @zed-industries/codex-acp # the ACP bridge agentic talks to
--   codex login                       # choose "Sign in with ChatGPT", NOT API key
--
-- ┌─ CONSTRAINT GUARDRAIL ────────────────────────────────────────────────┐
-- │ Do NOT add OPENAI_API_KEY (or any key) to the codex-acp `env` below.   │
-- │ An empty env makes the bridge read ~/.codex/auth.json from `codex      │
-- │ login`, keeping usage on your ChatGPT plan quota. Injecting a key      │
-- │ silently switches Codex to pay-per-token API billing.                  │
-- └───────────────────────────────────────────────────────────────────────┘
return {
	"carlos-algms/agentic.nvim",
	--- @type agentic.PartialUserConfig
	opts = {
		-- Use the built-in Codex provider.
		provider = "codex-acp",

		-- codex-acp is built in; its defaults are already `command = "codex-acp"`
		-- with an empty env. We re-state it here purely as documentation of intent
		-- and to keep the no-API-key guarantee visible at the call site.
		acp_providers = {
			["codex-acp"] = {
				command = "codex-acp",
				args = {},
				env = {}, -- intentionally empty: subscription login via ~/.codex/auth.json
			},
		},

		windows = {
			position = "right",
			width = "30%",
		},

		diff_preview = {
			enabled = true,
			layout = "split",
		},
	},
	dependencies = {
		-- Optional: paste/drag images into the chat. Needs wl-clipboard (Wayland)
		-- or xclip (X11) on the system. Drop this entry if you don't paste images.
		{ "HakonHarnes/img-clip.nvim", opts = {} },
	},
	-- Lazy-load on first keypress (no `event`, so startup stays fast).
	keys = {
		{
			"<C-\\>",
			function()
				require("agentic").toggle()
			end,
			mode = { "n", "v", "i" },
			desc = "Toggle Agentic chat",
		},
		{
			"<C-'>",
			function()
				require("agentic").add_selection_or_file_to_context()
			end,
			mode = { "n", "v" },
			desc = "Agentic: add file/selection to context",
		},
		{
			"<C-,>",
			function()
				require("agentic").new_session()
			end,
			mode = { "n", "v", "i" },
			desc = "Agentic: new session",
		},
	},
}
