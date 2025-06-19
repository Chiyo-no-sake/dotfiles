return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
    dependencies = {
        "nvim-treesitter/nvim-treesitter"
    },
    config = function()
        local ibl = require('ibl')
        ibl.setup({})
    end
}
