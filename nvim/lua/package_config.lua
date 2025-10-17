-- Treesitter configuration
require("nvim-treesitter.configs").setup({
  highlight = { enable = true },
  ensure_installed = {},
  auto_install = true
})

-- LuaSnip configuration
-- Load snippets from devtools repo (requires DEVTOOLS_ROOT env var)
local snippet_path = vim.env.DEVTOOLS_ROOT .. "/snippets/"
require("luasnip.loaders.from_lua").load({paths = snippet_path})
