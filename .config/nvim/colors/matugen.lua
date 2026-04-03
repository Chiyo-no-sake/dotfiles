-- Matugen Material You colorscheme for Neovim

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end
vim.g.colors_name = "matugen"

local ok, c = pcall(require, "matugen_colors")
if not ok then
  vim.notify("matugen_colors not found - run matugen to generate colors", vim.log.levels.WARN)
  return
end

local hi = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Kitty opacity: fully opaque while nvim is open, restore on exit
local kitty_opacity_group = vim.api.nvim_create_augroup("KittyOpacity", { clear = true })
vim.api.nvim_create_autocmd("VimEnter", {
  group = kitty_opacity_group,
  callback = function()
    vim.fn.system("kitty @ set-background-opacity 1.0")
  end,
})
vim.api.nvim_create_autocmd("VimLeave", {
  group = kitty_opacity_group,
  callback = function()
    vim.fn.system("kitty @ set-background-opacity 0.85")
  end,
})
-- Set it immediately too (colorscheme loads after VimEnter on first run)
vim.fn.system("kitty @ set-background-opacity 1.0")

-- Editor UI — solid bg so nvim is fully opaque
hi("Normal", { fg = c.on_surface, bg = c.surface })
hi("NormalFloat", { fg = c.on_surface, bg = c.surface_container })
hi("FloatBorder", { fg = c.outline, bg = c.surface_container })
hi("Cursor", { fg = c.surface, bg = c.on_surface })
hi("CursorLine", { bg = c.surface_container })
hi("CursorColumn", { bg = c.surface_container })
hi("ColorColumn", { bg = c.surface_container })
hi("LineNr", { fg = c.outline })
hi("CursorLineNr", { fg = c.primary, bold = true })
hi("SignColumn", { bg = c.surface })
hi("VertSplit", { fg = c.outline_variant })
hi("WinSeparator", { fg = c.outline_variant })
hi("StatusLine", { fg = c.on_surface, bg = c.surface_container })
hi("StatusLineNC", { fg = c.outline, bg = c.surface_container_low })
hi("TabLine", { fg = c.on_surface_variant, bg = c.surface_container })
hi("TabLineSel", { fg = c.on_primary_container, bg = c.primary_container })
hi("TabLineFill", { bg = c.surface_dim })
hi("Folded", { fg = c.on_surface_variant, bg = c.surface_container_low })
hi("FoldColumn", { fg = c.outline, bg = c.surface })
hi("NonText", { fg = c.outline })
hi("SpecialKey", { fg = c.outline })
hi("Whitespace", { fg = c.surface_container_high })
hi("EndOfBuffer", { fg = c.surface })

-- Selection & search
hi("Visual", { bg = c.surface_container_high })
hi("VisualNOS", { bg = c.surface_container_high })
hi("Search", { fg = c.on_primary_container, bg = c.primary_container })
hi("IncSearch", { fg = c.on_primary, bg = c.primary })
hi("CurSearch", { fg = c.on_primary, bg = c.primary })
hi("Substitute", { fg = c.on_tertiary, bg = c.tertiary })

-- Popup menu
hi("Pmenu", { fg = c.on_surface, bg = c.surface_container })
hi("PmenuSel", { fg = c.on_primary_container, bg = c.primary_container })
hi("PmenuSbar", { bg = c.surface_container_high })
hi("PmenuThumb", { bg = c.outline })

-- Messages
hi("ErrorMsg", { fg = c.error, bold = true })
hi("WarningMsg", { fg = c.tertiary, bold = true })
hi("ModeMsg", { fg = c.on_surface, bold = true })
hi("MoreMsg", { fg = c.primary })
hi("Question", { fg = c.primary })
hi("Title", { fg = c.primary, bold = true })
hi("Directory", { fg = c.primary })

-- Diff
hi("DiffAdd", { bg = c.tertiary_container })
hi("DiffChange", { bg = c.secondary_container })
hi("DiffDelete", { bg = c.error_container })
hi("DiffText", { bg = c.primary_container })
hi("Added", { fg = c.tertiary })
hi("Changed", { fg = c.secondary })
hi("Removed", { fg = c.error })

-- Spelling
hi("SpellBad", { undercurl = true, sp = c.error })
hi("SpellCap", { undercurl = true, sp = c.tertiary })
hi("SpellLocal", { undercurl = true, sp = c.secondary })
hi("SpellRare", { undercurl = true, sp = c.primary })

