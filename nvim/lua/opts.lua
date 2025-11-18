-- Colors and Themes
require('theme_toggle')
require('theme_tmux').setup()
vim.opt.background = 'dark'
local cmd = vim.cmd
cmd('syntax on')
cmd('set clipboard+=unnamedplus')
cmd('set foldlevel=99')

-- TmuxLine Theme
vim.g.tmuxline_preset = 'horizon'

vim.opt.termguicolors = true

-- Lines, Syntax, Language
vim.opt.hidden = true
vim.opt.encoding='utf-8'
vim.opt.number=true
vim.g.LANG='en_us'


-- Tab and Spacing
vim.opt.tabstop=2
vim.opt.softtabstop=2
vim.opt.shiftwidth=2
vim.opt.autoindent=true
vim.opt.expandtab=true

-- CMD Center
vim.opt.directory='/tmp'
vim.opt.showcmd=true
vim.opt.wildmenu=true
vim.opt.lazyredraw=true
vim.opt.ttyfast=true
vim.opt.showmatch=true
vim.opt.incsearch=true
vim.opt.hlsearch=true

-- Ctags configuration
vim.opt.tags = './tags,tags,../tags,../../tags'

-- Auto-generate tags for certain file types
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = {"*.ex", "*.exs", "*.lua", "*.js", "*.ts", "*.py"},
  callback = function()
    -- Only generate tags if we're in a project root (has .git)
    if vim.fn.finddir('.git', '.;') ~= '' then
      vim.fn.system('ctags -R . &')
    end
  end,
})
