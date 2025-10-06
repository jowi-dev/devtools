function OpenTest()
    local current_file = vim.fn.expand('%:p')
    local test_file = nil

    -- Elixir: lib/foo.ex -> test/foo_test.exs
    if current_file:match('%.exs?$') then
        if current_file:match('/lib/') then
            test_file = current_file:gsub('/lib/', '/test/'):gsub('%.ex$', '_test.exs')
        elseif current_file:match('/test/') and current_file:match('_test%.exs$') then
            print('Already in test file.')
            return
        end
    end

    if test_file and vim.fn.filereadable(test_file) == 1 then
        vim.cmd('vsplit ' .. vim.fn.fnameescape(test_file))
    else
        print('Test file not found: ' .. (test_file or 'unknown'))
    end
end

function CreateTest()
    local current_file = vim.fn.expand('%:p')
    local test_file = nil

    -- Elixir: lib/foo.ex -> test/foo_test.exs
    if current_file:match('%.exs?$') then
        if current_file:match('/lib/') then
            test_file = current_file:gsub('/lib/', '/test/'):gsub('%.ex$', '_test.exs')
        elseif current_file:match('/test/') and current_file:match('_test%.exs$') then
            print('Already in test file.')
            return
        end
    end

    if not test_file then
        print('Not an Elixir source file in lib/')
        return
    end

    if vim.fn.filereadable(test_file) == 1 then
        print('Test file already exists: ' .. test_file)
        vim.cmd('vsplit ' .. vim.fn.fnameescape(test_file))
        return
    end

    -- Create directory if needed
    local test_dir = vim.fn.fnamemodify(test_file, ':h')
    vim.fn.mkdir(test_dir, 'p')

    -- Create empty test file
    vim.fn.writefile({''}, test_file)
    vim.cmd('vsplit ' .. vim.fn.fnameescape(test_file))
    print('Created test file: ' .. test_file)
end
