function CopyToClipboard()
    -- save current register to restore later
    local saved_register = vim.fn.getreg('"')

    -- yank (copy) the highlighted text to the default register
    vim.cmd('y')

    -- send the text to xclip via shell command
    local cmd = 'echo -n "'..vim.fn.escape(vim.fn.getreg('"'), '"')..'" | xclip -selection clipboard'
    print(vim.fn.escape(vim.fn.getreg('"'), '"'))
    os.execute(cmd)

    -- restore original register
    vim.fn.setreg('"', saved_register)
end

--"-------------------------------------------------------------------------------
--" Places a link to the current file in github in the system paste buffer
--"-------------------------------------------------------------------------------
function GithubLink()
  -- Get the git remote URL and extract repo (works for both SSH and HTTPS)
  local remote_url = vim.fn.system("git remote get-url origin 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    print("Error: Not in a git repository or no remote configured")
    return
  end

  -- Parse the repo from the remote URL
  local repo = remote_url
    :gsub('\n', '')
    :gsub('git@github.com:', '')
    :gsub('https://github.com/', '')
    :gsub('%.git$', '')

  -- Get current branch
  local branch = vim.fn.substitute(vim.fn.system('git rev-parse --abbrev-ref HEAD 2>/dev/null'), '\n', '', '')
  if vim.v.shell_error ~= 0 then
    print("Error: Could not determine git branch")
    return
  end

  -- Get current line number
  local line_num = vim.fn.line('.')

  -- Build GitHub URL with line number
  local filename = "https://github.com/" .. repo .. "/blob/" .. branch .. "/" .. vim.fn.expand("%:.") .. "#L" .. line_num

  -- Detect OS and use appropriate clipboard command
  local uname = vim.fn.system("uname"):gsub('\n', '')
  local clipboard_cmd

  if uname == "Darwin" then
    -- macOS
    clipboard_cmd = "pbcopy"
  elseif uname == "Linux" then
    -- Linux - try xclip first, fall back to xsel
    if os.execute("command -v xclip >/dev/null 2>&1") == 0 then
      clipboard_cmd = "xclip -selection clipboard"
    elseif os.execute("command -v xsel >/dev/null 2>&1") == 0 then
      clipboard_cmd = "xsel --clipboard"
    else
      print("Error: No clipboard command found (install xclip or xsel)")
      return
    end
  else
    print("Error: Unsupported OS: " .. uname)
    return
  end

  -- Copy to clipboard
  os.execute("echo '" .. filename .. "' | " .. clipboard_cmd)

  -- Show the link in Neovim
  print("GitHub link copied: " .. filename)
end


function LldbBreak()
  local filename = vim.fn.expand("%:.")
  local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))
  os.execute("echo breakpoint set -f "..filename.." -l ".. lnum .. "| xclip -selection clipboard")
end
