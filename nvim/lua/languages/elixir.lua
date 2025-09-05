
return {
 -- Command and arguments to start the server.
 cmd = { 'elixir-ls' },

 -- Filetypes to automatically attach to.
 filetypes = { '.ex', '.exs', '.heex', '.eex', '.leex' },

 -- Sets the "root directory" to the parent directory of the file in the
 -- current buffer that contains either a ".luarc.json" or a
 -- ".luarc.jsonc" file. Files that share a root directory will reuse
 -- the connection to the same LSP server.
 -- Nested lists indicate equal priority, see |vim.lsp.Config|.
 root_markers = { { 'mix.exs', 'mix.lock' }, '.git' },

 -- Specific settings to send to the server. The schema for this is
 -- defined by the server. For example the schema for lua-language-server
 -- can be found here https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json
 settings = {
 }
}
--local lsp = require('lspconfig')
--
--
--vim.g.mix_format_on_save = 0
--
----local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())
--
--lsp.elixirls.setup{
--  cmd = {"elixir-ls"},
----  capabilities = capabilites
--}
--
----local elixirls = require("elixir.elixirls")
----require("elixir").setup({
----  nextls = {
----    enable = false, -- defaults to false
----    cmd = elixir_tools .. "/bin/nextls", -- path to the executable. mutually exclusive with `port`
----    version = "0.5.0", -- version of Next LS to install and use. defaults to the latest version
----    on_attach = function(client, bufnr)
----      -- custom keybinds
----      vim.keymap.set("n", "<space>fp", ":ElixirFromPipe<cr>", { buffer = true, noremap = true })
----      vim.keymap.set("n", "<space>tp", ":ElixirToPipe<cr>", { buffer = true, noremap = true })
----      vim.keymap.set("v", "<space>em", ":ElixirExpandMacro<cr>", { buffer = true, noremap = true })
----    end
----  },
----  credo = {
----    enable = true, -- defaults to true
----    cmd = elixir_tools .. "/bin/credo-language-server", -- path to the executable. mutually exclusive with `port`
----    version = "0.1.0-rc.3", -- version of credo-language-server to install and use. defaults to the latest release
----    on_attach = function(client, bufnr)
----      -- custom keybinds
----    end
----  },
----  elixirls = {
----    enable = true,
----    cmd = elixir_ls_home .. "/bin/elixir-ls", -- path to the executable. mutually exclusive with `port`
----    settings = elixirls.settings {
----      dialyzerEnabled = true,
----      enableTestLenses = false,
----    },
----    on_attach = function(client, bufnr)
----      vim.keymap.set("n", "<space>fp", ":ElixirFromPipe<cr>", { buffer = true, noremap = true })
----      vim.keymap.set("n", "<space>tp", ":ElixirToPipe<cr>", { buffer = true, noremap = true })
----      vim.keymap.set("v", "<space>em", ":ElixirExpandMacro<cr>", { buffer = true, noremap = true })
----    end,
----  }
---- -- elixirls = {enable = true},
----})
--
--function ElixirOpenTestFile()
--  local current_file = vim.fn.expand("%")
--
--  current_file = current_file:gsub("lib", "test")
--
--  current_file = current_file:gsub(".ex", "_test.exs")
--
--  vim.cmd("vs " .. current_file)
--end
--
--return lsp.elixirls
