require('actions.test')
require('actions.gpt')
require('actions.http_post')
require('actions.gql_request')
require('actions.http_request')
require('actions.copy_to_clipboard')
require('actions.build_environment')
require('actions.send_to_note')

-- Leader Key
vim.g.mapleader=","

local map = vim.keymap.set

-- Misc Copying Keybinds
map('n',  '<leader>m', ':let @+=expand("%")<CR>',{noremap=true})
map('v',  '<leader>k', '"*y<CR>',{noremap=true})

-- Search and FileNavigation Related keybinds
map('n',  '<leader>q',  ':bprev<CR>',{noremap=true})
map('n',  '<leader>p',  ':bnext<CR>',{noremap=true})
map('n', '<leader><space>', ':nohlsearch<CR>', {noremap=true})

-- LuaSnip Keybinds -- PREFIX s
map({'i', 's'}, '<leader>x', function() require('luasnip').expand() end, {noremap=true})
map({'i', 's'}, '<leader>n', function() require('luasnip').jump(1) end, {noremap=true})
map({'i', 's'}, '<leader>b', function() require('luasnip').jump(-1) end, {noremap=true})

-- Enhanced snippet editing: creates file if it doesn't exist
map('n', '<leader>sd', function()
  local ft = vim.bo.filetype
  if ft == '' then ft = 'all' end  -- Use 'all' for no filetype

  local snippet_dir = vim.env.DEVTOOLS_ROOT .. "/snippets"
  local snippet_file = snippet_dir .. "/" .. ft .. ".lua"

  -- Create snippet file if it doesn't exist
  if vim.fn.filereadable(snippet_file) == 0 then
    -- Ensure directory exists
    vim.fn.mkdir(snippet_dir, "p")

    -- Create file with template
    local template = [[local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  -- Example snippet
  -- s("trigger", {
  --   t("text here"),
  --   i(1, "placeholder"),
  -- }),
}
]]

    local file = io.open(snippet_file, "w")
    if file then
      file:write(template)
      file:close()
      print("Created new snippet file: " .. snippet_file)
    end
  end

  -- Open the snippet file directly
  vim.cmd("edit " .. snippet_file)
end, {noremap=true})


-- Nvim Config Keybinds -- PREFIX v
map('n', '<leader>vc', ':e ~/.config/nvim/init.lua', {noremap=true})
map('n', '<leader>vr', ':source ~/.config/nvim/init.lua', {noremap=true})


-- Testing Keybinds -- PREFIX t  
map('n', '<leader>t',   ':lua vim.lsp.codelens.run()<CR>',{noremap=true})

-- Ctags Keybinds
map('n', '<C-]>', '<C-]>', {noremap=true})  -- Jump to tag under cursor
map('n', '<C-t>', '<C-t>', {noremap=true})  -- Jump back from tag
map('n', '<leader>r', ':!ctags -R . 2>/dev/null<CR>', {noremap=true})  -- Regenerate tags (silenced)

-- Formatting Keybinds -- PREFIX f
map('n', '<leader>f',   ':lua Format()<CR>',{noremap=true})
map('n', '<leader>to',   ':lua ElixirOpenTestFile()<CR>',{noremap=true})


-- custom actions - because I can
map('v', '<leader>c',   ':lua CopyToClipboard()<CR>',{noremap=true})
map('v', '<leader>gpt3', ':lua GPTSubmit("3")<CR>',{noremap=true})
map('v', '<leader>gpt4', ':lua GPTSubmit()<CR>',{noremap=true})
map('n', '<leader>gl', ':lua GithubLink()<CR>', {noremap=true})

-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
map('n', '<space>e', vim.diagnostic.open_float, {noremap=true})
map('n', '[d', vim.diagnostic.goto_prev, {noremap=true})
map('n', ']d', vim.diagnostic.goto_next, {noremap=true})
map('n', '<space>q', vim.diagnostic.setloclist, {noremap=true})

-- Debugger - SEMI TODO THIS IS HALF DONE
map('n','<leader>bs', ":lua require('dap').toggle_breakpoint()", {noremap=true})
map('n','<leader>bo', ":lua require('dap').step_over()", {noremap=true})
map('n','<leader>bi', ":lua require('dap').step_into()", {noremap=true})
map('n','<leader>bc', ":lua require('dap').continue()", {noremap=true})
map('n','<leader>br', ":lua require('dap').repl.open()", {noremap=true})
map('n','<leader>bp', ":lua LldbBreak()<CR>", {noremap=true})

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    map('n', 'gD', vim.lsp.buf.declaration, opts)
    map('n', 'gd', vim.lsp.buf.definition, opts)
    map('n', 'K', vim.lsp.buf.hover, opts)
    map('n', 'gi', vim.lsp.buf.implementation, opts)
    map('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    map('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    map('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    map('n', '<space>D', vim.lsp.buf.type_definition, opts)
    map('n', '<space>rn', vim.lsp.buf.rename, opts)
    map('n', '<space>ca', vim.lsp.buf.code_action, opts)
    map('n', 'gr', vim.lsp.buf.references, opts)
    map('n', '<space>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})
