-- Soft Dark Theme - Easy on the eyes with excellent readability
-- Based on warm, natural color palette

local M = {}

function M.setup()
  -- Clear any existing colorscheme
  vim.cmd('highlight clear')
  if vim.fn.exists('syntax_on') then
    vim.cmd('syntax reset')
  end

  vim.o.termguicolors = true
  vim.g.colors_name = 'soft_dark'

  -- Set guicursor to use our custom cursor color
  vim.opt.guicursor = 'n-v-c-sm:block-Cursor,i-ci-ve:ver25-Cursor,r-cr-o:hor20-Cursor'

  -- Color palette - soft, muted tones for dark mode
  local colors = {
    -- Background shades (warm dark gray)
    bg0 = '#1e1e1e',      -- Main background
    bg1 = '#2a2a2a',      -- Slightly lighter
    bg2 = '#353535',      -- Line numbers, folds
    bg3 = '#404040',      -- Visual selection

    -- Foreground shades (warm off-white)
    fg0 = '#e8e4db',      -- Main text
    fg1 = '#b8b4ab',      -- Comments
    fg2 = '#8e8a81',      -- Subtle text

    -- Syntax colors (muted, natural)
    red = '#d88888',      -- Strings, errors
    orange = '#d8a878',   -- Numbers, constants
    yellow = '#d8c878',   -- Functions
    green = '#90b895',    -- Keywords, types
    cyan = '#88b8b8',     -- Special identifiers
    blue = '#88a8c8',     -- Methods, builtins
    purple = '#b898c0',   -- Variables
    magenta = '#c898a8',  -- Preprocessor

    -- UI elements
    border = '#4a4a4a',
    line_highlight = '#252525',
    cursor_line = '#282828',
    cursor = '#d88888',   -- Soft red cursor for visibility
    match = '#504838',
    diff_add = '#2a3a2a',
    diff_change = '#3a3828',
    diff_delete = '#3a2828',
  }

  -- Helper function to set highlights
  local function hi(group, opts)
    local cmd = 'highlight ' .. group
    if opts.fg then cmd = cmd .. ' guifg=' .. opts.fg end
    if opts.bg then cmd = cmd .. ' guibg=' .. opts.bg end
    if opts.style then cmd = cmd .. ' gui=' .. opts.style end
    if opts.sp then cmd = cmd .. ' guisp=' .. opts.sp end
    vim.cmd(cmd)
  end

  -- Editor UI
  hi('Normal', { fg = colors.fg0, bg = colors.bg0 })
  hi('NormalFloat', { fg = colors.fg0, bg = colors.bg1 })
  hi('FloatBorder', { fg = colors.border, bg = colors.bg1 })
  hi('Cursor', { fg = colors.bg0, bg = colors.cursor })
  hi('lCursor', { fg = colors.bg0, bg = colors.cursor })
  hi('CursorIM', { fg = colors.bg0, bg = colors.cursor })
  hi('TermCursor', { fg = colors.bg0, bg = colors.cursor })
  hi('CursorLine', { bg = colors.cursor_line })
  hi('CursorLineNr', { fg = colors.fg0, bg = colors.cursor_line, style = 'bold' })
  hi('LineNr', { fg = colors.fg2, bg = colors.bg0 })
  hi('SignColumn', { fg = colors.fg2, bg = colors.bg0 })
  hi('Visual', { bg = colors.bg3 })
  hi('VisualNOS', { bg = colors.bg3 })
  hi('Search', { fg = colors.fg0, bg = colors.match })
  hi('IncSearch', { fg = colors.bg0, bg = colors.yellow, style = 'bold' })
  hi('MatchParen', { fg = colors.red, style = 'bold,underline' })
  hi('Pmenu', { fg = colors.fg0, bg = colors.bg1 })
  hi('PmenuSel', { fg = colors.bg0, bg = colors.blue })
  hi('PmenuSbar', { bg = colors.bg2 })
  hi('PmenuThumb', { bg = colors.fg2 })
  hi('StatusLine', { fg = colors.fg0, bg = colors.bg2 })
  hi('StatusLineNC', { fg = colors.fg2, bg = colors.bg1 })
  hi('TabLine', { fg = colors.fg1, bg = colors.bg1 })
  hi('TabLineFill', { bg = colors.bg1 })
  hi('TabLineSel', { fg = colors.fg0, bg = colors.bg0, style = 'bold' })
  hi('VertSplit', { fg = colors.border, bg = colors.bg0 })
  hi('Folded', { fg = colors.fg1, bg = colors.bg2 })
  hi('FoldColumn', { fg = colors.fg2, bg = colors.bg0 })
  hi('ColorColumn', { bg = colors.bg1 })

  -- Syntax highlighting
  hi('Comment', { fg = colors.fg1, style = 'italic' })
  hi('Constant', { fg = colors.orange })
  hi('String', { fg = colors.red })
  hi('Character', { fg = colors.red })
  hi('Number', { fg = colors.orange })
  hi('Boolean', { fg = colors.orange })
  hi('Float', { fg = colors.orange })
  hi('Identifier', { fg = colors.purple })
  hi('Function', { fg = colors.yellow, style = 'bold' })
  hi('Statement', { fg = colors.green, style = 'bold' })
  hi('Conditional', { fg = colors.green, style = 'bold' })
  hi('Repeat', { fg = colors.green, style = 'bold' })
  hi('Label', { fg = colors.green })
  hi('Operator', { fg = colors.cyan })
  hi('Keyword', { fg = colors.green, style = 'bold' })
  hi('Exception', { fg = colors.red, style = 'bold' })
  hi('PreProc', { fg = colors.magenta })
  hi('Include', { fg = colors.magenta })
  hi('Define', { fg = colors.magenta })
  hi('Macro', { fg = colors.magenta })
  hi('PreCondit', { fg = colors.magenta })
  hi('Type', { fg = colors.green })
  hi('StorageClass', { fg = colors.green })
  hi('Structure', { fg = colors.green })
  hi('Typedef', { fg = colors.green })
  hi('Special', { fg = colors.cyan })
  hi('SpecialChar', { fg = colors.cyan })
  hi('Tag', { fg = colors.blue })
  hi('Delimiter', { fg = colors.fg0 })
  hi('SpecialComment', { fg = colors.cyan, style = 'italic' })
  hi('Debug', { fg = colors.red })
  hi('Underlined', { fg = colors.blue, style = 'underline' })
  hi('Ignore', { fg = colors.fg2 })
  hi('Error', { fg = colors.red, style = 'bold' })
  hi('Todo', { fg = colors.magenta, style = 'bold,italic' })

  -- Treesitter
  hi('@variable', { fg = colors.fg0 })
  hi('@variable.builtin', { fg = colors.purple, style = 'italic' })
  hi('@variable.parameter', { fg = colors.fg0 })
  hi('@variable.member', { fg = colors.purple })
  hi('@constant', { fg = colors.orange })
  hi('@constant.builtin', { fg = colors.orange })
  hi('@module', { fg = colors.blue })
  hi('@string', { fg = colors.red })
  hi('@character', { fg = colors.red })
  hi('@number', { fg = colors.orange })
  hi('@boolean', { fg = colors.orange })
  hi('@float', { fg = colors.orange })
  hi('@function', { fg = colors.yellow, style = 'bold' })
  hi('@function.builtin', { fg = colors.blue, style = 'bold' })
  hi('@function.call', { fg = colors.yellow })
  hi('@function.macro', { fg = colors.magenta })
  hi('@method', { fg = colors.yellow })
  hi('@method.call', { fg = colors.yellow })
  hi('@constructor', { fg = colors.green })
  hi('@parameter', { fg = colors.fg0 })
  hi('@keyword', { fg = colors.green, style = 'bold' })
  hi('@keyword.function', { fg = colors.green, style = 'bold' })
  hi('@keyword.operator', { fg = colors.cyan })
  hi('@keyword.return', { fg = colors.green, style = 'bold' })
  hi('@conditional', { fg = colors.green, style = 'bold' })
  hi('@repeat', { fg = colors.green, style = 'bold' })
  hi('@label', { fg = colors.green })
  hi('@operator', { fg = colors.cyan })
  hi('@exception', { fg = colors.red, style = 'bold' })
  hi('@type', { fg = colors.green })
  hi('@type.builtin', { fg = colors.green, style = 'italic' })
  hi('@type.qualifier', { fg = colors.green })
  hi('@structure', { fg = colors.green })
  hi('@include', { fg = colors.magenta })
  hi('@property', { fg = colors.purple })
  hi('@attribute', { fg = colors.magenta })
  hi('@comment', { fg = colors.fg1, style = 'italic' })
  hi('@tag', { fg = colors.blue })
  hi('@tag.attribute', { fg = colors.purple })
  hi('@tag.delimiter', { fg = colors.fg1 })
  hi('@punctuation.delimiter', { fg = colors.fg0 })
  hi('@punctuation.bracket', { fg = colors.fg0 })
  hi('@punctuation.special', { fg = colors.cyan })

  -- Diagnostics
  hi('DiagnosticError', { fg = colors.red })
  hi('DiagnosticWarn', { fg = colors.yellow })
  hi('DiagnosticInfo', { fg = colors.blue })
  hi('DiagnosticHint', { fg = colors.cyan })
  hi('DiagnosticUnderlineError', { sp = colors.red, style = 'undercurl' })
  hi('DiagnosticUnderlineWarn', { sp = colors.yellow, style = 'undercurl' })
  hi('DiagnosticUnderlineInfo', { sp = colors.blue, style = 'undercurl' })
  hi('DiagnosticUnderlineHint', { sp = colors.cyan, style = 'undercurl' })

  -- Git signs
  hi('GitSignsAdd', { fg = colors.green, bg = colors.bg0 })
  hi('GitSignsChange', { fg = colors.yellow, bg = colors.bg0 })
  hi('GitSignsDelete', { fg = colors.red, bg = colors.bg0 })

  -- Diff
  hi('DiffAdd', { bg = colors.diff_add })
  hi('DiffChange', { bg = colors.diff_change })
  hi('DiffDelete', { fg = colors.red, bg = colors.diff_delete })
  hi('DiffText', { bg = colors.diff_change, style = 'bold' })

  -- LSP
  hi('LspReferenceText', { bg = colors.bg2 })
  hi('LspReferenceRead', { bg = colors.bg2 })
  hi('LspReferenceWrite', { bg = colors.bg2 })

  -- CMP
  hi('CmpItemAbbrMatch', { fg = colors.yellow, style = 'bold' })
  hi('CmpItemAbbrMatchFuzzy', { fg = colors.yellow })
  hi('CmpItemKind', { fg = colors.blue })
  hi('CmpItemMenu', { fg = colors.fg1 })
end

return M
