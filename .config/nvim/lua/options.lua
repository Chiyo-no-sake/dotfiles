vim.cmd("set number")
vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set autoindent")
vim.cmd("set nospell")

-- required settings for vimwiki
vim.cmd("set nocompatible")
vim.cmd("filetype plugin on")
vim.cmd("syntax on")

vim.g.mapleader = " "
vim.g.have_nerd_font = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.showmode = true
vim.opt.cc = "80"
vim.opt.breakindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.gdefault = true
vim.o.exrc = true
vim.opt.splitright = true

vim.cmd("set nosmd")
vim.cmd("set noru")

-- exit from insert mode with jj
vim.keymap.set("i", "jj", "<Esc>", { noremap = true })

-- <leader>ss to save everything
vim.keymap.set("n", "<leader>ss", ":wa<CR>", { noremap = true })

-- Set the sessionoptions
-- required for debugging with DAP
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

if vim.g.vscode then
	require("options_vscode_only")
else
	require("options_neovim_only")
end
