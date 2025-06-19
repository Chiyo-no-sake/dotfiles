return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			require("catppuccin").setup({
				default_integration = true,
				flavor = "macchiato",
			})

			vim.cmd("colorscheme catppuccin")
		end,
	},
	-- {
	--     "navarasu/onedark.nvim",
	--     priority = 10000,
	--     config = function()
	--         local onedark = require("onedark")
	--         onedark.setup({
	--             style = "warmer",
	--             transparent = true,
	--         })
	--
	--         onedark.load()
	--         vim.cmd("colorscheme onedark")
	--     end,
	-- },
	-- {
	--     "oncomouse/lushwal.nvim",
	--     cmd = { "LushwalCompile" },
	--     dependencies = {
	--         { "rktjmp/lush.nvim" },
	--         { "rktjmp/shipwright.nvim" },
	--     },
	-- },
	-- {
	--     "ellisonleao/gruvbox.nvim",
	--     priority = 10000,
	--     config = function(opts)
	--         require("gruvbox").setup(opts)
	--         vim.cmd("colorscheme gruvbox")
	--     end,
	--     opts = {},
	-- },
}
