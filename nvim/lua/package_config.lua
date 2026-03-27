-- Treesitter configuration
require("nvim-treesitter.configs").setup({
  highlight = { enable = true },
  ensure_installed = {},
  auto_install = true
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

-- LuaSnip configuration
-- Load snippets from devtools repo (requires DEVTOOLS_ROOT env var)
local snippet_path = vim.env.DEVTOOLS_ROOT .. "/snippets/"
require("luasnip.loaders.from_lua").load({paths = snippet_path})