-- Syntax — only bright, high-contrast foreground colors
-- primary (lavender), tertiary (pink), error (salmon),
-- on_tertiary_container (bright pink), on_error_container (bright salmon),
-- on_primary_container (bright lavender), on_surface_variant (light gray)
hi("Comment", { fg = c.outline, italic = true })
hi("Constant", { fg = c.on_error_container })
hi("String", { fg = c.tertiary })
hi("Character", { fg = c.tertiary, bold = true })
hi("Number", { fg = c.error })
hi("Boolean", { fg = c.error, italic = true })
hi("Float", { fg = c.error })
hi("Identifier", { fg = c.on_surface })
hi("Function", { fg = c.primary })
hi("Statement", { fg = c.on_primary_container })
hi("Conditional", { fg = c.on_primary_container })
hi("Repeat", { fg = c.on_primary_container })
hi("Label", { fg = c.on_tertiary_container })
hi("Operator", { fg = c.on_surface_variant })
hi("Keyword", { fg = c.on_primary_container, italic = true })
hi("Exception", { fg = c.error, bold = true })
hi("PreProc", { fg = c.on_error_container })
hi("Include", { fg = c.on_primary_container })
hi("Define", { fg = c.on_error_container })
hi("Macro", { fg = c.on_error_container, bold = true })
hi("PreCondit", { fg = c.on_tertiary_container })
hi("Type", { fg = c.tertiary })
hi("StorageClass", { fg = c.on_primary_container })
hi("Structure", { fg = c.on_tertiary_container })
hi("Typedef", { fg = c.tertiary, italic = true })
hi("Special", { fg = c.on_tertiary_container })
hi("SpecialChar", { fg = c.error })
hi("Tag", { fg = c.primary })
hi("Delimiter", { fg = c.on_surface_variant })
hi("SpecialComment", { fg = c.tertiary, italic = true })
hi("Debug", { fg = c.error })
hi("Underlined", { fg = c.primary, underline = true })
hi("Error", { fg = c.on_error, bg = c.error })
hi("Todo", { fg = c.on_tertiary_container, bg = c.tertiary_container, bold = true })
hi("MatchParen", { fg = c.on_primary, bg = c.primary, bold = true })

-- Diagnostics
hi("DiagnosticError", { fg = c.error })
hi("DiagnosticWarn", { fg = c.tertiary })
hi("DiagnosticInfo", { fg = c.primary })
hi("DiagnosticHint", { fg = c.secondary })
hi("DiagnosticOk", { fg = c.tertiary })
hi("DiagnosticUnderlineError", { undercurl = true, sp = c.error })
hi("DiagnosticUnderlineWarn", { undercurl = true, sp = c.tertiary })
hi("DiagnosticUnderlineInfo", { undercurl = true, sp = c.primary })
hi("DiagnosticUnderlineHint", { undercurl = true, sp = c.secondary })
hi("DiagnosticVirtualTextError", { fg = c.error, bg = c.error_container })
hi("DiagnosticVirtualTextWarn", { fg = c.tertiary, bg = c.tertiary_container })
hi("DiagnosticVirtualTextInfo", { fg = c.primary, bg = c.primary_container })
hi("DiagnosticVirtualTextHint", { fg = c.secondary, bg = c.secondary_container })

-- Git signs
hi("GitSignsAdd", { fg = c.tertiary })
hi("GitSignsChange", { fg = c.secondary })
hi("GitSignsDelete", { fg = c.error })

