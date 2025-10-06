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
