-- Treesitter configuration
require("nvim-treesitter.configs").setup({
  highlight = { enable = true },
  ensure_installed = {},
  auto_install = true
})

-- LuaSnip configuration
require("luasnip.loaders.from_lua").load({paths = vim.fn.stdpath("config") .. "/lua/snippets/"})
