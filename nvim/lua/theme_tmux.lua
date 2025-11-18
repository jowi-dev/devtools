-- Tmux-inspired Theme - Matches tmux status bar and Ghostty terminal aesthetic
-- Based on warm, muted color palette: #262626, #af875f, #d75f00

local M = {}

function M.setup()
  -- Clear any existing colorscheme
  vim.cmd('highlight clear')
  if vim.fn.exists('syntax_on') then
    vim.cmd('syntax reset')
  end

  vim.o.termguicolors = true
  vim.g.colors_name = 'tmux_aesthetic'

  -- Set guicursor to use our custom cursor color
  vim.opt.guicursor = 'n-v-c-sm:block-Cursor,i-ci-ve:ver25-Cursor,r-cr-o:hor20-Cursor'

  -- Color palette - matching tmux/ghostty
  local colors = {
    -- Background shades (dark gray - colour235)
    bg0 = '#262626',      -- Main background
    bg1 = '#303030',      -- Slightly lighter
    bg2 = '#3a3a3a',      -- Line numbers, folds
    bg3 = '#444444',      -- Visual selection

    -- Foreground shades (warm tan - colour136)
    fg0 = '#af875f',      -- Main text
    fg1 = '#808080',      -- Comments (colour244)
    fg2 = '#6c6c6c',      -- Subtle text

    -- Accent colors (from ghostty palette)
    orange = '#d75f00',   -- Primary accent (colour166)
    bright_orange = '#ff8700', -- Bright orange
    red = '#d75f5f',      -- Errors
    green = '#5f8700',    -- Success, added
    bright_green = '#87af00',
    yellow = '#d7af5f',   -- Warnings, functions
    blue = '#5f87af',     -- Methods, builtins
    bright_blue = '#87afd7',
    magenta = '#875f87',  -- Preprocessor
    bright_magenta = '#af87af',
    cyan = '#5f8787',     -- Special identifiers
    bright_cyan = '#87afaf',

    -- UI elements
    border = '#444444',
    line_highlight = '#2a2a2a',
    cursor_line = '#303030',
    cursor = '#d75f00',     -- Orange cursor for visibility
    match = '#d7af5f',
    diff_add = '#2d3a2d',
    diff_change = '#3a3a2d',
    diff_delete = '#3a2d2d',
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
  hi('CursorLineNr', { fg = colors.orange, bg = colors.cursor_line, style = 'bold' })
  hi('LineNr', { fg = colors.fg1, bg = colors.bg0 })
  hi('SignColumn', { fg = colors.fg1, bg = colors.bg0 })
  hi('Visual', { bg = colors.bg3 })
  hi('VisualNOS', { bg = colors.bg3 })
  hi('Search', { fg = colors.bg0, bg = colors.yellow })
  hi('IncSearch', { fg = colors.bg0, bg = colors.orange, style = 'bold' })
  hi('MatchParen', { fg = colors.orange, style = 'bold,underline' })
  hi('Pmenu', { fg = colors.fg0, bg = colors.bg1 })
  hi('PmenuSel', { fg = colors.bg0, bg = colors.orange })
  hi('PmenuSbar', { bg = colors.bg2 })
  hi('PmenuThumb', { bg = colors.fg1 })
  hi('StatusLine', { fg = colors.orange, bg = colors.bg1, style = 'bold' })
  hi('StatusLineNC', { fg = colors.fg1, bg = colors.bg1 })
  hi('TabLine', { fg = colors.fg1, bg = colors.bg1 })
  hi('TabLineFill', { bg = colors.bg1 })
  hi('TabLineSel', { fg = colors.orange, bg = colors.bg0, style = 'bold' })
  hi('VertSplit', { fg = colors.border, bg = colors.bg0 })
  hi('Folded', { fg = colors.fg1, bg = colors.bg2 })
  hi('FoldColumn', { fg = colors.fg1, bg = colors.bg0 })
  hi('ColorColumn', { bg = colors.bg1 })

  -- Syntax highlighting
  hi('Comment', { fg = colors.fg1, style = 'italic' })
  hi('Constant', { fg = colors.yellow })
  hi('String', { fg = colors.green })
  hi('Character', { fg = colors.green })
  hi('Number', { fg = colors.yellow })
  hi('Boolean', { fg = colors.yellow })
  hi('Float', { fg = colors.yellow })
  hi('Identifier', { fg = colors.fg0 })
  hi('Function', { fg = colors.orange, style = 'bold' })
  hi('Statement', { fg = colors.blue, style = 'bold' })
  hi('Conditional', { fg = colors.blue, style = 'bold' })
  hi('Repeat', { fg = colors.blue, style = 'bold' })
  hi('Label', { fg = colors.blue })
  hi('Operator', { fg = colors.cyan })
  hi('Keyword', { fg = colors.blue, style = 'bold' })
  hi('Exception', { fg = colors.red, style = 'bold' })
  hi('PreProc', { fg = colors.magenta })
  hi('Include', { fg = colors.magenta })
  hi('Define', { fg = colors.magenta })
  hi('Macro', { fg = colors.magenta })
  hi('PreCondit', { fg = colors.magenta })
  hi('Type', { fg = colors.bright_green })
  hi('StorageClass', { fg = colors.bright_green })
  hi('Structure', { fg = colors.bright_green })
  hi('Typedef', { fg = colors.bright_green })
  hi('Special', { fg = colors.cyan })
  hi('SpecialChar', { fg = colors.cyan })
  hi('Tag', { fg = colors.blue })
  hi('Delimiter', { fg = colors.fg0 })
  hi('SpecialComment', { fg = colors.cyan, style = 'italic' })
  hi('Debug', { fg = colors.red })
  hi('Underlined', { fg = colors.blue, style = 'underline' })
  hi('Ignore', { fg = colors.fg2 })
  hi('Error', { fg = colors.red, style = 'bold' })
  hi('Todo', { fg = colors.bright_orange, style = 'bold,italic' })

  -- Treesitter
  hi('@variable', { fg = colors.fg0 })
  hi('@variable.builtin', { fg = colors.cyan, style = 'italic' })
  hi('@variable.parameter', { fg = colors.fg0 })
  hi('@variable.member', { fg = colors.fg0 })
  hi('@constant', { fg = colors.yellow })
  hi('@constant.builtin', { fg = colors.yellow })
  hi('@module', { fg = colors.blue })
  hi('@string', { fg = colors.green })
  hi('@character', { fg = colors.green })
  hi('@number', { fg = colors.yellow })
  hi('@boolean', { fg = colors.yellow })
  hi('@float', { fg = colors.yellow })
  hi('@function', { fg = colors.orange, style = 'bold' })
  hi('@function.builtin', { fg = colors.orange, style = 'bold' })
  hi('@function.call', { fg = colors.orange })
  hi('@function.macro', { fg = colors.magenta })
  hi('@method', { fg = colors.orange })
  hi('@method.call', { fg = colors.orange })
  hi('@constructor', { fg = colors.bright_green })
  hi('@parameter', { fg = colors.fg0 })
  hi('@keyword', { fg = colors.blue, style = 'bold' })
  hi('@keyword.function', { fg = colors.blue, style = 'bold' })
  hi('@keyword.operator', { fg = colors.cyan })
  hi('@keyword.return', { fg = colors.blue, style = 'bold' })
  hi('@conditional', { fg = colors.blue, style = 'bold' })
  hi('@repeat', { fg = colors.blue, style = 'bold' })
  hi('@label', { fg = colors.blue })
  hi('@operator', { fg = colors.cyan })
  hi('@exception', { fg = colors.red, style = 'bold' })
  hi('@type', { fg = colors.bright_green })
  hi('@type.builtin', { fg = colors.bright_green, style = 'italic' })
  hi('@type.qualifier', { fg = colors.bright_green })
  hi('@structure', { fg = colors.bright_green })
  hi('@include', { fg = colors.magenta })
  hi('@property', { fg = colors.fg0 })
  hi('@attribute', { fg = colors.magenta })
  hi('@comment', { fg = colors.fg1, style = 'italic' })
  hi('@tag', { fg = colors.blue })
  hi('@tag.attribute', { fg = colors.fg0 })
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
  hi('CmpItemAbbrMatch', { fg = colors.orange, style = 'bold' })
  hi('CmpItemAbbrMatchFuzzy', { fg = colors.orange })
  hi('CmpItemKind', { fg = colors.blue })
  hi('CmpItemMenu', { fg = colors.fg1 })
end

return M
