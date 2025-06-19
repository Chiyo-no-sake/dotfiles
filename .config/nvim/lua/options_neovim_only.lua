if vim.g.vscode then
	local vscode = require("vscode")

	-- <leader>zz to save and quit
	vim.keymap.set("n", "<leader>zz", ":wa<CR>:qa<CR>", { noremap = true })

	-- vscode keymaps
	vim.keymap.set("n", "<leader>ca", function()
		vscode.action("editor.action.codeAction")
	end)

	vim.keymap.set("n", "<leader>db", function()
		vscode.action("editor.debug.action.toggleBreakpoint")
	end)

	vim.keymap.set("n", "<leader>dbi", function()
		vscode.action("editor.debug.action.toggleInlineBreakpoint")
	end)

	vim.keymap.set("n", "<leader>dc", function()
		vscode.action("workbench.action.debug.continue")
	end)

	vim.keymap.set("n", "<leader>ds", function()
		vscode.action("workbench.action.debug.start")
	end)

	vim.keymap.set("n", "<leader>do", function()
		vscode.action("workbench.action.debug.stepOver")
	end)

	vim.keymap.set("n", "<leader>di", function()
		vscode.action("workbench.action.debug.stepInto")
	end)

	vim.keymap.set("n", "<leader>dq", function()
		vscode.action("workbench.action.debug.stop")
	end)
end
