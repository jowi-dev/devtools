
-- Elixir LSP configuration using elixir-ls
vim.lsp.config('elixirls', {
  cmd = { '/Users/jowi/.local/share/mise/installs/elixir-ls/0.29.3/language_server.sh' },
  root_markers = { 'mix.exs', '.git' },
  filetypes = { 'elixir', 'eelixir', 'heex' },
})

vim.lsp.enable 'elixirls'
