--- Ctrl+/: Toggle terminal
return {
	"akinsho/toggleterm.nvim",
	version = "*",
	config = function()
		require("toggleterm").setup({
			open_mapping = [[<C-`>]],
			on_open = function()
				vim.cmd("setlocal nospell")
			end,
		})

		-- keymaps for lazygit
		local Terminal = require("toggleterm.terminal").Terminal

		-- keymaps for lazydocker
		local lazydocker = Terminal:new({
			cmd = "lazydocker",
			direction = "float",
			hidden = true,
		})

		function _Lazydocker_toggle()
			lazydocker:toggle()
		end

		vim.api.nvim_set_keymap("n", "<leader>sd", "<cmd>lua _Lazydocker_toggle()<CR>", {
			noremap = true,
			silent = true,
		})

		vim.api.nvim_create_autocmd({ "TermEnter" }, {
			callback = function()
				for _, buffers in ipairs(vim.fn.getbufinfo()) do
					local filetype = vim.api.nvim_buf_get_option(buffers.bufnr, "filetype")
					if filetype == "toggleterm" then
						vim.api.nvim_create_autocmd({ "BufWriteCmd", "FileWriteCmd", "FileAppendCmd" }, {
							buffer = buffers.bufnr,
							command = "q!",
						})
					end
				end
			end,
		})
		-- keymaps to switch between windows
		-- vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
		vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
		vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
		vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
		vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
		vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
	end,
}
