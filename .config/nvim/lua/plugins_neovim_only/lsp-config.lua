return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	-- {
	-- 	"ray-x/lsp_signature.nvim",
	-- 	config = function()
	-- 		require("lsp_signature").setup({
	-- 			bind = true,
	-- 			handler_opts = {
	-- 				border = "single",
	-- 			},
	-- 		})
	-- 	end,
	-- },
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
			"williamboman/mason.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
		},
		config = function()
			local lspconfig = require("lspconfig")
			local telescope_builtins = require("telescope.builtin")

			-- LSP servers and clients are able to communicate to each other what features they hrt.
			--  By default, Neovim doesn't support everything that is in the LSP specification.
			--  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
			--  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())

			local function organize_imports()
				-- use pyright for python files, tsserver for everything else
				if vim.bo.filetype == "python" then
					vim.lsp.buf.execute_command({
						command = "pyright.organizeimports",
						arguments = { vim.uri_from_bufnr(0) },
					})
				else
					vim.lsp.buf.execute_command({
						command = "_typescript.organizeImports",
						arguments = { vim.api.nvim_buf_get_name(0) },
					})
				end
			end

			local function add_all_imports()
				vim.lsp.buf.code_action({
					apply = true,
					context = {
						only = { "source.addMissingImports.ts" },
					},
				})
			end

			-- Customize LSP default settings
			-- theses will be installed by default
			local servers = {
				lua_ls = {
					capabilities = capabilities,
					settings = {
						Lua = {
							completion = {
								callSnippet = "Replace",
							},
						},
					},
				},
				solidity = {
					capabilities = capabilities,
					cmd = { "nomicfoundation-solidity-language-server", "--stdio" },
					filetypes = { "solidity" },
					single_file_support = true,
				},
				ts_ls = {
					capabilities = capabilities,
					init_options = {
						plugins = {
							{
								name = "@vue/typescript-plugin",
								location = "/home/luca/.nvm/versions/node/v18.17.1/lib/node_modules/@vue/typescript-plugin",
								languages = {
									"javascript",
									"typescript",
									"vue",
								},
							},
						},
					},
					filetypes = {
						"javascript",
						"typescript",
						"typescriptreact",
						"javascriptreact",
						"javascript.jsx",
						"typescript.tsx",
						"vue",
					},
					settings = {
						typescript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = true,
								includeInlayVariableTypeHints = true,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHintsWhenTypeMatchesName = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
						},
						javascript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = true,
								includeInlayVariableTypeHints = true,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHintsWhenTypeMatchesName = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
						},
					},
				},
				pyright = {
					settings = {
						python = {
							analysis = {
								diagnosticSeverityOverrides = {
									reportOptionalMemberAccess = "none",
								},
							},
						},
					},
				},
				jsonls = {},
				helm_ls = {},
				yamlls = {
					capabilities = capabilities,
					settings = {
						yaml = {
							format = {
								enable = true,
							},
							schemas = {
								["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "**/*compose*.{yml,yaml}",
								["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json"] = "**/.gitlab-ci.{yml,yaml}",
								["https://json.schemastore.org/package.json"] = { "**/package.json" },
								["https://json.schemastore.org/eslintrc.json"] = { "**/*eslintrc.{json,yaml,yml}" },
								["https://json.schemastore.org/tsconfig.json"] = { "**/tsconfig.{json,jsonc}" },
								["https://json.schemastore.org/prettierrc.json"] = {
									"**/.prettierrc.{json,yaml,yml,js}",
								},
							},
						},
					},
				},
			}

			local ensure_installed = vim.tbl_keys(servers or {})
			vim.list_extend(ensure_installed, {
				"stylua",
				"prettierd",
				"isort",
				"black",
				"pylint",
				"codespell",
				"eslint",
				"jsonlint",
				"jq",
				"jsonls",
				"hadolint",
				"markdownlint",
				"xmlformatter",
				"yamlls",
				"typescript-language-server",
				"js-debug-adapter",
				"chrome-debug-adapter",
			})

			require("mason-tool-installer").setup({
				ensure_installed = ensure_installed,
			})

			require("mason-lspconfig").setup({
				handlers = {
					function(server_name)
						if server_name == "vuels" then
							return
						end

						local server = servers[server_name] or {}
						-- Applies custom settings and capabilities defined above
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						lspconfig[server_name].setup(server)
					end,
				},
			})

			---- LSP keybindings ----
			-- vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Show hover doc" })
			vim.keymap.set("n", "gr", telescope_builtins.lsp_references, { desc = "Go to references" })
			vim.keymap.set("n", "gi", telescope_builtins.lsp_implementations, { desc = "Go to implementation" })
			vim.keymap.set("n", "gd", telescope_builtins.lsp_definitions, { desc = "Go to definition" })

			vim.keymap.set("n", "<leader>oi", organize_imports, { desc = "Organize imports" })

			vim.keymap.set("n", "<leader>ai", add_all_imports, { desc = "Add all imports" })
			vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, { desc = "Format file" })
			vim.keymap.set(
				"n",
				"<leader>fS",
				telescope_builtins.lsp_workspace_symbols,
				{ desc = "Find workspace symbols" }
			)
			vim.keymap.set(
				"n",
				"<leader>fs",
				telescope_builtins.lsp_document_symbols,
				{ desc = "Find document symbols" }
			)

			-- <leader>ca to show code actions
			vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {})

			-- <leader>e to show under-cursor diagnostic in a floating window
			vim.api.nvim_set_keymap(
				"n",
				"<leader>e",
				':lua vim.diagnostic.open_float(nil, {focus=false, scope="cursor"})<CR>',
				{}
			)

			-- <leader>ne to jump to next diagnostic
			vim.keymap.set("n", "<leader>ne", vim.diagnostic.goto_next, {})

			-- <leader>pe to jump to previous diagnostic
			vim.keymap.set("n", "<leader>pe", vim.diagnostic.goto_prev, {})

			-- <leader>rn to rename
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, {})
		end,
	},
}