-- Treesitter — only high-contrast foreground colors
hi("@variable", { fg = c.on_surface })
hi("@variable.builtin", { fg = c.on_error_container, italic = true })
hi("@variable.parameter", { fg = c.on_tertiary_container })
hi("@constant", { fg = c.on_error_container })
hi("@constant.builtin", { fg = c.on_error_container, bold = true })
hi("@module", { fg = c.on_primary_container, italic = true })
hi("@string", { fg = c.tertiary })
hi("@string.escape", { fg = c.error })
hi("@string.regex", { fg = c.error })
hi("@character", { fg = c.tertiary, bold = true })
hi("@number", { fg = c.error })
hi("@boolean", { fg = c.error, italic = true })
hi("@type", { fg = c.tertiary })
hi("@type.builtin", { fg = c.tertiary, italic = true })
hi("@attribute", { fg = c.on_tertiary_container })
hi("@property", { fg = c.on_surface_variant })
hi("@function", { fg = c.primary })
hi("@function.builtin", { fg = c.primary, italic = true })
hi("@function.method", { fg = c.primary })
hi("@constructor", { fg = c.on_primary_container })
hi("@keyword", { fg = c.on_primary_container, italic = true })
hi("@keyword.function", { fg = c.on_primary_container, italic = true })
hi("@keyword.return", { fg = c.error, italic = true })
hi("@keyword.operator", { fg = c.on_surface_variant })
hi("@operator", { fg = c.on_surface_variant })
hi("@punctuation", { fg = c.outline })
hi("@punctuation.bracket", { fg = c.on_surface_variant })
hi("@punctuation.delimiter", { fg = c.outline })
hi("@comment", { fg = c.outline, italic = true })
hi("@tag", { fg = c.error })
hi("@tag.attribute", { fg = c.tertiary })
hi("@tag.delimiter", { fg = c.on_surface_variant })
hi("@markup.heading", { fg = c.primary, bold = true })
hi("@markup.strong", { fg = c.on_error_container, bold = true })
hi("@markup.italic", { fg = c.tertiary, italic = true })
hi("@markup.link", { fg = c.primary, underline = true })
hi("@markup.link.url", { fg = c.tertiary, underline = true })
hi("@markup.raw", { fg = c.on_tertiary_container })
hi("@markup.list", { fg = c.on_surface_variant })

-- LSP semantic tokens
hi("@lsp.type.class", { fg = c.tertiary })
hi("@lsp.type.decorator", { fg = c.on_tertiary_container })
hi("@lsp.type.enum", { fg = c.tertiary })
hi("@lsp.type.enumMember", { fg = c.on_error_container })
hi("@lsp.type.function", { fg = c.primary })
hi("@lsp.type.interface", { fg = c.on_tertiary_container, italic = true })
hi("@lsp.type.macro", { fg = c.on_error_container, bold = true })
hi("@lsp.type.method", { fg = c.primary })
hi("@lsp.type.namespace", { fg = c.on_primary_container, italic = true })
hi("@lsp.type.parameter", { fg = c.on_tertiary_container })
hi("@lsp.type.property", { fg = c.on_surface_variant })
hi("@lsp.type.struct", { fg = c.tertiary })
hi("@lsp.type.type", { fg = c.tertiary })
hi("@lsp.type.variable", { fg = c.on_surface })

-- Telescope
hi("TelescopeNormal", { fg = c.on_surface, bg = c.surface_container })
hi("TelescopeBorder", { fg = c.outline, bg = c.surface_container })
hi("TelescopePromptNormal", { fg = c.on_surface, bg = c.surface_container_high })
hi("TelescopePromptBorder", { fg = c.surface_container_high, bg = c.surface_container_high })
hi("TelescopePromptTitle", { fg = c.on_primary, bg = c.primary })
hi("TelescopePreviewTitle", { fg = c.on_tertiary, bg = c.tertiary })
hi("TelescopeResultsTitle", { fg = c.surface_container, bg = c.surface_container })
hi("TelescopeSelection", { fg = c.on_surface, bg = c.surface_container_high })
hi("TelescopeMatching", { fg = c.tertiary, bold = true })

-- Neo-tree
hi("NeoTreeNormal", { fg = c.on_surface, bg = c.surface_dim })
hi("NeoTreeNormalNC", { fg = c.on_surface, bg = c.surface_dim })
hi("NeoTreeDirectoryName", { fg = c.primary })
hi("NeoTreeDirectoryIcon", { fg = c.primary })
hi("NeoTreeRootName", { fg = c.primary, bold = true })
hi("NeoTreeFileName", { fg = c.on_surface })
hi("NeoTreeGitAdded", { fg = c.tertiary })
hi("NeoTreeGitModified", { fg = c.secondary })
hi("NeoTreeGitDeleted", { fg = c.error })
hi("NeoTreeGitUntracked", { fg = c.outline })
hi("NeoTreeIndentMarker", { fg = c.outline_variant })

-- Indent blankline
hi("IblIndent", { fg = c.surface_container_high })
hi("IblScope", { fg = c.primary })

-- Which-key
hi("WhichKey", { fg = c.primary })
hi("WhichKeyGroup", { fg = c.tertiary })
hi("WhichKeyDesc", { fg = c.on_surface })
hi("WhichKeySeparator", { fg = c.outline })
hi("WhichKeyFloat", { bg = c.surface_container })

-- Alpha (dashboard)
hi("AlphaHeader", { fg = c.primary })
hi("AlphaButtons", { fg = c.on_surface })
hi("AlphaShortcut", { fg = c.tertiary })
hi("AlphaFooter", { fg = c.outline, italic = true })
