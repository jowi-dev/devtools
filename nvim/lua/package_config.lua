-- Treesitter configuration (nvim-treesitter v0.10+ API)
-- highlight/indent/folds are now Neovim-native; setup() only accepts install_dir
require("nvim-treesitter").setup({})

-- Enable treesitter highlighting for all filetypes
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "*" },
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

-- fzf-lua configuration
require("fzf-lua").setup({
  winopts = {
    height = 0.85,
    width = 0.80,
    preview = {
      layout = "flex",
      flip_columns = 120,
    },
  },
  fzf_opts = {
    ["--layout"] = "reverse",
  },
})

-- nvim-tree configuration
require("nvim-tree").setup()

-- LuaSnip configuration
-- Load snippets from devtools repo (requires DEVTOOLS_ROOT env var)
local snippet_path = vim.env.DEVTOOLS_ROOT .. "/snippets/"
require("luasnip.loaders.from_lua").load({paths = snippet_path})
