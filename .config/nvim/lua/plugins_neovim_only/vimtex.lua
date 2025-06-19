return {
	"lervag/vimtex",
	lazy = false, -- we don't want to lazy load VimTeX
	-- tag = "v2.15", -- uncomment to pin to a specific release
	init = function()
		-- VimTeX configuration goes here, e.g.
		vim.g.vimtex_view_enabled = 1
		vim.g.vimtex_view_method = "skim"
		vim.g.vimtex_quickfix_open_on_warning = 0
		vim.g.vimtex_view_skim_sync = 1 --# Value 1 allows forward search after every successful compilation
		vim.g.vimtex_view_skim_activate = 1 --# Value 1 allows change focus to skim after command `:VimtexView` is given

		-- vim.g.vimtex_view_general_viewer = "zathura"
		-- vim.g.vimtex_view_general_options = "--unique file:@pdf\#src:@line@tex"
		-- vim.g.
	end,
}
