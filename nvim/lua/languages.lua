
-- Ensure mise shims are in PATH so LSP servers managed by mise are found
-- regardless of how nvim was launched (GUI, non-interactive shell, etc.)
local mise_shims = vim.env.HOME .. '/.local/share/mise/shims'
if not string.find(vim.env.PATH or '', mise_shims, 1, true) then
  vim.env.PATH = mise_shims .. ':' .. (vim.env.PATH or '')
end

vim.lsp.config('expert', {
  cmd = { 'expert', '--stdio' },
  root_markers = { 'mix.exs', '.git' },
  filetypes = { 'elixir', 'eelixir', 'heex' },
})
vim.lsp.enable 'expert'

vim.lsp.config('lua_ls', {
  cmd = { 'lua-language-server' },
  root_markers = { '.git', '.luarc.json' },
  filetypes = { 'lua' },
})
vim.lsp.enable 'lua_ls'

vim.lsp.config('nixd', {
  cmd = { 'nixd' },
  root_markers = { 'flake.nix', '.git' },
  filetypes = { 'nix' },
})
vim.lsp.enable 'nixd'

vim.lsp.config('rust_analyzer', {
  cmd = { 'rust-analyzer' },
  root_markers = { 'Cargo.toml', '.git' },
  filetypes = { 'rust' },
})
vim.lsp.enable 'rust_analyzer'

vim.lsp.config('clangd', {
  cmd = { 'clangd' },
  root_markers = { 'compile_commands.json', 'compile_flags.txt', '.git' },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
})
vim.lsp.enable 'clangd'

vim.lsp.config('ocamllsp', {
  cmd = { 'ocamllsp' },
  root_markers = { 'dune-project', '.git' },
  filetypes = { 'ocaml', 'ocaml.menhir', 'ocaml.interface', 'ocaml.ocamllex' },
})
vim.lsp.enable 'ocamllsp'
