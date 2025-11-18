
-- Elixir LSP configuration using expert (official Elixir LS)
vim.lsp.config('expert', {
  cmd = { '/Users/jowi/.local/share/mise/installs/http-expert/nightly/expert' },
  root_markers = { 'mix.exs', '.git' },
  filetypes = { 'elixir', 'eelixir', 'heex' },
})

vim.lsp.enable 'expert'

-- Previous elixir-ls config (commented out)
-- vim.lsp.config('elixirls', {
--   cmd = { '/Users/jowi/.local/share/mise/installs/elixir-ls/0.29.3/language_server.sh' },
--   root_markers = { 'mix.exs', '.git' },
--   filetypes = { 'elixir', 'eelixir', 'heex' },
-- })
-- vim.lsp.enable 'elixirls'
