return {
    "nvimtools/none-ls.nvim",
    dependencies = {
        "nvimtools/none-ls-extras.nvim",
    },
    config = function()
        local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
        local null_ls = require("null-ls")
        null_ls.setup({
            sources = {
                -- lua
                null_ls.builtins.formatting.stylua,

                -- js
                -- require("none-ls.diagnostics.eslint_d"),
                null_ls.builtins.formatting.prettier.with({
                    filetypes = {
                        "javascript",
                        "typescript",
                        "css",
                        "scss",
                        "html",
                        "json",
                        "yaml",
                        "markdown",
                        "graphql",
                        "md",
                        "txt",
                    },
                    extra_filetypes = { "solidity" },
                    only_local = "node_modules/.bin",
                }),

                -- python
                null_ls.builtins.formatting.isort,
                null_ls.builtins.formatting.black,
            },
            on_attach = function(client, bufnr)
                if client.supports_method("textDocument/formatting") then
                    vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
                    vim.api.nvim_create_autocmd("BufWritePre", {
                        group = augroup,
                        buffer = bufnr,
                        callback = function()
                            vim.lsp.buf.format({
                                bufnr = bufnr,
                                filter = function(c)
                                    return c.name == "null-ls"
                                end,
                            })
                        end,
                    })
                end
            end,
        })

        -- vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})
    end,
}
