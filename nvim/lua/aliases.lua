require('actions.open_test')

vim.cmd('command! Notes Telekasten panel')
vim.cmd('command! BuildEnv :lua BuildEnv()')
vim.cmd('command! Tests :lua OpenTest()')
vim.cmd('command! TestCreate :lua CreateTest()')
