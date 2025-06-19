return {
    "kkoomen/vim-doge",
    config = function()
        local g = vim.g;

        g.doge_enable_mappings = 0;
        vim.keymap.set('n', '<leader>ggd', ':DogeGenerate<CR>)');
    end,
}
