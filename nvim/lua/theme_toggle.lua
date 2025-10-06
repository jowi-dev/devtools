-- Theme toggle commands

local M = {}

function M.light()
  require('theme').setup()
  vim.opt.background = 'light'
end

function M.dark()
  require('theme_dark').setup()
  vim.opt.background = 'dark'
end

-- Create user commands
vim.api.nvim_create_user_command('LightMode', M.light, {})
vim.api.nvim_create_user_command('DarkMode', M.dark, {})

return M
