# ty Migration Plan

## Environment
- Neovim 0.11.2
- Fedora Linux
- asdf for Python (3.11.13)
- No uv installed (yet)

---

## Step 1: Install ty

ty is NOT in Mason registry. Install manually:

```bash
# Install uv via Fedora package manager
sudo dnf install uv

# Install ty as a uv tool
uv tool install ty@latest
```

---

## Step 2: Update lsp-config.lua

### 2a. Remove pyright from servers table (line 131-141)

Delete:
```lua
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
```

### 2b. Update organize_imports function (line 37-49)

The current function uses `pyright.organizeimports`. Options:
- Comment out the Python branch until ty supports organize imports
- Or remove the function entirely if not needed

Change from:
```lua
local function organize_imports()
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
```

To:
```lua
local function organize_imports()
    -- ty doesn't support organize imports yet, only for TypeScript
    if vim.bo.filetype ~= "python" then
        vim.lsp.buf.execute_command({
            command = "_typescript.organizeImports",
            arguments = { vim.api.nvim_buf_get_name(0) },
        })
    end
end
```

### 2c. Add ty config after mason-lspconfig.setup (after line 203)

Add:
```lua
-- ty language server (installed via uv, not Mason)
vim.lsp.config('ty', {
    settings = {
        ty = {
            rules = {
                -- Equivalent to pyright's reportOptionalMemberAccess = "none"
                ["possibly-missing-attribute"] = "ignore",
            }
        }
    }
})
vim.lsp.enable('ty')
```

---

## Step 3: Verify

1. Restart Neovim
2. Open a Python file
3. Run `:LspInfo` to confirm ty is attached
4. Test diagnostics, go-to-definition, hover, etc.

---

## Rollback

If issues occur, revert changes and reinstall pyright:
- Re-add pyright to servers table
- Remove vim.lsp.config/enable for ty
- Restore original organize_imports function

---

## Sources
- https://docs.astral.sh/ty/installation/
- https://docs.astral.sh/ty/editors/
- https://docs.astral.sh/ty/reference/rules/
- https://github.com/neovim/nvim-lspconfig/issues/3871
