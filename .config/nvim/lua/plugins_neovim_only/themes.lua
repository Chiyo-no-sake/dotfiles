return {
	{
		-- Matugen dynamic colorscheme (loaded from colors/matugen.lua)
		-- Falls back to catppuccin if matugen colors are not yet generated
		dir = vim.fn.stdpath("config"),
		name = "matugen-theme",
		priority = 1000,
		config = function()
			local ok = pcall(require, "matugen_colors")
			if ok then
				vim.cmd("colorscheme matugen")
			else
				vim.notify("matugen colors not found, run matugen to generate", vim.log.levels.WARN)
			end
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
