local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- require the global options
require("options")

-- check if custom.lua exists, if it does, load it
require("utils")
if file_exists("$HOME/.config/nvim/lua/custom.lua") then
	require("custom")
end

-- require the plugins setup
require("lazy").setup({
	{ import = "plugins", cond = "true" },
	{
		import = "plugins_vscode_only",
		cond = function()
			return vim.g.vscode
		end,
	},
	{
		import = "plugins_neovim_only",
		cond = function()
			return not vim.g.vscode
		end,
	},
})

vim.cmd("set termguicolors")
