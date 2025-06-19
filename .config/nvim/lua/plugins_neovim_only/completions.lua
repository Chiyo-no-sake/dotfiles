return {
	{
		"hrsh7th/cmp-nvim-lsp",
	},
	{
		"L3MON4D3/LuaSnip",
		dependencies = {
			"saadparwaiz1/cmp_luasnip",
			"rafamadriz/friendly-snippets",
			"onsails/lspkind.nvim",
		},
	},
	{
		"hrsh7th/nvim-cmp",
		config = function()
			local cmp = require("cmp")
			local lspkind = require("lspkind")
			require("luasnip.loaders.from_vscode").lazy_load()

			cmp.setup({
				formatting = {
					format = lspkind.cmp_format({
						mode = "symbol",
						maxwidth = 50,
						ellipsis_char = "…",
						show_labelDetails = true,
					}),
				},
				snippet = {
					expand = function(args)
						require("luasnip").lsp_expand(args.body)
					end,
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				mapping = cmp.mapping.preset.insert({
					--                ["K"] = cmp.mapping(
					--                    function(fallback)
					--                        if cmp.visible_docs() then
					--                            cmp.close_docs()
					--                        else
					--                            cmp.open_docs()
					--                        end
					--                    end
					--                ),
					["<C-n>"] = cmp.mapping.scroll_docs(-4),
					["<C-m>"] = cmp.mapping.scroll_docs(4),
					["<C-j>"] = cmp.mapping.select_next_item(),
					["<C-k>"] = cmp.mapping.select_prev_item(),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = false, behavior = cmp.ConfirmBehavior.Replace }),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
				}, {
					{ name = "buffer" },
				}),
			})
		end,
	},
	-- 	{
	-- 		"github/copilot.vim",
	-- 		config = function()
	-- 			local g = vim.g
	--
	-- 			g.copilot_no_tab_map = true
	-- 			vim.keymap.set({ "i" }, "<C-CR>", 'copilot#Accept("\\<CR>")', {
	-- 				expr = true,
	-- 				replace_keycodes = false,
	-- 			})
	-- 		end,
	-- 	},
}
